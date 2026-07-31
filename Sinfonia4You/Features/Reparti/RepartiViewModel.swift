//
//  RepartiViewModel.swift
//  Sinfonia4You
//
//  ViewModel per catalogo reparti, snapshot modulo e dettagli gara/referto.
//

import Combine
import Foundation
import UIKit

struct RefertoDirectorPlayerRowState: Identifiable {
    let section: String
    var order: Int
    var shirtNumber: String
    var personId: String
    var captainCode: String
    var documentType: String
    var documentNumber: String

    var id: String { "\(section)-\(order)" }
}

struct RefertoDirectorStaffRowState: Identifiable {
    var order: Int
    var roleId: String
    var personId: String
    var documentType: String
    var documentNumber: String

    var id: String { "staff-\(order)" }
}

struct RefertoDirectorTeamState {
    var teamId: String
    var teamName: String
    var availablePeople: [RefertoPersonaDisponibileDTO]
    var starters: [RefertoDirectorPlayerRowState]
    var substitutes: [RefertoDirectorPlayerRowState]
    var staff: [RefertoDirectorStaffRowState]

    static let empty = RefertoDirectorTeamState(
        teamId: "",
        teamName: "",
        availablePeople: [],
        starters: [],
        substitutes: [],
        staff: []
    )
}

struct RefertoDirectorDurationRowState: Identifiable {
    let id: UUID
    var phaseId: String
    var periodNumber: Int
    var markerType: String
    var order: Int
    var durationType: String
    var minutes: String
    var note: String
    var startTime: String
    var endTime: String

    init(
        id: UUID = UUID(),
        phaseId: String,
        periodNumber: Int,
        markerType: String,
        order: Int,
        durationType: String,
        minutes: String,
        note: String,
        startTime: String,
        endTime: String
    ) {
        self.id = id
        self.phaseId = phaseId
        self.periodNumber = periodNumber
        self.markerType = markerType
        self.order = order
        self.durationType = durationType
        self.minutes = minutes
        self.note = note
        self.startTime = startTime
        self.endTime = endTime
    }
}

struct RefertoDirectorDurationSegmentState: Identifiable {
    var phaseId: String
    var periodNumber: Int
    var markerType: String
    var title: String
    var rows: [RefertoDirectorDurationRowState]

    var id: String { "\(phaseId)-\(periodNumber)-\(markerType)" }
    var isInterval: Bool { markerType == "I" }
}

struct RefertoManualPersonDraftState {
    var matricola = ""
    var lastName = ""
    var firstName = ""
    var birthDate = ""
    var birthPlaceCode = ""
    var birthPlaceLabel = ""
    var sex = "M"
    var taxCode = ""

    static let empty = RefertoManualPersonDraftState()
}

@MainActor
final class CatalogoRepartiViewModel: ObservableObject {
    @Published var gruppi: [GruppoRepartiDTO] = []
    @Published var inCaricamento = false
    @Published var errore = ""

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func carica(token: String) async {
        guard gruppi.isEmpty else { return }
        inCaricamento = true
        errore = ""
        defer { inCaricamento = false }

        do {
            let catalogo = try await apiClient.catalogoReparti(token: token)
            gruppi = catalogo.groups
        } catch {
            errore = error.localizedDescription
        }
    }
}

@MainActor
final class SnapshotModuloViewModel: ObservableObject {
    @Published var snapshot: SnapshotModuloDTO?
    @Published var inCaricamento = false
    @Published var errore = ""

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func carica(
        token: String,
        moduleId: String,
        dateFrom: String? = nil,
        dateTo: String? = nil
    ) async {
        inCaricamento = true
        errore = ""
        defer { inCaricamento = false }

        do {
            snapshot = try await apiClient.snapshotModulo(
                token: token,
                moduleId: moduleId,
                dateFrom: dateFrom,
                dateTo: dateTo
            )
        } catch {
            errore = error.localizedDescription
        }
    }
}

@MainActor
final class DettaglioGaraViewModel: ObservableObject {
    private struct CachedClassificaEntry {
        let expiresAt: Date
        let value: ClassificaGaraDTO
    }

    private static let classificaCacheTTL: TimeInterval = 300
    private static let classificaCacheLock = NSLock()
    private static var cachedClassifiche: [String: CachedClassificaEntry] = [:]

    @Published var dettaglio: DettaglioGaraDTO?
    @Published var classifica: ClassificaGaraDTO?
    @Published var inCaricamento = false
    @Published var inCaricamentoClassifica = false
    @Published var inAzione = false
    @Published var errore = ""
    @Published var erroreClassifica = ""
    @Published var messaggioOperazione = ""

    private let apiClient: APIClient
    private var classificaTask: Task<Void, Never>?
    private var classificaFallbackSwitchTask: Task<Void, Never>?
    private var classificaRequestID = UUID()
    private var pendingDirectClassificaFallback = false

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    deinit {
        classificaTask?.cancel()
        classificaFallbackSwitchTask?.cancel()
    }

    func carica(token: String, designazioneId: String) async {
        let requestID = UUID()
        classificaRequestID = requestID
        classificaTask?.cancel()
        classificaFallbackSwitchTask?.cancel()
        pendingDirectClassificaFallback = false
        let cachedClassifica = Self.cachedClassifica(for: designazioneId)
        inCaricamento = true
        inCaricamentoClassifica = cachedClassifica == nil
        errore = ""
        erroreClassifica = ""
        messaggioOperazione = ""
        classifica = cachedClassifica
        defer { inCaricamento = false }

        avviaCaricamentoClassifica(
            token: token,
            designazioneId: designazioneId,
            requestID: requestID
        )

        do {
            let loadedDettaglio = try await apiClient.dettaglioGara(token: token, designazioneId: designazioneId)
            dettaglio = loadedDettaglio

            if pendingDirectClassificaFallback && classifica == nil {
                pendingDirectClassificaFallback = false
                avviaCaricamentoClassificaDiretto(
                    match: loadedDettaglio.match,
                    designazioneId: designazioneId,
                    requestID: requestID
                )
            } else if let currentClassifica = classifica,
                      currentClassifica.homeRow == nil || currentClassifica.awayRow == nil {
                avviaCaricamentoClassificaDiretto(
                    match: loadedDettaglio.match,
                    designazioneId: designazioneId,
                    requestID: requestID
                )
            } else {
                programmaFallbackDirettoSeNecessario(
                    match: loadedDettaglio.match,
                    designazioneId: designazioneId,
                    requestID: requestID
                )
            }
        } catch {
            classificaTask?.cancel()
            classificaFallbackSwitchTask?.cancel()
            inCaricamentoClassifica = false
            errore = error.localizedDescription
            classifica = nil
            erroreClassifica = ""
        }
    }

    private func avviaCaricamentoClassifica(token: String, designazioneId: String, requestID: UUID) {
        inCaricamentoClassifica = true
        erroreClassifica = ""

        classificaTask = Task { [apiClient] in
            do {
                let loadedClassifica = try await apiClient.classificaGara(token: token, designazioneId: designazioneId)
                TuttocampoTeamLogoStore.prefetch(
                    rows: loadedClassifica.rows,
                    prioritizedRows: [loadedClassifica.homeRow, loadedClassifica.awayRow]
                )
                let resolvedClassifica = await TuttocampoOfficialStandingsLoader.loadReplacingFallback(loadedClassifica)
                Self.storeClassifica(resolvedClassifica, for: designazioneId)
                TuttocampoTeamLogoStore.prefetch(
                    rows: resolvedClassifica.rows,
                    prioritizedRows: [resolvedClassifica.homeRow, resolvedClassifica.awayRow]
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard requestID == self.classificaRequestID else { return }
                    self.classificaFallbackSwitchTask?.cancel()
                    self.classifica = resolvedClassifica
                    self.inCaricamentoClassifica = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    guard requestID == self.classificaRequestID else { return }
                    self.classificaFallbackSwitchTask?.cancel()
                    self.inCaricamentoClassifica = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                let dettaglioMatch = await MainActor.run { self.dettaglio?.match }
                if let dettaglioMatch,
                   let recoveredClassifica = await TuttocampoOfficialStandingsLoader.loadDirectFromMatch(dettaglioMatch) {
                    Self.storeClassifica(recoveredClassifica, for: designazioneId)
                    TuttocampoTeamLogoStore.prefetch(
                        rows: recoveredClassifica.rows,
                        prioritizedRows: [recoveredClassifica.homeRow, recoveredClassifica.awayRow]
                    )
                    await MainActor.run {
                        guard requestID == self.classificaRequestID else { return }
                        self.classificaFallbackSwitchTask?.cancel()
                        self.classifica = recoveredClassifica
                        self.erroreClassifica = ""
                        self.inCaricamentoClassifica = false
                    }
                    return
                }
                await MainActor.run {
                    guard requestID == self.classificaRequestID else { return }
                    if self.classifica == nil && self.dettaglio == nil {
                        self.pendingDirectClassificaFallback = true
                    } else if self.classifica == nil {
                        self.erroreClassifica = error.localizedDescription
                    }
                    self.inCaricamentoClassifica = false
                }
            }
        }
    }

    private func programmaFallbackDirettoSeNecessario(
        match: MatchAssignmentDTO,
        designazioneId: String,
        requestID: UUID
    ) {
        classificaFallbackSwitchTask?.cancel()
        classificaFallbackSwitchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self else { return }
            guard requestID == self.classificaRequestID else { return }
            let needsDirectFallback = {
                guard let currentClassifica = self.classifica else { return true }
                return currentClassifica.homeRow == nil || currentClassifica.awayRow == nil
            }()
            guard needsDirectFallback else { return }
            self.avviaCaricamentoClassificaDiretto(
                match: match,
                designazioneId: designazioneId,
                requestID: requestID
            )
        }
    }

    private func avviaCaricamentoClassificaDiretto(
        match: MatchAssignmentDTO,
        designazioneId: String,
        requestID: UUID
    ) {
        classificaTask?.cancel()
        classificaFallbackSwitchTask?.cancel()
        inCaricamentoClassifica = true
        erroreClassifica = ""

        classificaTask = Task {
            let recoveredClassifica = await TuttocampoOfficialStandingsLoader.loadDirectFromMatch(match)
            guard !Task.isCancelled else { return }

            if let recoveredClassifica {
                Self.storeClassifica(recoveredClassifica, for: designazioneId)
                TuttocampoTeamLogoStore.prefetch(
                    rows: recoveredClassifica.rows,
                    prioritizedRows: [recoveredClassifica.homeRow, recoveredClassifica.awayRow]
                )
            }

            await MainActor.run {
                guard requestID == self.classificaRequestID else { return }
                if let recoveredClassifica {
                    self.classifica = recoveredClassifica
                    self.erroreClassifica = ""
                } else if self.classifica == nil {
                    self.erroreClassifica = "Classifica ufficiale non disponibile per questa gara."
                }
                self.inCaricamentoClassifica = false
            }
        }
    }

    func eseguiAzione(token: String, designazioneId: String, action: String) async {
        guard !inAzione else { return }
        inAzione = true
        errore = ""
        messaggioOperazione = ""
        defer { inAzione = false }

        do {
            dettaglio = try await apiClient.eseguiAzioneGara(
                token: token,
                designazioneId: designazioneId,
                action: action
            )
            messaggioOperazione = action == "accept" ? "Gara accettata con successo." : "Gara rifiutata con successo."
        } catch {
            errore = error.localizedDescription
        }
    }

    private static func cachedClassifica(for designazioneId: String) -> ClassificaGaraDTO? {
        classificaCacheLock.lock()
        defer { classificaCacheLock.unlock() }

        guard let cached = cachedClassifiche[designazioneId] else {
            return nil
        }

        guard cached.expiresAt > Date() else {
            cachedClassifiche.removeValue(forKey: designazioneId)
            return nil
        }

        return cached.value
    }

    private static func storeClassifica(_ classifica: ClassificaGaraDTO, for designazioneId: String) {
        classificaCacheLock.lock()
        defer { classificaCacheLock.unlock() }

        cachedClassifiche[designazioneId] = CachedClassificaEntry(
            expiresAt: Date().addingTimeInterval(classificaCacheTTL),
            value: classifica
        )
    }
}

enum TuttocampoTeamLogoStore {
    private static let preferredLogoSize = 40
    private static let lock = NSLock()
    private static var teamIDsByNormalizedName: [String: String] = [:]
    private static var inflightImageTasks: [String: Task<UIImage?, Never>] = [:]
    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 256
        return cache
    }()

    static func logoURL(for row: RigaClassificaDTO?, fallbackTeamName: String? = nil, size: Int = 40) -> URL? {
        if let row, let teamID = resolvedTeamID(from: row) {
            return logoURL(forTeamID: teamID, size: size)
        }

        guard
            let fallbackTeamName,
            let teamID = cachedTeamID(forTeamName: fallbackTeamName)
        else {
            return nil
        }

        return logoURL(forTeamID: teamID, size: size)
    }

    static func prefetch(rows: [RigaClassificaDTO], prioritizedRows: [RigaClassificaDTO?] = []) {
        register(rows: rows)

        let orderedRows = prioritizedRows.compactMap { $0 } + rows
        var seen = Set<String>()
        let uniqueURLs = orderedRows.compactMap { logoURL(for: $0, size: preferredLogoSize) }
            .filter { seen.insert($0.absoluteString).inserted }

        guard !uniqueURLs.isEmpty else { return }

        for url in uniqueURLs {
            Task.detached(priority: .utility) {
                _ = await loadImage(from: url)
            }
        }
    }

    static func cachedImage(for url: URL?) -> UIImage? {
        guard let url else { return nil }
        let key = assetKey(for: url)
        lock.lock()
        defer { lock.unlock() }
        return imageCache.object(forKey: key as NSString)
    }

    static func loadImage(from url: URL) async -> UIImage? {
        let key = assetKey(for: url)

        lock.lock()
        if let cached = imageCache.object(forKey: key as NSString) {
            lock.unlock()
            return cached
        }

        if let task = inflightImageTasks[key] {
            lock.unlock()
            return await task.value
        }

        let task = Task<UIImage?, Never>(priority: .utility) {
            let candidateURLs = candidateLogoURLs(from: url)
            var resolvedImage: UIImage?

            for candidateURL in candidateURLs {
                var request = URLRequest(url: candidateURL)
                request.cachePolicy = .returnCacheDataElseLoad

                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse,
                       200..<300 ~= httpResponse.statusCode,
                       let decoded = UIImage(data: data) {
                        resolvedImage = decoded
                        break
                    }
                } catch {
                    continue
                }
            }

            lock.lock()
            if let resolvedImage {
                imageCache.setObject(resolvedImage, forKey: key as NSString)
            }
            inflightImageTasks.removeValue(forKey: key)
            lock.unlock()
            return resolvedImage
        }

        inflightImageTasks[key] = task
        lock.unlock()
        return await task.value
    }

    private static func register(rows: [RigaClassificaDTO]) {
        let pairs = rows.compactMap { row -> (String, String)? in
            guard let teamID = resolvedTeamID(from: row) else { return nil }
            let normalized = normalizedTeamName(row.team)
            guard !normalized.isEmpty else { return nil }
            return (normalized, teamID)
        }

        guard !pairs.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }

        for (normalized, teamID) in pairs {
            teamIDsByNormalizedName[normalized] = teamID
        }
    }

    private static func cachedTeamID(forTeamName teamName: String) -> String? {
        let normalized = normalizedTeamName(teamName)
        guard !normalized.isEmpty else { return nil }

        lock.lock()
        defer { lock.unlock() }
        if let exact = teamIDsByNormalizedName[normalized] {
            return exact
        }

        let bestMatch = teamIDsByNormalizedName
            .map { entry in
                (teamID: entry.value, score: similarityScore(normalized, entry.key))
            }
            .max { lhs, rhs in
                lhs.score < rhs.score
            }

        guard let bestMatch, bestMatch.score >= 0.74 else {
            return nil
        }

        return bestMatch.teamID
    }

    private static func logoURL(forTeamID teamID: String, size: Int) -> URL? {
        guard !teamID.isEmpty else { return nil }
        return URL(string: "https://b2-content.tuttocampo.it/Teams/\(size)/\(teamID).png")
    }

    private static func resolvedTeamID(from row: RigaClassificaDTO) -> String? {
        let direct = row.teamId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !direct.isEmpty {
            return direct
        }

        let link = row.teamLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else { return nil }

        let pattern = #"/(\d+)(?:/|$)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: link, range: NSRange(link.startIndex..<link.endIndex, in: link)),
            match.numberOfRanges >= 2,
            let range = Range(match.range(at: 1), in: link)
        else {
            return nil
        }

        return String(link[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedTeamName(_ value: String) -> String {
        let scrubbed = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT"))
            .replacingOccurrences(of: #"\bunder[\s\-]?1[56789]\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bu[\s\-]?1[56789]\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bjuniores?\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\ballievi\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bgiovanissimi\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\belite\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bdilettantistica\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bresponsabilita\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\blimitata\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bsrls?\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\barl\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
        let stopwords: Set<String> = [
            "a", "s", "d", "asd", "ssd", "societa", "sportiva",
            "polisportiva", "polis", "club", "team", "fc", "fcd",
            "ac", "sc", "us", "usd", "u", "calcio"
        ]

        return scrubbed
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                guard !token.isEmpty else { return false }
                if token.count == 1 && !token.allSatisfy(\.isNumber) {
                    return false
                }
                return !stopwords.contains(token)
            }
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func similarityScore(_ lhs: String, _ rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        if lhs == rhs { return 1 }
        if lhs.contains(rhs) || rhs.contains(lhs) { return 0.95 }

        let lhsTokens = Set(lhs.split(separator: " ").map(String.init))
        let rhsTokens = Set(rhs.split(separator: " ").map(String.init))
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else { return 0 }

        let overlap = lhsTokens.intersection(rhsTokens).count
        let union = lhsTokens.union(rhsTokens).count
        let denominator = max(lhsTokens.count, rhsTokens.count)
        let overlapScore = Double(overlap) / Double(denominator)
        let jaccardScore = union == 0 ? 0 : Double(overlap) / Double(union)
        return max(overlapScore, jaccardScore)
    }

    private static func assetKey(for url: URL) -> String {
        if let teamID = teamIDFromLogoURL(url) {
            return teamID
        }
        return url.absoluteString
    }

    private static func candidateLogoURLs(from url: URL) -> [URL] {
        guard let teamID = teamIDFromLogoURL(url) else {
            return [url]
        }

        let requestedSize = requestedLogoSize(from: url)
        let orderedSizes = [requestedSize, preferredLogoSize, 72, 80, 64, 48, 32]
            .filter { $0 > 0 }

        var seen = Set<Int>()
        return orderedSizes.compactMap { size in
            guard seen.insert(size).inserted else { return nil }
            return logoURL(forTeamID: teamID, size: size)
        }
    }

    private static func teamIDFromLogoURL(_ url: URL) -> String? {
        let components = url.pathComponents
        guard
            let teamsIndex = components.firstIndex(of: "Teams"),
            components.indices.contains(teamsIndex + 2)
        else {
            return nil
        }

        let raw = components[teamsIndex + 2]
        return raw.replacingOccurrences(of: ".png", with: "")
    }

    private static func requestedLogoSize(from url: URL) -> Int {
        let components = url.pathComponents
        guard
            let teamsIndex = components.firstIndex(of: "Teams"),
            components.indices.contains(teamsIndex + 1)
        else {
            return preferredLogoSize
        }

        return Int(components[teamsIndex + 1]) ?? preferredLogoSize
    }
}

struct TuttocampoOfficialStandingsPageParameters: Equatable {
    let tckk: String
    let roundID: String
}

enum TuttocampoOfficialStandingsParser {
    static func parsePageParameters(from html: String) -> TuttocampoOfficialStandingsPageParameters? {
        guard
            let tckk = firstMatch(in: html, pattern: #"var\s+tckk\s*=\s*'([^']+)'"#),
            let roundID = firstMatch(in: html, pattern: #"var\s+roundID\s*=\s*'([^']+)'"#)
        else {
            return nil
        }

        let cleanedTckk = tckk.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedRoundID = roundID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTckk.isEmpty, !cleanedRoundID.isEmpty else {
            return nil
        }

        return TuttocampoOfficialStandingsPageParameters(tckk: cleanedTckk, roundID: cleanedRoundID)
    }

    static func parseRows(from html: String) -> [RigaClassificaDTO] {
        let rowPattern = #"<tr\b[^>]*data-team-id="([^"]*)"[^>]*>(.*?)</tr>"#
        let cellPattern = #"<td\b[^>]*>(.*?)</td>"#
        let linkPattern = #"<a\b[^>]*href="([^"]+)"[^>]*>"#

        let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let cellRegex = try? NSRegularExpression(pattern: cellPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])

        guard let rowRegex, let cellRegex else { return [] }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = rowRegex.matches(in: html, options: [], range: range)
        var rows: [RigaClassificaDTO] = []

        for (index, match) in matches.enumerated() {
            guard
                match.numberOfRanges >= 3,
                let teamIDRange = Range(match.range(at: 1), in: html),
                let rowHTMLRange = Range(match.range(at: 2), in: html)
            else {
                continue
            }

            let teamID = String(html[teamIDRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rowHTML = String(html[rowHTMLRange])
            let cellMatches = cellRegex.matches(
                in: rowHTML,
                options: [],
                range: NSRange(rowHTML.startIndex..<rowHTML.endIndex, in: rowHTML)
            )

            let cells = cellMatches.compactMap { match -> String? in
                guard
                    match.numberOfRanges >= 2,
                    let range = Range(match.range(at: 1), in: rowHTML)
                else {
                    return nil
                }
                return plainText(fromHTML: String(rowHTML[range]))
            }

            guard cells.count >= 11 else { continue }

            let teamName = cells[2]
            guard !teamName.isEmpty else { continue }

            let teamLink: String
            if let linkRegex,
               let linkMatch = linkRegex.firstMatch(
                in: rowHTML,
                options: [],
                range: NSRange(rowHTML.startIndex..<rowHTML.endIndex, in: rowHTML)
               ),
               linkMatch.numberOfRanges >= 2,
               let linkRange = Range(linkMatch.range(at: 1), in: rowHTML) {
                teamLink = String(rowHTML[linkRange])
            } else {
                teamLink = ""
            }

            rows.append(
                RigaClassificaDTO(
                    position: index + 1,
                    teamId: teamID,
                    team: teamName,
                    teamLink: teamLink,
                    points: integerValue(from: cells[3]),
                    played: integerValue(from: cells[4]),
                    won: integerValue(from: cells[5]),
                    draw: integerValue(from: cells[6]),
                    lost: integerValue(from: cells[7]),
                    goalsFor: integerValue(from: cells[8]),
                    goalsAgainst: integerValue(from: cells[9]),
                    goalDiff: integerValue(from: cells[10])
                )
            )
        }

        return rows
    }

    private static func firstMatch(in value: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard
            let match = regex.firstMatch(in: value, options: [], range: range),
            match.numberOfRanges >= 2,
            let captureRange = Range(match.range(at: 1), in: value)
        else {
            return nil
        }

        return String(value[captureRange])
    }

    private static func integerValue(from raw: String) -> Int {
        Int(raw.replacingOccurrences(of: #"[^0-9\-]"#, with: "", options: .regularExpression)) ?? 0
    }

    private static func plainText(fromHTML html: String) -> String {
        let breaksNormalized = html.replacingOccurrences(
            of: #"<br\s*/?>"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )

        let stripped = breaksNormalized.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )

        return decodeHTMLEntities(in: stripped)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeHTMLEntities(in value: String) -> String {
        guard let data = "<span>\(value)</span>".data(using: .utf8) else {
            return value
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return value
        }

        return attributed.string
    }
}

private enum TuttocampoOfficialStandingsLoader {
    private struct CachedStandings {
        let expiresAt: Date
        let rows: [RigaClassificaDTO]
    }

    private struct CachedParameters {
        let expiresAt: Date
        let parameters: TuttocampoOfficialStandingsPageParameters
    }

    private struct ResolvedRowsCandidate {
        let homeRow: RigaClassificaDTO?
        let awayRow: RigaClassificaDTO?
        let homeScore: Double
        let awayScore: Double

        var matchedTeamsCount: Int {
            [homeRow, awayRow].compactMap { $0 }.count
        }

        var combinedScore: Double {
            homeScore + awayScore
        }
    }

    private static let cacheTTL: TimeInterval = 300
    private static let parametersCacheTTL: TimeInterval = 1800
    private static let cacheLock = NSLock()
    private static var cache: [String: CachedStandings] = [:]
    private static var parametersCache: [String: CachedParameters] = [:]
    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    private static let campaniaDiscoveryPaths = [
        "Campania",
        "Campania/AV",
        "Campania/BN",
        "Campania/CE",
        "Campania/NA",
        "Campania/SA"
    ]
    private static let categoryVariantsMap: [String: [String]] = [
        "ECC": ["Eccellenza"],
        "PRO": ["Promozione"],
        "PRI": ["Prima Categoria", "PrimaCategoria"],
        "SEC": ["Seconda Categoria", "SecondaCategoria"],
        "TER": ["Terza Categoria", "TerzaCategoria"],
        "JUN": [
            "Juniores",
            "Juniores Regionali U19",
            "JunioresRegionaliU19",
            "Juniores Nazionali U19",
            "JunioresNazionaliU19",
            "Under 19",
            "U19"
        ],
        "ALL": [
            "Allievi",
            "Allievi Regionali U18",
            "AllieviRegionaliU18",
            "Allievi Nazionali U17",
            "AllieviNazionaliU17"
        ],
        "GIO": [
            "Giovanissimi",
            "Giovanissimi Elite U15",
            "GiovanissimiEliteU15",
            "Giovanissimi Regionali U15",
            "GiovanissimiRegionaliU15",
            "Giovanissimi Nazionali U15",
            "GiovanissimiNazionaliU15"
        ],
        "CZ3": ["Campionato Primavera 3", "Primavera 3", "CampionatoPrimavera3"],
        "CZ4": ["Campionato Primavera 4", "Primavera 4", "CampionatoPrimavera4"]
    ]

    static func loadReplacingFallback(_ fallback: ClassificaGaraDTO) async -> ClassificaGaraDTO {
        guard let pageURL = officialClassificaURL(from: fallback.classificaUrl) else {
            return fallback
        }

        do {
            let session = makeSession()
            let rows = try await loadRows(session: session, pageURL: pageURL)
            guard !rows.isEmpty else {
                return fallback
            }
            return fallback.replacingRowsWithOfficial(rows)
        } catch {
            return fallback
        }
    }

    static func loadDirectFromMatch(_ match: MatchAssignmentDTO) async -> ClassificaGaraDTO? {
        let candidateURLs = directClassificaURLs(for: match)
        guard !candidateURLs.isEmpty else {
            return nil
        }

        let session = makeSession()
        var bestCandidate: (url: URL, rows: [RigaClassificaDTO], resolved: ResolvedRowsCandidate)?

        for candidate in candidateURLs {
            guard let pageURL = officialClassificaURL(from: candidate) else {
                continue
            }

            do {
                let rows = try await loadRows(session: session, pageURL: pageURL)
                guard !rows.isEmpty else {
                    continue
                }

                let resolved = resolveRows(
                    rows: rows,
                    homeTeam: match.homeTeam,
                    awayTeam: match.awayTeam
                )

                if let currentBest = bestCandidate {
                    let shouldReplace =
                        resolved.matchedTeamsCount > currentBest.resolved.matchedTeamsCount
                        || (
                            resolved.matchedTeamsCount == currentBest.resolved.matchedTeamsCount
                            && resolved.combinedScore > currentBest.resolved.combinedScore
                        )
                    if shouldReplace {
                        bestCandidate = (pageURL, rows, resolved)
                    }
                } else {
                    bestCandidate = (pageURL, rows, resolved)
                }

                if resolved.matchedTeamsCount == 2, resolved.homeScore >= 0.84, resolved.awayScore >= 0.84 {
                    return buildClassificaDTO(
                        match: match,
                        pageURL: pageURL,
                        rows: rows,
                        resolved: resolved
                    )
                }
            } catch {
                continue
            }
        }

        guard let bestCandidate, bestCandidate.resolved.matchedTeamsCount > 0 else {
            return nil
        }

        return buildClassificaDTO(
            match: match,
            pageURL: bestCandidate.url,
            rows: bestCandidate.rows,
            resolved: bestCandidate.resolved
        )
    }

    private static func loadRows(session: URLSession, pageURL: URL) async throws -> [RigaClassificaDTO] {
        let cacheKey = pageURL.absoluteString.lowercased()
        if let cachedRows = cachedRows(for: cacheKey), !cachedRows.isEmpty {
            return cachedRows
        }

        let rows: [RigaClassificaDTO]
        if let parameters = cachedParameters(for: cacheKey) {
            let rankingURL = buildRankingURL(pageURL: pageURL, parameters: parameters)
            let rankingHTML = try await fetchHTML(
                session: session,
                url: rankingURL,
                referer: pageURL.absoluteString,
                isAJAX: true
            )
            rows = TuttocampoOfficialStandingsParser.parseRows(from: rankingHTML)
        } else {
            let pageHTML = try await fetchHTML(session: session, url: pageURL, referer: nil, isAJAX: false)

            if pageHTML.contains("table_ranking") {
                rows = TuttocampoOfficialStandingsParser.parseRows(from: pageHTML)
            } else if let parameters = TuttocampoOfficialStandingsParser.parsePageParameters(from: pageHTML) {
                storeParameters(parameters, for: cacheKey)
                let rankingURL = buildRankingURL(pageURL: pageURL, parameters: parameters)
                let rankingHTML = try await fetchHTML(
                    session: session,
                    url: rankingURL,
                    referer: pageURL.absoluteString,
                    isAJAX: true
                )
                rows = TuttocampoOfficialStandingsParser.parseRows(from: rankingHTML)
            } else {
                return []
            }
        }

        if !rows.isEmpty {
            storeRows(rows, for: cacheKey)
        }
        return rows
    }

    private static func buildClassificaDTO(
        match: MatchAssignmentDTO,
        pageURL: URL,
        rows: [RigaClassificaDTO],
        resolved: ResolvedRowsCandidate? = nil
    ) -> ClassificaGaraDTO {
        let resolvedRows = resolved ?? resolveRows(
            rows: rows,
            homeTeam: match.homeTeam,
            awayTeam: match.awayTeam
        )
        let competitionLabel = [cleanText(match.category), cleanText(match.group)]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")

        return ClassificaGaraDTO(
            competitionLabel: competitionLabel,
            areaLabel: areaLabel(from: pageURL),
            classificaUrl: pageURL.absoluteString,
            homeRow: resolvedRows.homeRow,
            awayRow: resolvedRows.awayRow,
            homeScore: resolvedRows.homeScore,
            awayScore: resolvedRows.awayScore,
            rows: rows
        )
    }

    private static func resolveRows(
        rows: [RigaClassificaDTO],
        homeTeam: String,
        awayTeam: String
    ) -> ResolvedRowsCandidate {
        var usedTeamIDs = Set<String>()
        let home = bestRowMatch(for: homeTeam, rows: rows, usedTeamIDs: &usedTeamIDs)
        let away = bestRowMatch(for: awayTeam, rows: rows, usedTeamIDs: &usedTeamIDs)
        return ResolvedRowsCandidate(
            homeRow: home.row,
            awayRow: away.row,
            homeScore: home.score,
            awayScore: away.score
        )
    }

    private static func bestRowMatch(
        for teamName: String,
        rows: [RigaClassificaDTO],
        usedTeamIDs: inout Set<String>
    ) -> (row: RigaClassificaDTO?, score: Double) {
        let normalizedTarget = normalizedTeamName(teamName)
        guard !normalizedTarget.isEmpty else {
            return (nil, 0)
        }

        let bestMatch = rows
            .filter { $0.teamId.isEmpty || !usedTeamIDs.contains($0.teamId) }
            .map { row in
                (row, similarityScore(normalizedTarget, normalizedTeamName(row.team)))
            }
            .max { lhs, rhs in
                lhs.1 < rhs.1
            }

        guard let (row, score) = bestMatch, score >= 0.72 else {
            return (nil, bestMatch?.1 ?? 0)
        }

        if !row.teamId.isEmpty {
            usedTeamIDs.insert(row.teamId)
        }
        return (row, score)
    }

    private static func directClassificaURLs(for match: MatchAssignmentDTO) -> [String] {
        let categorySegments = categoryVariants(for: match.category)
            .map { slugifySegment($0) }
            .filter { !$0.isEmpty }
        let groupSegments = groupVariants(for: match)
        let areaPaths = areaVariants(for: match)

        guard !categorySegments.isEmpty, !groupSegments.isEmpty, !areaPaths.isEmpty else {
            return []
        }

        var results: [String] = []
        var seen = Set<String>()

        for categorySegment in categorySegments {
            for groupSegment in groupSegments {
                let roundPath = "\(categorySegment)/\(groupSegment)"
                for origin in ["https://www.tuttocampo.it", "https://b-static.tuttocampo.it"] {
                    for areaPath in areaPaths {
                        let urlString: String
                        if areaPath.isEmpty {
                            urlString = "\(origin)/\(roundPath)/Classifica"
                        } else {
                            urlString = "\(origin)/\(areaPath)/\(roundPath)/Classifica"
                        }

                        let key = urlString.lowercased()
                        if seen.insert(key).inserted {
                            results.append(urlString)
                        }
                    }
                }
            }
        }

        return results
    }

    private static func areaVariants(for match: MatchAssignmentDTO) -> [String] {
        if isNationalCategory(match.category) {
            return ["", "Italia"]
        }

        var areas = campaniaDiscoveryPaths
        if isYouthCategory(match.category) {
            areas.append("Italia")
        }
        return areas
    }

    private static func groupVariants(for match: MatchAssignmentDTO) -> [String] {
        let rawGroup = cleanText(match.group)
        if rawGroup.isEmpty {
            let key = normalizeLookupText(match.category)
            if key.contains("serie a") || key.contains("serie b") {
                return ["GironeUnico"]
            }
            return []
        }

        let groupSegment = slugifySegment(rawGroup)
        guard !groupSegment.isEmpty else {
            return []
        }

        var variants: [String] = []
        func append(_ value: String) {
            guard !value.isEmpty else { return }
            if !variants.contains(value) {
                variants.append(value)
            }
        }

        let baseGroup: String
        if groupSegment.lowercased().hasPrefix("girone") {
            baseGroup = String(groupSegment.dropFirst("Girone".count))
        } else {
            baseGroup = groupSegment
        }

        if isNationalCategory(match.category), !baseGroup.isEmpty {
            append("Girone\(baseGroup)Nazionali")
        }

        if groupSegment.lowercased().hasPrefix("girone") {
            append(groupSegment)
        } else {
            append("Girone\(groupSegment)")
        }

        return variants
    }

    private static func categoryVariants(for value: String) -> [String] {
        let clean = cleanText(value).uppercased()
        var variants: [String] = []

        func append(_ items: String...) {
            for item in items where !item.isEmpty && !variants.contains(item) {
                variants.append(item)
            }
        }

        if clean.hasPrefix("ECC") {
            append("Eccellenza")
        } else if clean.hasPrefix("PRO") {
            append("Promozione")
        } else if clean.hasPrefix("PRI") {
            append("Prima Categoria")
        } else if clean.hasPrefix("SEC") {
            append("Seconda Categoria")
        } else if clean.hasPrefix("TER") {
            append("Terza Categoria")
        } else if clean.hasPrefix("ALL") {
            if isNationalCategory(value) {
                append("Allievi Nazionali U17", "AllieviNazionaliU17")
            }
            append("Allievi Regionali U18", "AllieviRegionaliU18", "Allievi")
        } else if clean.hasPrefix("GIO") {
            if isNationalCategory(value) {
                append("Giovanissimi Nazionali U15", "GiovanissimiNazionaliU15")
            }
            append(
                "Giovanissimi Elite U15",
                "GiovanissimiEliteU15",
                "Giovanissimi Regionali U15",
                "GiovanissimiRegionaliU15",
                "Giovanissimi"
            )
        } else if clean.hasPrefix("JUN") {
            if isNationalCategory(value) {
                append("Juniores Nazionali U19", "Juniores Nazionali")
            }
            append("Juniores Regionali U19", "JunioresRegionaliU19", "Juniores", "Under 19", "U19")
        } else if let mapped = categoryVariantsMap[clean] {
            for item in mapped where !variants.contains(item) {
                variants.append(item)
            }
        }

        let readable = cleanText(value)
        let isShortCode = clean.range(of: #"^[A-Z0-9]{2,6}$"#, options: .regularExpression) != nil
        if !readable.isEmpty && (!isShortCode || variants.isEmpty) {
            append(readable)
        }

        return variants
    }

    private static func isNationalCategory(_ value: String) -> Bool {
        let clean = cleanText(value).uppercased()
        let compact = clean.replacingOccurrences(of: #"[^A-Z0-9]+"#, with: "", options: .regularExpression)
        let key = normalizeLookupText(value)

        if key.contains("nazional")
            || key.contains("interregional")
            || key.contains("serie d")
            || key.contains("serie a")
            || key.contains("serie b")
            || key.contains("serie c")
            || key.contains("primavera")
            || key.contains("coppa italia")
            || key.contains("supercoppa")
            || key.contains("champions")
            || key.contains("europa league")
            || key.contains("conference league") {
            return true
        }

        if ["SERIEA", "SERIEB", "SERIEC", "SERIED", "PRIMAVERA"].contains(compact) {
            return true
        }

        if clean.hasPrefix("JUN") && (clean.contains(" I") || compact.contains("NAZ")) {
            return true
        }

        return false
    }

    private static func isYouthCategory(_ value: String) -> Bool {
        let key = normalizeLookupText(value)
        let tokens = ["giovan", "juniores", "allievi", "giovanissimi", "under", "u19", "u18", "u17", "u16", "u15", "u14", "u13", "u12", "primavera"]
        return tokens.contains { key.contains($0) }
    }

    private static func areaLabel(from pageURL: URL) -> String {
        let path = pageURL.path.lowercased()
        if path.contains("/italia/") {
            return "Italia"
        }
        if path.contains("/campania/") {
            return "Campania"
        }
        return ""
    }

    private static func cleanText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeLookupText(_ value: String) -> String {
        cleanText(value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT"))
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func slugifySegment(_ value: String) -> String {
        cleanText(value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT"))
            .replacingOccurrences(of: #"[^A-Za-z0-9]+"#, with: "", options: .regularExpression)
    }

    private static func normalizedTeamName(_ value: String) -> String {
        normalizeLookupText(value)
            .replacingOccurrences(
                of: #"\b(asd|ssd|usd|calcio|football|club|polisportiva|societa|sportiva|dilettantistica|responsabilita|limitata|arl|srl|srls|under|u19|u18|u17|u16|u15|u14|u13|u12|juniores|allievi|giovanissimi|elite|regionali|provinciali)\b"#,
                with: " ",
                options: .regularExpression
            )
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                guard !token.isEmpty else { return false }
                let isNumeric = token.allSatisfy(\.isNumber)
                return isNumeric || token.count > 1
            }
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func similarityScore(_ lhs: String, _ rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        if lhs == rhs { return 1 }
        if lhs.contains(rhs) || rhs.contains(lhs) { return 0.92 }

        let lhsTokens = Set(lhs.split(separator: " ").map(String.init))
        let rhsTokens = Set(rhs.split(separator: " ").map(String.init))
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else { return 0 }

        let intersection = lhsTokens.intersection(rhsTokens).count
        let denominator = max(lhsTokens.count, rhsTokens.count)
        guard denominator > 0 else { return 0 }
        return Double(intersection) / Double(denominator)
    }

    private static func cachedRows(for key: String) -> [RigaClassificaDTO]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let cached = cache[key] else {
            return nil
        }

        guard cached.expiresAt > Date() else {
            cache.removeValue(forKey: key)
            return nil
        }

        return cached.rows
    }

    private static func storeRows(_ rows: [RigaClassificaDTO], for key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        cache[key] = CachedStandings(
            expiresAt: Date().addingTimeInterval(cacheTTL),
            rows: rows
        )
    }

    private static func cachedParameters(for key: String) -> TuttocampoOfficialStandingsPageParameters? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let cached = parametersCache[key] else {
            return nil
        }

        guard cached.expiresAt > Date() else {
            parametersCache.removeValue(forKey: key)
            return nil
        }

        return cached.parameters
    }

    private static func storeParameters(_ parameters: TuttocampoOfficialStandingsPageParameters, for key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        parametersCache[key] = CachedParameters(
            expiresAt: Date().addingTimeInterval(parametersCacheTTL),
            parameters: parameters
        )
    }

    private static func officialClassificaURL(from raw: String) -> URL? {
        guard var components = URLComponents(string: raw), components.scheme != nil else {
            return nil
        }

        if components.host == "b-static.tuttocampo.it" {
            components.host = "www.tuttocampo.it"
        }

        return components.url
    }

    private static func buildRankingURL(
        pageURL: URL,
        parameters: TuttocampoOfficialStandingsPageParameters
    ) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.tuttocampo.it"
        components.path = "/Web/Views/Rankings/RankingView.php"
        components.queryItems = [
            URLQueryItem(name: "tckk", value: parameters.tckk),
            URLQueryItem(name: "v", value: "1"),
            URLQueryItem(name: "category_id", value: parameters.roundID),
            URLQueryItem(name: "total", value: "true"),
            URLQueryItem(name: "is_ranking_tab", value: "true")
        ]
        return components.url ?? pageURL
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Accept-Language": "it-IT,it;q=0.9"
        ]
        return URLSession(configuration: configuration)
    }

    private static func fetchHTML(
        session: URLSession,
        url: URL,
        referer: String?,
        isAJAX: Bool
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        if let referer, !referer.isEmpty {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        if isAJAX {
            request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }
}

private extension ClassificaGaraDTO {
    func replacingRowsWithOfficial(_ rows: [RigaClassificaDTO]) -> ClassificaGaraDTO {
        guard !rows.isEmpty else { return self }

        var usedTeamIDs = Set<String>()

        let resolvedHome = ClassificaGaraDTO.resolveOfficialRow(
            preferredRow: homeRow,
            candidates: rows,
            usedTeamIDs: &usedTeamIDs
        )
        let resolvedAway = ClassificaGaraDTO.resolveOfficialRow(
            preferredRow: awayRow,
            candidates: rows,
            usedTeamIDs: &usedTeamIDs
        )

        return ClassificaGaraDTO(
            competitionLabel: competitionLabel,
            areaLabel: areaLabel,
            classificaUrl: classificaUrl,
            homeRow: resolvedHome,
            awayRow: resolvedAway,
            homeScore: resolvedHome == nil ? homeScore : max(homeScore, 0.99),
            awayScore: resolvedAway == nil ? awayScore : max(awayScore, 0.99),
            rows: rows
        )
    }

    private static func resolveOfficialRow(
        preferredRow: RigaClassificaDTO?,
        candidates: [RigaClassificaDTO],
        usedTeamIDs: inout Set<String>
    ) -> RigaClassificaDTO? {
        guard let preferredRow else {
            return nil
        }

        if !preferredRow.teamId.isEmpty,
           let exactMatch = candidates.first(where: { $0.teamId == preferredRow.teamId && !usedTeamIDs.contains($0.teamId) }) {
            usedTeamIDs.insert(exactMatch.teamId)
            return exactMatch
        }

        let normalizedPreferred = normalizedTeamName(preferredRow.team)
        guard !normalizedPreferred.isEmpty else {
            return nil
        }

        let bestMatch = candidates
            .filter { $0.teamId.isEmpty || !usedTeamIDs.contains($0.teamId) }
            .map { row in
                (row, similarityScore(normalizedPreferred, normalizedTeamName(row.team)))
            }
            .max { lhs, rhs in
                lhs.1 < rhs.1
            }

        guard let (row, score) = bestMatch, score >= 0.72 else {
            return nil
        }

        if !row.teamId.isEmpty {
            usedTeamIDs.insert(row.teamId)
        }
        return row
    }

    private static func normalizedTeamName(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT"))
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func similarityScore(_ lhs: String, _ rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        if lhs == rhs { return 1 }
        if lhs.contains(rhs) || rhs.contains(lhs) { return 0.92 }

        let lhsTokens = Set(lhs.split(separator: " ").map(String.init))
        let rhsTokens = Set(rhs.split(separator: " ").map(String.init))
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else { return 0 }

        let intersection = lhsTokens.intersection(rhsTokens).count
        let denominator = max(lhsTokens.count, rhsTokens.count)
        guard denominator > 0 else { return 0 }
        return Double(intersection) / Double(denominator)
    }
}

@MainActor
final class DettaglioRefertoViewModel: ObservableObject {
    @Published var dettaglio: DettaglioRefertoDTO?
    @Published var inCaricamento = false
    @Published var inSalvataggio = false
    @Published var errore = ""
    @Published var messaggioOperazione = ""
    @Published var segnalazioneSelezionata = "1"
    @Published var noteEventi = ""
    @Published var svolgimentoSelezionato = ""
    @Published var noteSvolgimento = ""
    @Published var directorCurrentTab = ""
    @Published var ordineSelezionato = ""
    @Published var ambulanzaSelezionata = ""
    @Published var noteOrdine = ""
    @Published var directorDurataTitle = ""
    @Published var directorDurataNotice = ""
    @Published var directorDurataStartTitle = ""
    @Published var directorDurataStartTime = ""
    @Published var directorDurataEndTitle = ""
    @Published var directorDurataEndTime = ""
    @Published var directorDurataGameOptions: [RefertoSelectOptionDTO] = []
    @Published var directorDurataIntervalOptions: [RefertoSelectOptionDTO] = []
    @Published var directorDurataRigoriOptions: [RefertoSelectOptionDTO] = []
    @Published var directorRegulationSegments: [RefertoDirectorDurationSegmentState] = []
    @Published var directorExtraSegments: [RefertoDirectorDurationSegmentState] = []
    @Published var directorPenaltySegments: [RefertoDirectorDurationSegmentState] = []
    @Published var listaCasa = RefertoDirectorTeamState.empty
    @Published var listaFuori = RefertoDirectorTeamState.empty
    @Published var anteprimaPronta = false
    @Published var mostraPopupSalvataggioAssistente = false

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func carica(token: String, designazioneId: String) async {
        inCaricamento = true
        errore = ""
        messaggioOperazione = ""
        anteprimaPronta = false
        mostraPopupSalvataggioAssistente = false
        defer { inCaricamento = false }

        do {
            let valore = try await apiClient.dettaglioReferto(token: token, designazioneId: designazioneId)
            dettaglio = valore
            sincronizzaStatoForm(con: valore)
        } catch {
            errore = error.localizedDescription
        }
    }

    func salva(token: String, designazioneId: String) async {
        guard !inSalvataggio else { return }
        errore = ""
        messaggioOperazione = ""

        let isAssistantRole = dettaglio?.roleKind == "assistant"
        let isDirettore = dettaglio?.roleKind != "assistant" && !(dettaglio?.svolgimentoOptions.isEmpty ?? true)
        if isDirettore {
            let tab = directorCurrentTabNormalizzato
            if tab == "durata" {
                if let durationError = validateDurata() {
                    errore = durationError
                    return
                }
                recalculateDurataTimes()
            } else if tab == "sicurezza" {
                let ordine = ordineSelezionato.trimmingCharacters(in: .whitespacesAndNewlines)
                let ambulanza = ambulanzaSelezionata.trimmingCharacters(in: .whitespacesAndNewlines)
                if ordine.isEmpty {
                    errore = "Seleziona le misure d'ordine."
                    return
                }
                if ambulanza.isEmpty {
                    errore = "Seleziona la presenza dell'ambulanza."
                    return
                }
            } else if tab == "liste" {
                if let listeError = validateListeGara(team: listaCasa, fallbackLabel: "squadra locale") {
                    errore = listeError
                    return
                }
                if let listeError = validateListeGara(team: listaFuori, fallbackLabel: "squadra ospite") {
                    errore = listeError
                    return
                }
            } else {
                let svolgimento = svolgimentoSelezionato.trimmingCharacters(in: .whitespacesAndNewlines)
                if svolgimento.isEmpty {
                    errore = "Seleziona lo svolgimento della gara."
                    return
                }
            }
        }

        let segnalazione = segnalazioneSelezionata.trimmingCharacters(in: .whitespacesAndNewlines)
        let notePulite = noteEventi.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isDirettore, segnalazione == "2", notePulite.isEmpty {
            errore = "Per 'Segnala eventi' devi inserire una descrizione."
            return
        }

        inSalvataggio = true
        defer { inSalvataggio = false }

        do {
            let refertoId = dettaglio?.refertoId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let esito = try await apiClient.salvaReferto(
                token: token,
                designazioneId: designazioneId,
                refertoId: refertoId,
                segnalazioneValue: segnalazione,
                noteText: notePulite,
                assistantOnly: isAssistantRole,
                svolgimentoValue: svolgimentoSelezionato,
                svolgimentoNote: noteSvolgimento,
                currentTab: directorCurrentTab,
                ordineValue: ordineSelezionato,
                ambulanzaValue: ambulanzaSelezionata,
                ordineNote: noteOrdine,
                durataRows: payloadDurataRows(),
                listaGaraHome: payloadGiocatori(team: listaCasa),
                listaGaraAway: payloadGiocatori(team: listaFuori),
                listaGaraHomeStaff: payloadDirigenti(team: listaCasa),
                listaGaraAwayStaff: payloadDirigenti(team: listaFuori)
            )
            dettaglio = esito.detail
            sincronizzaStatoForm(con: esito.detail)
            let isAssistant = !isDirettore && esito.detail.roleKind == "assistant"
            if isAssistant {
                anteprimaPronta = false
                if esito.ok && !(esito.warning ?? false) {
                    mostraPopupSalvataggioAssistente = true
                    messaggioOperazione = ""
                } else {
                    errore = esito.message
                }
            } else {
                anteprimaPronta = !isDirettore && esito.ok && !(esito.warning ?? false)
                if esito.ok && !(esito.warning ?? false) {
                    messaggioOperazione = esito.message
                } else {
                    errore = esito.message
                }
            }
        } catch {
            errore = error.localizedDescription
        }
    }

    func selezionaSegnalazione(_ value: String) {
        let normalized = value == "2" ? "2" : "1"
        if segnalazioneSelezionata != normalized {
            anteprimaPronta = false
            messaggioOperazione = ""
            mostraPopupSalvataggioAssistente = false
        }
        segnalazioneSelezionata = normalized
        if normalized == "1" {
            noteEventi = ""
        }
    }

    func aggiornaNoteEventi(_ text: String) {
        if noteEventi != text {
            anteprimaPronta = false
            messaggioOperazione = ""
            mostraPopupSalvataggioAssistente = false
        }
        noteEventi = text
    }

    func annullaAnteprima() {
        anteprimaPronta = false
        messaggioOperazione = ""
        mostraPopupSalvataggioAssistente = false
    }

    func chiudiPopupSalvataggioAssistente() {
        mostraPopupSalvataggioAssistente = false
    }

    private func sincronizzaStatoForm(con dettaglio: DettaglioRefertoDTO) {
        let valore = dettaglio.segnalazioneValue.trimmingCharacters(in: .whitespacesAndNewlines)
        segnalazioneSelezionata = valore.isEmpty ? "1" : valore
        noteEventi = dettaglio.noteText
        svolgimentoSelezionato = dettaglio.svolgimentoValue.trimmingCharacters(in: .whitespacesAndNewlines)
        noteSvolgimento = dettaglio.roleKind == "assistant" ? "" : dettaglio.noteText
        ordineSelezionato = dettaglio.ordineValue.trimmingCharacters(in: .whitespacesAndNewlines)
        ambulanzaSelezionata = dettaglio.ambulanzaValue.trimmingCharacters(in: .whitespacesAndNewlines)
        noteOrdine = dettaglio.ordineNoteText
        directorDurataTitle = dettaglio.durataTitle
        directorDurataNotice = dettaglio.durataNotice
        directorDurataStartTitle = dettaglio.durataStartTitle
        directorDurataStartTime = dettaglio.durataStartTime
        directorDurataEndTitle = dettaglio.durataEndTitle
        directorDurataEndTime = dettaglio.durataEndTime
        directorDurataGameOptions = dettaglio.durataGameOptions
        directorDurataIntervalOptions = dettaglio.durataIntervalOptions
        directorDurataRigoriOptions = dettaglio.durataRigoriOptions
        let durataSegments = makeDurataSegments(from: dettaglio.durataRows)
        directorRegulationSegments = durataSegments.regulations
        directorExtraSegments = durataSegments.extras
        directorPenaltySegments = durataSegments.penalties
        recalculateDurataTimes()
        let listaHome = dettaglio.listaGaraHome
        let listaAway = dettaglio.listaGaraAway
        listaCasa = RefertoDirectorTeamState(
            teamId: listaHome?.teamId ?? "",
            teamName: listaHome?.teamName ?? "",
            availablePeople: listaHome?.availablePeople ?? [],
            starters: (listaHome?.starters ?? []).map {
                RefertoDirectorPlayerRowState(
                    section: "starters",
                    order: $0.order,
                    shirtNumber: $0.shirtNumber,
                    personId: $0.personId,
                    captainCode: $0.captainCode,
                    documentType: $0.documentType,
                    documentNumber: $0.documentNumber
                )
            },
            substitutes: (listaHome?.substitutes ?? []).map {
                RefertoDirectorPlayerRowState(
                    section: "substitutes",
                    order: $0.order,
                    shirtNumber: $0.shirtNumber,
                    personId: $0.personId,
                    captainCode: $0.captainCode,
                    documentType: $0.documentType,
                    documentNumber: $0.documentNumber
                )
            },
            staff: (listaHome?.staff ?? []).map {
                RefertoDirectorStaffRowState(
                    order: $0.order,
                    roleId: $0.roleId,
                    personId: $0.personId,
                    documentType: $0.documentType,
                    documentNumber: $0.documentNumber
                )
            }
        )
        listaFuori = RefertoDirectorTeamState(
            teamId: listaAway?.teamId ?? "",
            teamName: listaAway?.teamName ?? "",
            availablePeople: listaAway?.availablePeople ?? [],
            starters: (listaAway?.starters ?? []).map {
                RefertoDirectorPlayerRowState(
                    section: "starters",
                    order: $0.order,
                    shirtNumber: $0.shirtNumber,
                    personId: $0.personId,
                    captainCode: $0.captainCode,
                    documentType: $0.documentType,
                    documentNumber: $0.documentNumber
                )
            },
            substitutes: (listaAway?.substitutes ?? []).map {
                RefertoDirectorPlayerRowState(
                    section: "substitutes",
                    order: $0.order,
                    shirtNumber: $0.shirtNumber,
                    personId: $0.personId,
                    captainCode: $0.captainCode,
                    documentType: $0.documentType,
                    documentNumber: $0.documentNumber
                )
            },
            staff: (listaAway?.staff ?? []).map {
                RefertoDirectorStaffRowState(
                    order: $0.order,
                    roleId: $0.roleId,
                    personId: $0.personId,
                    documentType: $0.documentType,
                    documentNumber: $0.documentNumber
                )
            }
        )
        if directorCurrentTab.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            directorCurrentTab = dettaglio.currentTab
        }
        mostraPopupSalvataggioAssistente = false
    }

    private var directorCurrentTabNormalizzato: String {
        let raw = directorCurrentTab.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.contains("liste") {
            return "liste"
        }
        if raw.contains("durata") {
            return "durata"
        }
        if raw.contains("sicurezza") {
            return "sicurezza"
        }
        return "svolgimento"
    }

    private func payloadGiocatori(team: RefertoDirectorTeamState) -> [APIClient.SaveRefertoPlayerRowPayload] {
        let starters = team.starters.map {
            APIClient.SaveRefertoPlayerRowPayload(
                order: $0.order,
                shirtNumber: $0.shirtNumber,
                personId: $0.personId,
                captainCode: $0.captainCode,
                documentType: $0.documentType,
                documentNumber: $0.documentNumber,
                section: "starters"
            )
        }
        let substitutes = team.substitutes.map {
            APIClient.SaveRefertoPlayerRowPayload(
                order: $0.order,
                shirtNumber: $0.shirtNumber,
                personId: $0.personId,
                captainCode: $0.captainCode,
                documentType: $0.documentType,
                documentNumber: $0.documentNumber,
                section: "substitutes"
            )
        }
        return starters + substitutes
    }

    private func payloadDirigenti(team: RefertoDirectorTeamState) -> [APIClient.SaveRefertoStaffRowPayload] {
        team.staff.map {
            APIClient.SaveRefertoStaffRowPayload(
                order: $0.order,
                roleId: $0.roleId,
                personId: $0.personId,
                documentType: $0.documentType,
                documentNumber: $0.documentNumber
            )
        }
    }

    private func payloadDurataRows() -> [APIClient.SaveRefertoDurationRowPayload] {
        orderedDurataRows().map {
            APIClient.SaveRefertoDurationRowPayload(
                phaseId: $0.phaseId,
                periodNumber: $0.periodNumber,
                markerType: $0.markerType,
                minutes: $0.minutes,
                durationType: $0.durationType,
                note: $0.note,
                startTime: $0.startTime,
                endTime: $0.endTime,
                order: $0.order
            )
        }
    }

    private func makeDurataSegments(
        from rows: [RefertoDurataRowDTO]
    ) -> (
        regulations: [RefertoDirectorDurationSegmentState],
        extras: [RefertoDirectorDurationSegmentState],
        penalties: [RefertoDirectorDurationSegmentState]
    ) {
        var regulations: [RefertoDirectorDurationSegmentState] = []
        var extras: [RefertoDirectorDurationSegmentState] = []
        var penalties: [RefertoDirectorDurationSegmentState] = []

        let grouped = Dictionary(grouping: rows) {
            "\($0.phaseId)-\($0.periodNumber)-\($0.markerType)"
        }

        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            durationKeyComponents(lhs).lexicographicallyPrecedes(durationKeyComponents(rhs))
        }

        for key in sortedKeys {
            guard let group = grouped[key] else { continue }
            let first = group[0]
            let segment = RefertoDirectorDurationSegmentState(
                phaseId: first.phaseId,
                periodNumber: first.periodNumber,
                markerType: first.markerType,
                title: durationSegmentTitle(
                    phaseId: first.phaseId,
                    periodNumber: first.periodNumber,
                    markerType: first.markerType
                ),
                rows: group
                    .sorted { $0.order < $1.order }
                    .map {
                        RefertoDirectorDurationRowState(
                            phaseId: $0.phaseId,
                            periodNumber: $0.periodNumber,
                            markerType: $0.markerType,
                            order: $0.order,
                            durationType: $0.durationType,
                            minutes: $0.minutes,
                            note: $0.note,
                            startTime: $0.startTime,
                            endTime: $0.endTime
                        )
                    }
            )

            switch first.phaseId {
            case "2":
                extras.append(segment)
            case "3":
                penalties.append(segment)
            default:
                regulations.append(segment)
            }
        }

        return (regulations, extras, penalties)
    }

    private func durationKeyComponents(_ key: String) -> [Int] {
        let parts = key.split(separator: "-").map(String.init)
        let phase = parts.indices.contains(0) ? (Int(parts[0]) ?? 1) : 1
        let period = parts.indices.contains(1) ? (Int(parts[1]) ?? 1) : 1
        let marker = (parts.indices.contains(2) ? parts[2] : "T") == "I" ? 0 : 1
        return [phase, period, marker]
    }

    private func durationSortTuple(row: RefertoDirectorDurationRowState) -> [Int] {
        let phase = Int(row.phaseId) ?? 1
        let marker = row.markerType == "I" ? 0 : 1
        return [phase, row.periodNumber, marker, row.order]
    }

    private func durationSegmentTitle(phaseId: String, periodNumber: Int, markerType: String) -> String {
        switch phaseId {
        case "2":
            return markerType == "I" ? "Intervallo Supplementare" : "\(periodNumber) Tempo Supplementare"
        case "3":
            return markerType == "I" ? "Intervallo Tiri di Rigore" : "Tiri di Rigore"
        default:
            return markerType == "I" ? "Intervallo" : "\(periodNumber) Tempo"
        }
    }

    private func orderedDurataRows() -> [RefertoDirectorDurationRowState] {
        (directorRegulationSegments + directorExtraSegments + directorPenaltySegments)
            .flatMap(\.rows)
            .sorted {
                durationSortTuple(row: $0).lexicographicallyPrecedes(durationSortTuple(row: $1))
            }
    }

    private func sanitizedMinutes(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(3))
    }

    private func timeValue(after base: String, adding minutes: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "HH:mm"
        let start = formatter.date(from: base) ?? formatter.date(from: "00:00") ?? .now
        return formatter.string(from: start.addingTimeInterval(TimeInterval(max(0, minutes) * 60)))
    }

    private func recalculateDurataTimes() {
        let kickoff = directorDurataStartTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "00:00" : directorDurataStartTime
        var elapsed = 0
        let computed = orderedDurataRows().map { row -> RefertoDirectorDurationRowState in
            var copy = row
            let start = timeValue(after: kickoff, adding: elapsed)
            let rowMinutes = Int(copy.minutes) ?? 0
            elapsed += max(0, rowMinutes)
            copy.startTime = start
            copy.endTime = timeValue(after: kickoff, adding: elapsed)
            return copy
        }

        applyComputedDurataRows(computed)
        directorDurataEndTime = computed.last?.endTime ?? kickoff
    }

    private func applyComputedDurataRows(_ rows: [RefertoDirectorDurationRowState]) {
        let grouped = Dictionary(grouping: rows) {
            "\($0.phaseId)-\($0.periodNumber)-\($0.markerType)"
        }
        func rebuiltSegments(from source: [RefertoDirectorDurationSegmentState]) -> [RefertoDirectorDurationSegmentState] {
            source.map { segment in
                var copy = segment
                copy.rows = (grouped[segment.id] ?? segment.rows).sorted { $0.order < $1.order }
                return copy
            }
        }
        directorRegulationSegments = rebuiltSegments(from: directorRegulationSegments)
        directorExtraSegments = rebuiltSegments(from: directorExtraSegments)
        directorPenaltySegments = rebuiltSegments(from: directorPenaltySegments)
    }

    private func makeDurataRow(
        phaseId: String,
        periodNumber: Int,
        markerType: String,
        order: Int,
        durationType: String,
        minutes: String,
        note: String
    ) -> RefertoDirectorDurationRowState {
        RefertoDirectorDurationRowState(
            phaseId: phaseId,
            periodNumber: periodNumber,
            markerType: markerType,
            order: order,
            durationType: durationType,
            minutes: minutes,
            note: note,
            startTime: "",
            endTime: ""
        )
    }

    private func mutateDurataSegments(phaseId: String, transform: (inout [RefertoDirectorDurationSegmentState]) -> Void) {
        switch phaseId {
        case "2":
            var segments = directorExtraSegments
            transform(&segments)
            directorExtraSegments = segments
        case "3":
            var segments = directorPenaltySegments
            transform(&segments)
            directorPenaltySegments = segments
        default:
            var segments = directorRegulationSegments
            transform(&segments)
            directorRegulationSegments = segments
        }
        recalculateDurataTimes()
        errore = ""
        messaggioOperazione = ""
    }

    func aggiornaDurataRiga(
        phaseId: String,
        periodNumber: Int,
        markerType: String,
        rowId: UUID,
        durationType: String? = nil,
        minutes: String? = nil,
        note: String? = nil
    ) {
        mutateDurataSegments(phaseId: phaseId) { segments in
            guard let segmentIndex = segments.firstIndex(where: {
                $0.phaseId == phaseId && $0.periodNumber == periodNumber && $0.markerType == markerType
            }) else { return }
            guard let rowIndex = segments[segmentIndex].rows.firstIndex(where: { $0.id == rowId }) else { return }
            if let durationType {
                segments[segmentIndex].rows[rowIndex].durationType = durationType
            }
            if let minutes {
                segments[segmentIndex].rows[rowIndex].minutes = sanitizedMinutes(minutes)
            }
            if let note {
                segments[segmentIndex].rows[rowIndex].note = note
            }
        }
    }

    func aggiungiEventoDurata(phaseId: String, periodNumber: Int) {
        mutateDurataSegments(phaseId: phaseId) { segments in
            guard let index = segments.firstIndex(where: {
                $0.phaseId == phaseId && $0.periodNumber == periodNumber && $0.markerType == "T"
            }) else { return }
            let nextOrder = (segments[index].rows.map(\.order).max() ?? 0) + 1
            let defaultType = phaseId == "3" ? "7" : ""
            segments[index].rows.append(
                makeDurataRow(
                    phaseId: phaseId,
                    periodNumber: periodNumber,
                    markerType: "T",
                    order: nextOrder,
                    durationType: defaultType,
                    minutes: "",
                    note: ""
                )
            )
        }
    }

    func rimuoviEventoDurata(phaseId: String, periodNumber: Int, rowId: UUID) {
        mutateDurataSegments(phaseId: phaseId) { segments in
            guard let index = segments.firstIndex(where: {
                $0.phaseId == phaseId && $0.periodNumber == periodNumber && $0.markerType == "T"
            }) else { return }
            guard segments[index].rows.count > 1 else { return }
            segments[index].rows.removeAll { $0.id == rowId }
            segments[index].rows = segments[index].rows.enumerated().map { offset, row in
                var copy = row
                copy.order = offset + 1
                return copy
            }
        }
    }

    func aggiungiTempoRegolamentare() {
        mutateDurataSegments(phaseId: "1") { segments in
            let nextPeriod = (segments.filter { $0.markerType == "T" }.map(\.periodNumber).max() ?? 0) + 1
            if nextPeriod > 1 {
                segments.append(
                    RefertoDirectorDurationSegmentState(
                        phaseId: "1",
                        periodNumber: nextPeriod,
                        markerType: "I",
                        title: durationSegmentTitle(phaseId: "1", periodNumber: nextPeriod, markerType: "I"),
                        rows: [
                            makeDurataRow(
                                phaseId: "1",
                                periodNumber: nextPeriod,
                                markerType: "I",
                                order: 1,
                                durationType: "6",
                                minutes: "0",
                                note: ""
                            )
                        ]
                    )
                )
            }
            segments.append(
                RefertoDirectorDurationSegmentState(
                    phaseId: "1",
                    periodNumber: nextPeriod,
                    markerType: "T",
                    title: durationSegmentTitle(phaseId: "1", periodNumber: nextPeriod, markerType: "T"),
                    rows: [
                        makeDurataRow(
                            phaseId: "1",
                            periodNumber: nextPeriod,
                            markerType: "T",
                            order: 1,
                            durationType: "2",
                            minutes: "45",
                            note: "AUTOMATICO - Aggiunto tempo di gara"
                        )
                    ]
                )
            )
            segments.sort { $0.id < $1.id }
        }
    }

    func rimuoviTempoRegolamentare() {
        mutateDurataSegments(phaseId: "1") { segments in
            let lastPeriod = segments.filter { $0.markerType == "T" }.map(\.periodNumber).max() ?? 0
            guard lastPeriod > 2 else { return }
            segments.removeAll { $0.periodNumber == lastPeriod }
        }
    }

    func aggiungiTempoSupplementare() {
        mutateDurataSegments(phaseId: "2") { segments in
            let nextPeriod = (segments.filter { $0.markerType == "T" }.map(\.periodNumber).max() ?? 0) + 1
            segments.append(
                RefertoDirectorDurationSegmentState(
                    phaseId: "2",
                    periodNumber: nextPeriod,
                    markerType: "I",
                    title: durationSegmentTitle(phaseId: "2", periodNumber: nextPeriod, markerType: "I"),
                    rows: [
                        makeDurataRow(
                            phaseId: "2",
                            periodNumber: nextPeriod,
                            markerType: "I",
                            order: 1,
                            durationType: "6",
                            minutes: "0",
                            note: ""
                        )
                    ]
                )
            )
            segments.append(
                RefertoDirectorDurationSegmentState(
                    phaseId: "2",
                    periodNumber: nextPeriod,
                    markerType: "T",
                    title: durationSegmentTitle(phaseId: "2", periodNumber: nextPeriod, markerType: "T"),
                    rows: [
                        makeDurataRow(
                            phaseId: "2",
                            periodNumber: nextPeriod,
                            markerType: "T",
                            order: 1,
                            durationType: "",
                            minutes: "",
                            note: ""
                        )
                    ]
                )
            )
            segments.sort { $0.id < $1.id }
        }
    }

    func rimuoviTempoSupplementare() {
        mutateDurataSegments(phaseId: "2") { segments in
            let lastPeriod = segments.filter { $0.markerType == "T" }.map(\.periodNumber).max() ?? 0
            guard lastPeriod > 0 else { return }
            segments.removeAll { $0.periodNumber == lastPeriod }
        }
    }

    func aggiungiTiriDiRigore() {
        mutateDurataSegments(phaseId: "3") { segments in
            guard segments.isEmpty else { return }
            segments = [
                RefertoDirectorDurationSegmentState(
                    phaseId: "3",
                    periodNumber: 1,
                    markerType: "I",
                    title: durationSegmentTitle(phaseId: "3", periodNumber: 1, markerType: "I"),
                    rows: [
                        makeDurataRow(
                            phaseId: "3",
                            periodNumber: 1,
                            markerType: "I",
                            order: 1,
                            durationType: "6",
                            minutes: "0",
                            note: ""
                        )
                    ]
                ),
                RefertoDirectorDurationSegmentState(
                    phaseId: "3",
                    periodNumber: 1,
                    markerType: "T",
                    title: durationSegmentTitle(phaseId: "3", periodNumber: 1, markerType: "T"),
                    rows: [
                        makeDurataRow(
                            phaseId: "3",
                            periodNumber: 1,
                            markerType: "T",
                            order: 1,
                            durationType: "7",
                            minutes: "",
                            note: ""
                        )
                    ]
                ),
            ]
        }
    }

    func rimuoviTiriDiRigore() {
        mutateDurataSegments(phaseId: "3") { segments in
            segments.removeAll()
        }
    }

    private func validateDurata() -> String? {
        let kickoff = directorDurataStartTime.trimmingCharacters(in: .whitespacesAndNewlines)
        if kickoff.isEmpty {
            return "L'orario di inizio ufficiale della gara non è disponibile."
        }

        let regularGamePeriods = Set(
            directorRegulationSegments
                .filter { $0.markerType == "T" }
                .map(\.periodNumber)
        )
        if regularGamePeriods.count < 2 {
            return "Inserisci almeno i due tempi regolamentari della gara."
        }

        for row in orderedDurataRows() {
            let type = row.durationType.trimmingCharacters(in: .whitespacesAndNewlines)
            let minutesText = row.minutes.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !type.isEmpty else {
                return row.markerType == "I"
                    ? "Seleziona la voce dell'intervallo per tutti i periodi."
                    : "Seleziona il tipo di tempo/evento per tutte le righe della scheda Durata."
            }
            guard let minutes = Int(minutesText) else {
                return "Inserisci i minuti per ogni riga della scheda Durata."
            }
            if row.markerType == "I" {
                if type != "6" {
                    return "L'intervallo deve essere impostato come 'Intervallo Tra Tempi di Gioco'."
                }
                if minutes < 0 {
                    return "I minuti dell'intervallo non possono essere negativi."
                }
            } else {
                if minutes <= 0 {
                    return "Inserisci minuti maggiori di zero per ogni tempo o evento di gioco."
                }
                if row.phaseId == "3", type != "7" {
                    return "Nei tiri di rigore devi selezionare 'Tiri di Rigore'."
                }
            }
        }

        return nil
    }

    private func validateListeGara(team: RefertoDirectorTeamState, fallbackLabel: String) -> String? {
        let teamLabel = team.teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackLabel : team.teamName

        for row in team.starters + team.substitutes {
            if isPlayerRowPartiallyFilled(row) {
                return "Completa o svuota del tutto la riga #\(row.order) dei calciatori di \(teamLabel)."
            }
        }

        for row in team.staff {
            if isStaffRowPartiallyFilled(row) {
                return "Completa o svuota del tutto la riga #\(row.order) dei dirigenti di \(teamLabel)."
            }
        }

        let roster = (team.starters + team.substitutes).filter(isPlayerRowComplete)
        guard !roster.isEmpty else { return nil }

        let captainCount = roster.filter { $0.captainCode == "C" }.count
        let viceCount = roster.filter { $0.captainCode == "V" }.count

        if captainCount != 1 {
            return "Seleziona un solo capitano per \(teamLabel)."
        }
        if viceCount != 1 {
            return "Seleziona un solo vice-capitano per \(teamLabel)."
        }

        return nil
    }

    private func isPlayerRowComplete(_ row: RefertoDirectorPlayerRowState) -> Bool {
        !row.shirtNumber.isEmpty &&
        !row.personId.isEmpty &&
        !row.documentType.isEmpty &&
        !row.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isPlayerRowPartiallyFilled(_ row: RefertoDirectorPlayerRowState) -> Bool {
        let hasAnyValue =
            !row.shirtNumber.isEmpty ||
            !row.personId.isEmpty ||
            !row.captainCode.isEmpty ||
            !row.documentType.isEmpty ||
            !row.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasAnyValue && !isPlayerRowComplete(row)
    }

    private func isStaffRowComplete(_ row: RefertoDirectorStaffRowState) -> Bool {
        !row.roleId.isEmpty &&
        !row.personId.isEmpty &&
        !row.documentType.isEmpty &&
        !row.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isStaffRowPartiallyFilled(_ row: RefertoDirectorStaffRowState) -> Bool {
        let hasAnyValue =
            !row.roleId.isEmpty ||
            !row.personId.isEmpty ||
            !row.documentType.isEmpty ||
            !row.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasAnyValue && !isStaffRowComplete(row)
    }

    func aggiornaNumeroMaglia(isHome: Bool, section: String, order: Int, value: String) {
        mutatePlayerRow(isHome: isHome, section: section, order: order) { row, team in
            row.shirtNumber = value
            guard !value.isEmpty else { return }
            clearDuplicatePlayerValues(in: &team, section: section, currentOrder: order, match: { $0.shirtNumber == value }) { duplicate in
                duplicate.shirtNumber = ""
            }
        }
    }

    func aggiornaPersonaCalciatore(isHome: Bool, section: String, order: Int, value: String) {
        mutatePlayerRow(isHome: isHome, section: section, order: order) { row, team in
            row.personId = value
            guard !value.isEmpty else { return }
            clearDuplicatePlayerValues(in: &team, section: section, currentOrder: order, match: { $0.personId == value }) { duplicate in
                duplicate.personId = ""
            }
        }
    }

    func aggiornaCapitano(isHome: Bool, section: String, order: Int, value: String) {
        mutatePlayerRow(isHome: isHome, section: section, order: order) { row, team in
            row.captainCode = value
            guard !value.isEmpty else { return }
            clearDuplicatePlayerValues(in: &team, section: section, currentOrder: order, match: { $0.captainCode == value }) { duplicate in
                duplicate.captainCode = ""
            }
        }
    }

    func aggiornaDocumentoCalciatore(isHome: Bool, section: String, order: Int, type: String? = nil, number: String? = nil) {
        mutatePlayerRow(isHome: isHome, section: section, order: order) { row, _ in
            if let type {
                row.documentType = type
            }
            if let number {
                row.documentNumber = number
            }
        }
    }

    func aggiornaDirigente(isHome: Bool, order: Int, roleId: String? = nil, personId: String? = nil, documentType: String? = nil, documentNumber: String? = nil) {
        mutateStaffRow(isHome: isHome, order: order) { row in
            if let roleId {
                row.roleId = roleId
            }
            if let personId {
                row.personId = personId
            }
            if let documentType {
                row.documentType = documentType
            }
            if let documentNumber {
                row.documentNumber = documentNumber
            }
        }
    }

    func aggiungiRigaGiocatore(isHome: Bool, section: String) {
        mutateTeam(isHome: isHome) { team in
            if section == "substitutes" {
                team.substitutes.append(
                    RefertoDirectorPlayerRowState(
                        section: "substitutes",
                        order: team.substitutes.count + 1,
                        shirtNumber: "",
                        personId: "",
                        captainCode: "",
                        documentType: "",
                        documentNumber: ""
                    )
                )
            } else {
                team.starters.append(
                    RefertoDirectorPlayerRowState(
                        section: "starters",
                        order: team.starters.count + 1,
                        shirtNumber: "",
                        personId: "",
                        captainCode: "",
                        documentType: "",
                        documentNumber: ""
                    )
                )
            }
        }
    }

    func rimuoviRigaGiocatore(isHome: Bool, section: String) {
        mutateTeam(isHome: isHome) { team in
            if section == "substitutes" {
                guard !team.substitutes.isEmpty else { return }
                team.substitutes.removeLast()
                team.substitutes = team.substitutes.enumerated().map { index, row in
                    var copy = row
                    copy.order = index + 1
                    return copy
                }
            } else {
                guard !team.starters.isEmpty else { return }
                team.starters.removeLast()
                team.starters = team.starters.enumerated().map { index, row in
                    var copy = row
                    copy.order = index + 1
                    return copy
                }
            }
        }
    }

    func aggiungiDirigente(isHome: Bool) {
        mutateTeam(isHome: isHome) { team in
            team.staff.append(
                RefertoDirectorStaffRowState(
                    order: team.staff.count + 1,
                    roleId: "",
                    personId: "",
                    documentType: "",
                    documentNumber: ""
                )
            )
        }
    }

    func rimuoviDirigente(isHome: Bool) {
        mutateTeam(isHome: isHome) { team in
            guard !team.staff.isEmpty else { return }
            team.staff.removeLast()
            team.staff = team.staff.enumerated().map { index, row in
                var copy = row
                copy.order = index + 1
                return copy
            }
        }
    }

    func aggiungiPersonaManuale(
        token: String,
        designazioneId: String,
        isHome: Bool,
        draft: RefertoManualPersonDraftState,
        forceDuplicate: Bool = false
    ) async {
        guard !inSalvataggio else { return }
        let team = isHome ? listaCasa : listaFuori
        let refertoId = dettaglio?.refertoId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let teamId = team.teamId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !teamId.isEmpty else {
            errore = "Squadra non disponibile per l'aggiunta della persona."
            return
        }

        inSalvataggio = true
        errore = ""
        messaggioOperazione = ""
        defer { inSalvataggio = false }

        do {
            let esito = try await apiClient.aggiungiPersonaReferto(
                token: token,
                designazioneId: designazioneId,
                payload: APIClient.AddRefertoPersonPayload(
                    refertoId: refertoId,
                    teamId: teamId,
                    isHome: isHome,
                    matricola: draft.matricola,
                    lastName: draft.lastName,
                    firstName: draft.firstName,
                    birthDate: draft.birthDate,
                    birthPlaceCode: draft.birthPlaceCode,
                    birthPlaceLabel: draft.birthPlaceLabel,
                    sex: draft.sex,
                    taxCode: draft.taxCode,
                    forceDuplicate: forceDuplicate
                )
            )
            dettaglio = esito.detail
            sincronizzaStatoForm(con: esito.detail)
            directorCurrentTab = "Liste Gara"
            messaggioOperazione = esito.message
        } catch {
            errore = error.localizedDescription
        }
    }

    func rimuoviPersonaManuale(
        token: String,
        designazioneId: String,
        isHome: Bool,
        personId: String
    ) async {
        guard !inSalvataggio else { return }
        let team = isHome ? listaCasa : listaFuori
        let refertoId = dettaglio?.refertoId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let teamId = team.teamId.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPersonId = personId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !teamId.isEmpty else {
            errore = "Squadra non disponibile per la rimozione."
            return
        }
        guard !resolvedPersonId.isEmpty else {
            errore = "Seleziona una persona da rimuovere."
            return
        }

        inSalvataggio = true
        errore = ""
        messaggioOperazione = ""
        defer { inSalvataggio = false }

        do {
            let esito = try await apiClient.rimuoviPersonaReferto(
                token: token,
                designazioneId: designazioneId,
                payload: APIClient.ArchiveRefertoPersonPayload(
                    refertoId: refertoId,
                    teamId: teamId,
                    isHome: isHome,
                    personId: resolvedPersonId
                )
            )
            dettaglio = esito.detail
            sincronizzaStatoForm(con: esito.detail)
            directorCurrentTab = "Liste Gara"
            messaggioOperazione = esito.message
        } catch {
            errore = error.localizedDescription
        }
    }

    private func mutateTeam(isHome: Bool, transform: (inout RefertoDirectorTeamState) -> Void) {
        var team = isHome ? listaCasa : listaFuori
        transform(&team)
        if isHome {
            listaCasa = team
        } else {
            listaFuori = team
        }
        errore = ""
        messaggioOperazione = ""
    }

    private func mutatePlayerRow(
        isHome: Bool,
        section: String,
        order: Int,
        transform: (inout RefertoDirectorPlayerRowState, inout RefertoDirectorTeamState) -> Void
    ) {
        mutateTeam(isHome: isHome) { team in
            if section == "substitutes" {
                guard let index = team.substitutes.firstIndex(where: { $0.order == order }) else { return }
                var row = team.substitutes[index]
                transform(&row, &team)
                team.substitutes[index] = row
            } else {
                guard let index = team.starters.firstIndex(where: { $0.order == order }) else { return }
                var row = team.starters[index]
                transform(&row, &team)
                team.starters[index] = row
            }
        }
    }

    private func mutateStaffRow(isHome: Bool, order: Int, transform: (inout RefertoDirectorStaffRowState) -> Void) {
        mutateTeam(isHome: isHome) { team in
            guard let index = team.staff.firstIndex(where: { $0.order == order }) else { return }
            var row = team.staff[index]
            transform(&row)
            team.staff[index] = row
        }
    }

    private func clearDuplicatePlayerValues(
        in team: inout RefertoDirectorTeamState,
        section: String?,
        currentOrder: Int,
        match: (RefertoDirectorPlayerRowState) -> Bool,
        clear: (inout RefertoDirectorPlayerRowState) -> Void
    ) {
        team.starters = team.starters.map { row in
            var copy = row
            if !(section == "starters" && row.order == currentOrder) && match(row) {
                clear(&copy)
            }
            return copy
        }
        team.substitutes = team.substitutes.map { row in
            var copy = row
            if !(section == "substitutes" && row.order == currentOrder) && match(row) {
                clear(&copy)
            }
            return copy
        }
    }
}
