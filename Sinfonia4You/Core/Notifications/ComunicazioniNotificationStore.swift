//
//  ComunicazioniNotificationStore.swift
//  Sinfonia4You
//
//  Mantiene il conteggio locale delle comunicazioni non lette, così la tab
//  Notizie mostra solo ciò che è davvero nuovo per l'arbitro.
//

import Combine
import Foundation

@MainActor
final class ComunicazioniNotificationStore: ObservableObject {
    static let shared = ComunicazioniNotificationStore()

    @Published private(set) var unreadCount = 0
    @Published private(set) var unreadCommunicationIDs: Set<String> = []

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
        unreadCommunicationIDs = currentUnreadSet(for: userKey)
        unreadCount = unreadCommunicationIDs.count
    }

    func sync(token: String, userIdentifier: String) async {
        let userKey = normalizedUserKey(userIdentifier)
        currentUserKey = userKey

        do {
            let snapshot = try await apiClient.snapshotModulo(token: token, moduleId: "communications")
            applySnapshot(snapshot.rows, for: userKey)
        } catch {
            // Se la rete fallisce manteniamo l'ultimo stato valido.
        }
    }

    func applySnapshot(_ rows: [RigaModuloDTO]) {
        guard let userKey = currentUserKey else { return }
        applySnapshot(rows, for: userKey)
    }

    func markItemsAsRead(_ rows: [RigaModuloDTO]) {
        guard let userKey = currentUserKey else { return }
        let viewedIDs = Set(rows.map(\.id))
        let currentSnapshot = loadSet(forKey: snapshotKey(for: userKey))
        let sanitizedViewed = viewedIDs.intersection(currentSnapshot)
        let currentRead = loadSet(forKey: readKey(for: userKey)).intersection(currentSnapshot)
        let updatedRead = currentRead.union(sanitizedViewed)
        let currentUnread = loadSet(forKey: unreadKey(for: userKey)).intersection(currentSnapshot)
        let remainingUnread = currentUnread.subtracting(sanitizedViewed)

        storeSet(updatedRead, forKey: readKey(for: userKey))
        storeSet(remainingUnread, forKey: unreadKey(for: userKey))
        unreadCommunicationIDs = remainingUnread
        unreadCount = remainingUnread.count
    }

    func resetSession() {
        currentUserKey = nil
        unreadCommunicationIDs = []
        unreadCount = 0
    }

    private func applySnapshot(_ rows: [RigaModuloDTO], for userKey: String) {
        let fetchedIDs = Set(rows.map(\.id))
        let knownIDs = loadSet(forKey: knownKey(for: userKey))
        let previousRead = loadSet(forKey: readKey(for: userKey)).intersection(fetchedIDs)
        let previousUnread = loadSet(forKey: unreadKey(for: userKey)).intersection(fetchedIDs)
        let hasBaseline = defaults.bool(forKey: baselineKey(for: userKey))
        let newIDs = hasBaseline ? fetchedIDs.subtracting(knownIDs) : []
        let unread = hasBaseline ? previousUnread.union(newIDs).subtracting(previousRead) : []

        storeSet(fetchedIDs, forKey: snapshotKey(for: userKey))
        storeSet(knownIDs.union(fetchedIDs), forKey: knownKey(for: userKey))
        storeSet(previousRead, forKey: readKey(for: userKey))
        storeSet(unread, forKey: unreadKey(for: userKey))
        defaults.set(true, forKey: baselineKey(for: userKey))

        unreadCommunicationIDs = unread
        unreadCount = unread.count
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

    private func normalizedUserKey(_ raw: String) -> String {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
        return cleaned.isEmpty ? "default" : cleaned
    }

    private func knownKey(for userKey: String) -> String {
        "sinfonia4you.communications.known.\(userKey)"
    }

    private func snapshotKey(for userKey: String) -> String {
        "sinfonia4you.communications.snapshot.\(userKey)"
    }

    private func readKey(for userKey: String) -> String {
        "sinfonia4you.communications.read.\(userKey)"
    }

    private func unreadKey(for userKey: String) -> String {
        "sinfonia4you.communications.unread.\(userKey)"
    }

    private func baselineKey(for userKey: String) -> String {
        "sinfonia4you.communications.baseline.\(userKey)"
    }

    private func migrationKey(for userKey: String) -> String {
        "sinfonia4you.communications.unread.migration.v2.\(userKey)"
    }

    private func loadSet(forKey key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    private func storeSet(_ set: Set<String>, forKey key: String) {
        defaults.set(Array(set).sorted(), forKey: key)
    }
}
