//
//  PromemoriaGareStore.swift
//  Sinfonia4You
//
//  Gestisce promemoria locali per la gara del giorno. I dati restano sul
//  dispositivo e vengono aggiornati quando l'app sincronizza le designazioni.
//

import Combine
import Foundation
import UserNotifications

@MainActor
final class PromemoriaGareStore: ObservableObject {
    static let shared = PromemoriaGareStore()

    @Published private(set) var remindersEnabled: Bool

    private let apiClient: APIClient
    private let defaults: UserDefaults
    private var currentUserKey: String?

    init() {
        self.apiClient = .shared
        self.defaults = .standard
        self.remindersEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    init(apiClient: APIClient, defaults: UserDefaults) {
        self.apiClient = apiClient
        self.defaults = defaults
        self.remindersEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    func configureSession(userIdentifier: String) {
        currentUserKey = normalizedUserKey(userIdentifier)
    }

    func setEnabled(_ enabled: Bool) async {
        remindersEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)

        if enabled {
            await requestAuthorizationIfNeeded()
        } else {
            clearPendingReminders()
        }
    }

    func sync(token: String, userIdentifier: String) async {
        let userKey = normalizedUserKey(userIdentifier)
        currentUserKey = userKey

        guard remindersEnabled else {
            clearPendingReminders()
            return
        }

        await requestAuthorizationIfNeeded()

        do {
            let matches = try await apiClient.matches(token: token)
            await scheduleReminders(for: matches, userKey: userKey)
        } catch {
            // Un errore di rete non deve cancellare promemoria già programmati.
        }
    }

    func resetSession() {
        currentUserKey = nil
        clearPendingReminders()
    }

    private func scheduleReminders(for matches: [MatchAssignmentDTO], userKey: String) async {
        let center = UNUserNotificationCenter.current()
        let prefix = Self.identifierPrefix + userKey + "."
        var scheduledKeys = loadSet(forKey: scheduledKey(for: userKey))
        var deliveredKeys = loadSet(forKey: deliveredKey(for: userKey))

        let currentIDs = Set(matches.map(\.idDesignazione))
        let pending = await Self.pendingRequests(center: center)
        let pendingIDs = Set(pending.map(\.identifier))
        let removable = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) && currentIDs.contains($0.components(separatedBy: ".").last ?? "") == false }
        if !removable.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: removable)
        }

        for match in matches {
            let identifier = identifier(for: match, userKey: userKey)
            let reminderKey = reminderKey(for: match)

            guard let reminder = reminderTrigger(for: match) else {
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
                scheduledKeys.remove(reminderKey)
                continue
            }

            if deliveredKeys.contains(reminderKey) {
                continue
            }

            if scheduledKeys.contains(reminderKey) {
                if pendingIDs.contains(identifier) {
                    continue
                }

                if reminder.reminderDate <= Date() {
                    deliveredKeys.insert(reminderKey)
                    scheduledKeys.remove(reminderKey)
                    continue
                }
            }

            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: reminder.trigger
            )

            do {
                try await Self.add(request, center: center)
                scheduledKeys.insert(reminderKey)
            } catch {
                // Ignoriamo errori sporadici del sistema notifiche senza rompere il flusso.
            }
        }

        storeSet(prunedReminderHistory(scheduledKeys), forKey: scheduledKey(for: userKey))
        storeSet(prunedReminderHistory(deliveredKeys), forKey: deliveredKey(for: userKey))
    }

    private func reminderTrigger(for match: MatchAssignmentDTO) -> (title: String, body: String, trigger: UNNotificationTrigger, reminderDate: Date)? {
        guard isAccepted(match.statusLabel, status: match.status) else { return nil }
        guard let kickOffDate = parsedMatchDate(date: match.date, time: match.time) else { return nil }

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let reminderDate = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: kickOffDate
        ) ?? kickOffDate

        let trigger: UNNotificationTrigger
        if reminderDate > now {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        } else if calendar.isDate(kickOffDate, inSameDayAs: now), kickOffDate > now {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        } else {
            return nil
        }

        let teams = "\(clean(match.homeTeam)) vs \(clean(match.awayTeam))"
        let role = clean(match.activity)
        let competition = [clean(match.category), clean(match.group)].filter { !$0.isEmpty }.joined(separator: " · ")
        let time = clean(match.time)

        let title = "Promemoria gara di oggi"
        let body = [teams, time.isEmpty ? "" : "ore \(time)", role, competition]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        return (title, body, trigger, reminderDate)
    }

    private func isAccepted(_ statusLabel: String, status: String) -> Bool {
        let merged = (statusLabel + " " + status).lowercased()
        return merged.contains("accett") || merged.contains("accepted")
    }

    private func parsedMatchDate(date: String, time: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"

        let dateValue = clean(date)
        let timeValue = clean(time).isEmpty ? "00:00" : clean(time)
        return formatter.date(from: "\(dateValue) \(timeValue)")
    }

    private func requestAuthorizationIfNeeded() async {
        guard defaults.bool(forKey: Self.authorizationRequestedKey) == false else { return }
        defaults.set(true, forKey: Self.authorizationRequestedKey)
        await Self.requestNotificationAuthorization()
    }

    private func clearPendingReminders() {
        let center = UNUserNotificationCenter.current()
        let prefix = Self.identifierPrefix
        if let currentUserKey {
            storeSet([], forKey: scheduledKey(for: currentUserKey))
        }
        Task {
            let requests = await Self.pendingRequests(center: center)
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    private func identifier(for match: MatchAssignmentDTO, userKey: String) -> String {
        Self.identifierPrefix + userKey + "." + match.idDesignazione
    }

    private func reminderKey(for match: MatchAssignmentDTO) -> String {
        let normalizedDate = clean(match.date).replacingOccurrences(of: "/", with: "-")
        return "\(clean(match.idDesignazione))|\(normalizedDate)"
    }

    private func normalizedUserKey(_ raw: String) -> String {
        let cleaned = clean(raw)
        let fallback = cleaned.isEmpty ? "default" : cleaned
        return fallback
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
    }

    private func clean(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func pendingRequests(center: UNUserNotificationCenter) async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func scheduledKey(for userKey: String) -> String {
        "sinfonia4you.match.reminders.scheduled.\(userKey)"
    }

    private func deliveredKey(for userKey: String) -> String {
        "sinfonia4you.match.reminders.delivered.\(userKey)"
    }

    private func loadSet(forKey key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    private func storeSet(_ set: Set<String>, forKey key: String) {
        defaults.set(Array(set).sorted(), forKey: key)
    }

    private func prunedReminderHistory(_ keys: Set<String>) -> Set<String> {
        let calendar = Calendar(identifier: .gregorian)
        let cutoff = calendar.date(byAdding: .day, value: -45, to: Date()) ?? Date.distantPast

        return Set(keys.filter { key in
            let components = key.split(separator: "|")
            guard let rawDate = components.last else { return false }
            let normalized = rawDate.replacingOccurrences(of: "-", with: "/")
            guard let date = parsedMatchDate(date: normalized, time: "00:00") else { return false }
            return date >= cutoff
        })
    }

    nonisolated private static func add(_ request: UNNotificationRequest, center: UNUserNotificationCenter) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static let enabledKey = "sinfonia4you.match.reminders.enabled"
    private static let authorizationRequestedKey = "sinfonia4you.match.reminders.authorization.requested"
    private static let identifierPrefix = "sinfonia4you.match.reminder."

    nonisolated private static func requestNotificationAuthorization() async {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                continuation.resume()
            }
        }
    }
}
