//
//  EventiNotificationStore.swift
//  Sinfonia4You
//
//  Tiene traccia degli eventi nuovi, aggiorna il badge e mostra
//  notifiche locali quando arrivano nuove convocazioni.
//

import Combine
import Foundation
import UIKit
import UserNotifications

@MainActor
final class EventiNotificationStore: ObservableObject {
    static let shared = EventiNotificationStore()

    @Published private(set) var unreadCount = 0
    @Published private(set) var unreadEventIDs: Set<String> = []

    private let apiClient: APIClient
    private let defaults: UserDefaults
    private var currentUserKey: String?

    init() {
        self.apiClient = .shared
        self.defaults = .standard
    }

    init(apiClient: APIClient, defaults: UserDefaults) {
        self.apiClient = apiClient
        self.defaults = defaults
    }

    func configureSession(userIdentifier: String) async {
        let userKey = normalizedUserKey(userIdentifier)
        currentUserKey = userKey
        migrateLegacyUnreadIfNeeded(userKey: userKey)
        unreadEventIDs = currentUnreadSet(for: userKey)
        unreadCount = unreadEventIDs.count
        applyAppBadge()
    }

    func sync(token: String, userIdentifier: String, notifyOnNewItems: Bool) async {
        let userKey = normalizedUserKey(userIdentifier)
        currentUserKey = userKey

        if notifyOnNewItems {
            await requestAuthorizationIfNeeded()
        }

        do {
            let items = try await apiClient.eventi(token: token)
            applySnapshot(items, for: userKey, notifyOnNewItems: notifyOnNewItems)
        } catch {
            // Il badge mantiene l'ultimo stato valido; un errore di rete non deve
            // azzerare i contatori né generare rumore all'utente.
        }
    }

    func markItemsAsRead(_ items: [EventoItemDTO]) {
        guard let userKey = currentUserKey else { return }
        let viewedIDs = Set(items.map(\.eventId))
        let currentSnapshot = loadSet(forKey: snapshotKey(for: userKey))
        let sanitizedViewed = viewedIDs.intersection(currentSnapshot)
        let currentRead = loadSet(forKey: readKey(for: userKey)).intersection(currentSnapshot)
        let updatedRead = currentRead.union(sanitizedViewed)
        let currentUnread = loadSet(forKey: unreadKey(for: userKey)).intersection(currentSnapshot)
        let remainingUnread = currentUnread.subtracting(sanitizedViewed)

        storeSet(updatedRead, forKey: readKey(for: userKey))
        storeSet(remainingUnread, forKey: unreadKey(for: userKey))
        unreadEventIDs = remainingUnread
        unreadCount = remainingUnread.count
        applyAppBadge()
    }

    func resetSession() {
        currentUserKey = nil
        unreadEventIDs = []
        unreadCount = 0
        applyAppBadge()
    }

    private func applySnapshot(_ items: [EventoItemDTO], for userKey: String, notifyOnNewItems: Bool) {
        let fetchedIDs = Set(items.map(\.eventId))
        let knownIDs = loadSet(forKey: knownKey(for: userKey))
        let previousRead = loadSet(forKey: readKey(for: userKey))
        let previousUnread = loadSet(forKey: unreadKey(for: userKey)).intersection(fetchedIDs)
        let hasBaseline = defaults.bool(forKey: baselineKey(for: userKey))

        let newIDs = hasBaseline ? fetchedIDs.subtracting(knownIDs) : []
        let sanitizedRead = previousRead.intersection(fetchedIDs)
        let updatedUnread = hasBaseline ? previousUnread.union(newIDs).subtracting(sanitizedRead) : []

        storeSet(knownIDs.union(fetchedIDs), forKey: knownKey(for: userKey))
        storeSet(fetchedIDs, forKey: snapshotKey(for: userKey))
        storeSet(sanitizedRead, forKey: readKey(for: userKey))
        storeSet(updatedUnread, forKey: unreadKey(for: userKey))
        defaults.set(true, forKey: baselineKey(for: userKey))

        unreadEventIDs = updatedUnread
        unreadCount = updatedUnread.count
        applyAppBadge()

        if notifyOnNewItems, hasBaseline, !newIDs.isEmpty {
            scheduleNotification(for: newIDs, items: items)
        }
    }

    private func currentUnreadSet(for userKey: String) -> Set<String> {
        let snapshot = loadSet(forKey: snapshotKey(for: userKey))
        guard !snapshot.isEmpty else {
            return loadSet(forKey: unreadKey(for: userKey))
        }

        let read = loadSet(forKey: readKey(for: userKey)).intersection(snapshot)
        let unread = loadSet(forKey: unreadKey(for: userKey))
            .intersection(snapshot)
            .subtracting(read)
        storeSet(read, forKey: readKey(for: userKey))
        storeSet(unread, forKey: unreadKey(for: userKey))
        return unread
    }

    private func migrateLegacyUnreadIfNeeded(userKey: String) {
        let key = migrationKey(for: userKey)
        guard defaults.bool(forKey: key) == false else { return }

        let snapshot = loadSet(forKey: snapshotKey(for: userKey))
        if !snapshot.isEmpty {
            let updatedRead = loadSet(forKey: readKey(for: userKey)).union(snapshot)
            storeSet(updatedRead, forKey: readKey(for: userKey))
            storeSet([], forKey: unreadKey(for: userKey))
        }

        defaults.set(true, forKey: key)
    }

    private func scheduleNotification(for newIDs: Set<String>, items: [EventoItemDTO]) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()

        if newIDs.count == 1,
           let item = items.first(where: { newIDs.contains($0.eventId) }) {
            content.title = "Nuovo evento Sinfonia4You"
            content.body = notificationBody(for: item)
        } else {
            content.title = "Nuove convocazioni"
            content.body = "Hai \(newIDs.count) nuovi eventi da controllare in Elenco Eventi."
        }

        content.sound = .default
        content.badge = NSNumber(value: unreadCount)

        let request = UNNotificationRequest(
            identifier: "sinfonia4you.events.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }

    private func notificationBody(for item: EventoItemDTO) -> String {
        let titolo = cleanText(item.eventType.isEmpty ? "Convocazione" : item.eventType)
        let when = [item.startDate, item.startTime]
            .map(cleanText)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let luogo = cleanText(item.place)

        return [titolo, when, luogo]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func applyAppBadge() {
        UNUserNotificationCenter.current().setBadgeCount(unreadCount)
    }

    private func requestAuthorizationIfNeeded() async {
        let key = "sinfonia4you.notifications.authorization.requested"
        guard defaults.bool(forKey: key) == false else { return }
        defaults.set(true, forKey: key)

        await Self.requestNotificationAuthorization()
    }

    private func normalizedUserKey(_ raw: String) -> String {
        let cleaned = cleanText(raw)
        let fallback = cleaned.isEmpty ? "default" : cleaned
        return fallback
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
    }

    private func cleanText(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        if let encoded = cleaned.data(using: .isoLatin1),
           let decoded = String(data: encoded, encoding: .utf8),
           !decoded.isEmpty {
            cleaned = decoded
        }

        cleaned = cleaned.replacingOccurrences(of: "\u{00A0}", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "Â", with: "")

        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func knownKey(for userKey: String) -> String {
        "sinfonia4you.events.known.\(userKey)"
    }

    private func unreadKey(for userKey: String) -> String {
        "sinfonia4you.events.unread.\(userKey)"
    }

    private func readKey(for userKey: String) -> String {
        "sinfonia4you.events.read.\(userKey)"
    }

    private func snapshotKey(for userKey: String) -> String {
        "sinfonia4you.events.snapshot.\(userKey)"
    }

    private func baselineKey(for userKey: String) -> String {
        "sinfonia4you.events.baseline.\(userKey)"
    }

    private func migrationKey(for userKey: String) -> String {
        "sinfonia4you.events.unread.migration.v2.\(userKey)"
    }

    private func loadSet(forKey key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    private func storeSet(_ set: Set<String>, forKey key: String) {
        defaults.set(Array(set).sorted(), forKey: key)
    }

    nonisolated private static func requestNotificationAuthorization() async {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                continuation.resume()
            }
        }
    }
}
