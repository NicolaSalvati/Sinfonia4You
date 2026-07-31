//
//  APIClient.swift
//  Sinfonia4You
//
//  Client HTTP verso il backend FastAPI che riusa il motore Sinfonia.
//

import Foundation

enum APIError: LocalizedError {
    case urlNonValido
    case rispostaNonValida
    case server(String)
    case sessioneScaduta(String)
    case decodifica
    case backendNonRaggiungibile(String)
    case timeout(String)

    var errorDescription: String? {
        switch self {
        case .urlNonValido:
            return "URL del backend non valido."
        case .rispostaNonValida:
            return "Risposta del server non valida."
        case .server(let message):
            return message
        case .sessioneScaduta(let message):
            return message
        case .decodifica:
            return "Non riesco a leggere la risposta del server."
        case .backendNonRaggiungibile(let message):
            return message
        case .timeout(let message):
            return message
        }
    }
}

extension Notification.Name {
    static let sinfoniaSessioneScaduta = Notification.Name("sinfonia4you.session.expired")
}

final class APIClient {
    static let shared = APIClient()

    // Endpoint di riserva. Il valore reale va fornito tramite
    // Config/Secrets.xcconfig -> SINFONIA_API_BASE_URL (vedi README).
    private static let backendProduzioneFallback = "https://backend.example.com"
    private static let infoPlistBackendKey = "SINFONIA_API_BASE_URL"
    private static let infoPlistBackendListKey = "SINFONIA_API_BACKUP_URLS"
    private static let defaultsBackendKey = "sinfonia_api_base_url"
    private static let defaultsBackendListKey = "sinfonia_api_base_urls"
    private static let defaultsDebugBackendKey = "sinfonia_api_debug_base_url"
    private static let defaultsDebugBackendListKey = "sinfonia_api_debug_base_urls"
    private static let defaultsLastGoodBackendKey = "sinfonia_api_last_good_base_url"
    private static let defaultsMigratedBackendKey = "sinfonia_api_migrated_base_url"
    private static let defaultsMigratedBackupListKey = "sinfonia_api_migrated_backup_base_urls"
    private static let environmentBackendKey = "SINFONIA_API_BASE_URL"
    private static let environmentBackendListKey = "SINFONIA_API_BASE_URLS"
    private static let environmentDebugBackendKey = "SINFONIA_DEBUG_API_BASE_URL"
    private static let environmentDebugBackendListKey = "SINFONIA_DEBUG_API_BASE_URLS"
    private static let canonicalBackendHeader = "X-Sinfonia-Canonical-Base-URL"
    private static let backupBackendsHeader = "X-Sinfonia-Backup-Base-URLs"
    private static let sessioneScadutaNotificationLock = NSLock()
    private static var lastSessioneScadutaNotificationAt = Date.distantPast

    private let decoder: JSONDecoder
    private let session: URLSession
    private let endpointStore: EndpointStore
    private let trustDelegate = BackendTrustDelegate()

    private init() {
        decoder = JSONDecoder()
        endpointStore = EndpointStore(defaults: .standard)

        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 128 * 1024 * 1024,
            diskPath: "sinfonia4you-api-cache"
        )
        // Il backend non usa cookie: accettarli espone solo a fissazione di
        // sessione e a tracciamento indesiderato.
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false

        // Certificate pinning. Senza questo delegate, il backend su indirizzo
        // IP con certificato self-signed sarebbe accettato solo disattivando
        // App Transport Security, esponendo credenziali e token a chiunque sia
        // sulla stessa rete.
        session = URLSession(
            configuration: configuration,
            delegate: trustDelegate,
            delegateQueue: nil
        )
    }

    private var baseURLString: String {
        endpointStore.preferredBaseURLString
    }

    private static func normalizzaOverrideBackend(_ rawValue: String?) -> String? {
        let clean = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return nil
        }

        // I quick tunnel trycloudflare sono effimeri e finiscono spesso in 530
        // quando l'URL scade o viene rigenerato.
        if clean.lowercased().contains(".trycloudflare.com") {
            return nil
        }

        // Alcune reti aziendali filtrano i domini dinamici sslip.io con
        // ispezione TLS; evito quindi che un vecchio endpoint sslip.io
        // resti salvato come preferito sul device.
        if clean.lowercased().contains(".sslip.io") {
            return nil
        }

        // In produzione accettiamo sempre endpoint HTTPS.
        if clean.lowercased().hasPrefix("https://") {
            return clean
        }

        // In sviluppo locale lasciamo passare solo host sicuri per test manuali.
        let allowedLocalHTTP = [
            "http://127.0.0.1",
            "http://localhost",
            "http://192.168.",
            "http://10.",
        ]
        if allowedLocalHTTP.contains(where: { clean.lowercased().hasPrefix($0) }) {
            return clean
        }

        // Evita che un vecchio override HTTP pubblico faccia scattare ATS su device.
        return nil
    }

    private static func parseBackendList(_ rawValue: String?) -> [String] {
        (rawValue ?? "")
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" })
            .compactMap { normalizzaOverrideBackend(String($0)) }
    }

    nonisolated private static func isLocalDevelopmentBackend(_ value: String) -> Bool {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return clean.hasPrefix("http://127.0.0.1")
            || clean.hasPrefix("http://localhost")
            || clean.hasPrefix("http://192.168.")
            || clean.hasPrefix("http://10.")
    }

    private static func deduplicaBackend(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        for value in values {
            guard !value.isEmpty, !seen.contains(value) else { continue }
            seen.insert(value)
            ordered.append(value)
        }

        return ordered
    }

    private struct EndpointTransportFailure: Error {
        let apiError: APIError
        let canTryAnotherEndpoint: Bool
    }

    private final class EndpointStore {
        private let defaults: UserDefaults
        private let lock = NSLock()

        init(defaults: UserDefaults) {
            self.defaults = defaults
        }

        var preferredBaseURLString: String {
            lock.lock()
            defer { lock.unlock() }
            return orderedBaseURLsLocked().first ?? APIClient.backendProduzioneFallback
        }

        func orderedBaseURLs(for requestURL: URL?) -> [String] {
            lock.lock()
            defer { lock.unlock() }

            var values = orderedBaseURLsLocked()
            if let current = Self.baseURLString(from: requestURL),
               let index = values.firstIndex(of: current),
               index > 0 {
                let selected = values.remove(at: index)
                values.insert(selected, at: 0)
            }
            return values
        }

        func registerSuccessfulResponse(requestURL: URL?, response: URLResponse) {
            lock.lock()
            defer { lock.unlock() }

            if let current = Self.baseURLString(from: requestURL),
               APIClient.normalizzaOverrideBackend(current) != nil {
                defaults.set(current, forKey: APIClient.defaultsLastGoodBackendKey)
            }

            guard let httpResponse = response as? HTTPURLResponse else { return }

            if let canonical = APIClient.normalizzaOverrideBackend(
                httpResponse.value(forHTTPHeaderField: APIClient.canonicalBackendHeader)
            ) {
                defaults.set(canonical, forKey: APIClient.defaultsMigratedBackendKey)
            }

            if let rawBackups = httpResponse.value(forHTTPHeaderField: APIClient.backupBackendsHeader) {
                let backups = APIClient.parseBackendList(rawBackups)
                if backups.isEmpty {
                    defaults.removeObject(forKey: APIClient.defaultsMigratedBackupListKey)
                } else {
                    defaults.set(backups.joined(separator: ","), forKey: APIClient.defaultsMigratedBackupListKey)
                }
            }
        }

        private func orderedBaseURLsLocked() -> [String] {
#if DEBUG
            let debugEnvironment = APIClient.parseBackendList(
                ProcessInfo.processInfo.environment[APIClient.environmentDebugBackendListKey]
            )
            let debugEnvironmentSingle = APIClient.parseBackendList(
                ProcessInfo.processInfo.environment[APIClient.environmentDebugBackendKey]
            )
            let debugDefaultsList = APIClient.parseBackendList(
                defaults.string(forKey: APIClient.defaultsDebugBackendListKey)
            )
            let debugDefaultsSingle = APIClient.parseBackendList(
                defaults.string(forKey: APIClient.defaultsDebugBackendKey)
            )
            let explicitDebugBackends = APIClient.deduplicaBackend(
                debugEnvironment
                + debugEnvironmentSingle
                + debugDefaultsList
                + debugDefaultsSingle
            )
            if !explicitDebugBackends.isEmpty {
                return explicitDebugBackends
            }
#endif

            let environment = APIClient.parseBackendList(
                ProcessInfo.processInfo.environment[APIClient.environmentBackendListKey]
            )
            let environmentSingle = APIClient.parseBackendList(
                ProcessInfo.processInfo.environment[APIClient.environmentBackendKey]
            )

            let defaultsList = APIClient.parseBackendList(
                defaults.string(forKey: APIClient.defaultsBackendListKey)
            )
            let defaultsSingle = APIClient.parseBackendList(
                defaults.string(forKey: APIClient.defaultsBackendKey)
            )

            let migrated = APIClient.parseBackendList(
                defaults.string(forKey: APIClient.defaultsMigratedBackendKey)
            )
            let migratedBackups = APIClient.parseBackendList(
                defaults.string(forKey: APIClient.defaultsMigratedBackupListKey)
            )
            let lastGood = APIClient.parseBackendList(
                defaults.string(forKey: APIClient.defaultsLastGoodBackendKey)
            )

            let bundlePrimary = APIClient.parseBackendList(
                Bundle.main.object(forInfoDictionaryKey: APIClient.infoPlistBackendKey) as? String
            )
            let bundleBackups = APIClient.parseBackendList(
                Bundle.main.object(forInfoDictionaryKey: APIClient.infoPlistBackendListKey) as? String
            )

            let explicitBackends = APIClient.deduplicaBackend(
                environment
                + environmentSingle
                + defaultsList
                + defaultsSingle
                + migrated
                + migratedBackups
                + lastGood
                + bundlePrimary
                + bundleBackups
            )

#if DEBUG
            let localDevelopmentBackends = explicitBackends.filter(APIClient.isLocalDevelopmentBackend)
            if !localDevelopmentBackends.isEmpty {
                return localDevelopmentBackends
            }
#endif

            return APIClient.deduplicaBackend(
                explicitBackends + [APIClient.backendProduzioneFallback]
            )
        }

        private static func baseURLString(from url: URL?) -> String? {
            guard let url, let scheme = url.scheme, let host = url.host else {
                return nil
            }

            if let port = url.port {
                return "\(scheme)://\(host):\(port)"
            }

            return "\(scheme)://\(host)"
        }
    }

    var baseURLAssoluto: String {
        baseURLString
    }

    func login(username: String, password: String) async throws -> LoginResponseDTO {
        guard let url = URL(string: baseURLString + "/api/v1/auth/login") else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "username": username,
            "password": password
        ])

        let (data, response) = try await esegui(request: request, retryPolicy: .retryOnceOnTransientFailure)
        try valida(response: response, data: data)

        do {
            return try decoder.decode(LoginResponseDTO.self, from: data)
        } catch {
            throw APIError.decodifica
        }
    }

    func home(token: String) async throws -> HomePayloadDTO {
        guard let url = URL(string: baseURLString + "/api/v1/home") else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)

        do {
            return try decoder.decode(HomePayloadDTO.self, from: data)
        } catch {
            throw APIError.decodifica
        }
    }

    func catalogoReparti(token: String) async throws -> CatalogoRepartiDTO {
        guard let url = URL(string: baseURLString + "/api/v1/modules/catalog") else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)

        do {
            return try decoder.decode(CatalogoRepartiDTO.self, from: data)
        } catch {
            throw APIError.decodifica
        }
    }

    func snapshotModulo(
        token: String,
        moduleId: String,
        dateFrom: String? = nil,
        dateTo: String? = nil
    ) async throws -> SnapshotModuloDTO {
        guard let encoded = moduleId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              var components = URLComponents(string: baseURLString + "/api/v1/modules/" + encoded) else {
            throw APIError.urlNonValido
        }

        var queryItems: [URLQueryItem] = []
        if let dateFrom, !dateFrom.isEmpty {
            queryItems.append(URLQueryItem(name: "date_from", value: dateFrom))
        }
        if let dateTo, !dateTo.isEmpty {
            queryItems.append(URLQueryItem(name: "date_to", value: dateTo))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)

        do {
            return try decoder.decode(SnapshotModuloDTO.self, from: data)
        } catch {
            throw APIError.decodifica
        }
    }

    func dettaglioGara(token: String, designazioneId: String) async throws -> DettaglioGaraDTO {
        guard let encoded = designazioneId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: baseURLString + "/api/v1/matches/" + encoded) else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)

        do {
            return try decoder.decode(DettaglioGaraDTO.self, from: data)
        } catch {
            throw APIError.decodifica
        }
    }

    func classificaGara(token: String, designazioneId: String) async throws -> ClassificaGaraDTO {
        guard let encoded = designazioneId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: baseURLString + "/api/v1/matches/" + encoded + "/standings") else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 45

        let (data, response) = try await esegui(request: request, retryPolicy: .retryOnceOnTransientFailure)
        try valida(response: response, data: data)

        do {
            return try decoder.decode(ClassificaGaraDTO.self, from: data)
        } catch {
            throw APIError.decodifica
        }
    }

    func schedaTecnicaOverview(token: String, seasonId: String = "") async throws -> TechnicalSheetOverviewDTO {
        try await request(
            path: "/api/v1/technical-sheet",
            token: token,
            queryItems: technicalSheetQueryItems(seasonId: seasonId)
        )
    }

    func schedaTecnicaGare(token: String, seasonId: String = "") async throws -> TechnicalSheetMatchesDTO {
        try await request(
            path: "/api/v1/technical-sheet/matches",
            token: token,
            queryItems: technicalSheetQueryItems(seasonId: seasonId)
        )
    }

    func schedaTecnicaVoti(token: String, seasonId: String = "") async throws -> TechnicalSheetVotesScreenDTO {
        try await request(
            path: "/api/v1/technical-sheet/votes",
            token: token,
            queryItems: technicalSheetQueryItems(seasonId: seasonId)
        )
    }

    func schedaTecnicaDettaglioGara(token: String, matchId: String, seasonId: String = "") async throws -> TechnicalSheetMatchDetailDTO {
        guard let encoded = matchId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw APIError.urlNonValido
        }
        return try await request(
            path: "/api/v1/technical-sheet/matches/" + encoded,
            token: token,
            queryItems: technicalSheetQueryItems(seasonId: seasonId)
        )
    }

    func schedaTecnicaRimborsi(token: String, seasonId: String = "") async throws -> TechnicalSheetReimbursementsDTO {
        try await request(
            path: "/api/v1/technical-sheet/reimbursements",
            token: token,
            queryItems: technicalSheetQueryItems(seasonId: seasonId)
        )
    }

    func schedaTecnicaAnagrafe(token: String, seasonId: String = "") async throws -> TechnicalSheetAnagraphicsDTO {
        try await request(
            path: "/api/v1/technical-sheet/anagraphics",
            token: token,
            queryItems: technicalSheetQueryItems(seasonId: seasonId)
        )
    }

    func dettaglioReferto(token: String, designazioneId: String) async throws -> DettaglioRefertoDTO {
        guard let encoded = designazioneId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: baseURLString + "/api/v1/referti/" + encoded) else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)

        do {
            return try decoder.decode(DettaglioRefertoDTO.self, from: data)
        } catch {
            throw APIError.decodifica
        }
    }

    func salvaReferto(
        token: String,
        designazioneId: String,
        refertoId: String,
        segnalazioneValue: String,
        noteText: String,
        assistantOnly: Bool = false,
        svolgimentoValue: String = "",
        svolgimentoNote: String = "",
        currentTab: String = "",
        ordineValue: String = "",
        ambulanzaValue: String = "",
        ordineNote: String = "",
        durataRows: [SaveRefertoDurationRowPayload] = [],
        listaGaraHome: [SaveRefertoPlayerRowPayload] = [],
        listaGaraAway: [SaveRefertoPlayerRowPayload] = [],
        listaGaraHomeStaff: [SaveRefertoStaffRowPayload] = [],
        listaGaraAwayStaff: [SaveRefertoStaffRowPayload] = []
    ) async throws -> EsitoOperazioneRefertoDTO {
        guard let encoded = designazioneId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: baseURLString + "/api/v1/referti/" + encoded + "/save") else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if assistantOnly {
            let payload = AssistantSaveRefertoPayload(
                refertoId: refertoId,
                segnalazioneValue: segnalazioneValue,
                noteText: noteText
            )
            request.httpBody = try JSONEncoder().encode(payload)
        } else {
            let payload = SaveRefertoPayload(
                refertoId: refertoId,
                segnalazioneValue: segnalazioneValue,
                noteText: noteText,
                svolgimentoValue: svolgimentoValue,
                svolgimentoNote: svolgimentoNote,
                currentTab: currentTab,
                ordineValue: ordineValue,
                ambulanzaValue: ambulanzaValue,
                ordineNote: ordineNote,
                durataRows: durataRows,
                listaGaraHome: listaGaraHome,
                listaGaraAway: listaGaraAway,
                listaGaraHomeStaff: listaGaraHomeStaff,
                listaGaraAwayStaff: listaGaraAwayStaff
            )
            request.httpBody = try JSONEncoder().encode(payload)
        }

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)

        do {
            return try decoder.decode(EsitoOperazioneRefertoDTO.self, from: data)
        } catch {
            throw APIError.decodifica
        }
    }

    private struct AssistantSaveRefertoPayload: Encodable {
        let refertoId: String
        let segnalazioneValue: String
        let noteText: String

        enum CodingKeys: String, CodingKey {
            case refertoId = "referto_id"
            case segnalazioneValue = "segnalazione_value"
            case noteText = "note_text"
        }
    }

    private struct SaveRefertoPayload: Encodable {
        let refertoId: String
        let segnalazioneValue: String
        let noteText: String
        let svolgimentoValue: String
        let svolgimentoNote: String
        let currentTab: String
        let ordineValue: String
        let ambulanzaValue: String
        let ordineNote: String
        let durataRows: [SaveRefertoDurationRowPayload]
        let listaGaraHome: [SaveRefertoPlayerRowPayload]
        let listaGaraAway: [SaveRefertoPlayerRowPayload]
        let listaGaraHomeStaff: [SaveRefertoStaffRowPayload]
        let listaGaraAwayStaff: [SaveRefertoStaffRowPayload]

        enum CodingKeys: String, CodingKey {
            case refertoId = "referto_id"
            case segnalazioneValue = "segnalazione_value"
            case noteText = "note_text"
            case svolgimentoValue = "svolgimento_value"
            case svolgimentoNote = "svolgimento_note"
            case currentTab = "current_tab"
            case ordineValue = "ordine_value"
            case ambulanzaValue = "ambulanza_value"
            case ordineNote = "ordine_note"
            case durataRows = "durata_rows"
            case listaGaraHome = "lista_gara_home"
            case listaGaraAway = "lista_gara_away"
            case listaGaraHomeStaff = "lista_gara_home_staff"
            case listaGaraAwayStaff = "lista_gara_away_staff"
        }
    }

    struct SaveRefertoDurationRowPayload: Encodable {
        let phaseId: String
        let periodNumber: Int
        let markerType: String
        let minutes: String
        let durationType: String
        let note: String
        let startTime: String
        let endTime: String
        let order: Int

        enum CodingKeys: String, CodingKey {
            case phaseId = "t_tipo"
            case periodNumber = "t_tempo"
            case markerType = "m_tipo"
            case minutes = "m_minuto"
            case durationType = "durata"
            case note
            case startTime = "ora_inizio"
            case endTime = "ora_fine"
            case order = "ordine"
        }
    }

    struct SaveRefertoPlayerRowPayload: Encodable {
        let order: Int
        let shirtNumber: String
        let personId: String
        let captainCode: String
        let documentType: String
        let documentNumber: String
        let section: String

        enum CodingKeys: String, CodingKey {
            case order
            case shirtNumber = "shirt_number"
            case personId = "person_id"
            case captainCode = "captain_code"
            case documentType = "document_type"
            case documentNumber = "document_number"
            case section
        }
    }

    struct SaveRefertoStaffRowPayload: Encodable {
        let order: Int
        let roleId: String
        let personId: String
        let documentType: String
        let documentNumber: String

        enum CodingKeys: String, CodingKey {
            case order
            case roleId = "role_id"
            case personId = "person_id"
            case documentType = "document_type"
            case documentNumber = "document_number"
        }
    }

    struct AddRefertoPersonPayload: Encodable {
        let refertoId: String
        let teamId: String
        let isHome: Bool
        let matricola: String
        let lastName: String
        let firstName: String
        let birthDate: String
        let birthPlaceCode: String
        let birthPlaceLabel: String
        let sex: String
        let taxCode: String
        let forceDuplicate: Bool

        enum CodingKeys: String, CodingKey {
            case refertoId = "referto_id"
            case teamId = "team_id"
            case isHome = "is_home"
            case matricola
            case lastName = "last_name"
            case firstName = "first_name"
            case birthDate = "birth_date"
            case birthPlaceCode = "birth_place_code"
            case birthPlaceLabel = "birth_place_label"
            case sex
            case taxCode = "tax_code"
            case forceDuplicate = "force_duplicate"
        }
    }

    struct ArchiveRefertoPersonPayload: Encodable {
        let refertoId: String
        let teamId: String
        let isHome: Bool
        let personId: String

        enum CodingKeys: String, CodingKey {
            case refertoId = "referto_id"
            case teamId = "team_id"
            case isHome = "is_home"
            case personId = "person_id"
        }
    }

    func aggiungiPersonaReferto(
        token: String,
        designazioneId: String,
        payload: AddRefertoPersonPayload
    ) async throws -> EsitoOperazioneRefertoDTO {
        guard let encoded = designazioneId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: baseURLString + "/api/v1/referti/" + encoded + "/people/add") else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)

        do {
            return try decoder.decode(EsitoOperazioneRefertoDTO.self, from: data)
        } catch {
            throw APIError.decodifica
        }
    }

    func rimuoviPersonaReferto(
        token: String,
        designazioneId: String,
        payload: ArchiveRefertoPersonPayload
    ) async throws -> EsitoOperazioneRefertoDTO {
        guard let encoded = designazioneId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: baseURLString + "/api/v1/referti/" + encoded + "/people/archive") else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)

        do {
            return try decoder.decode(EsitoOperazioneRefertoDTO.self, from: data)
        } catch {
            throw APIError.decodifica
        }
    }

    func formIban(token: String) async throws -> IbanConfigDTO {
        try await request(path: "/api/v1/forms/iban", token: token)
    }

    func inviaIban(
        token: String,
        ibanCode: String,
        file: FileSelezionatoApp?
    ) async throws -> EsitoOperazioneDTO {
        let fields = ["iban_code": ibanCode]
        return try await multipartRequest(
            path: "/api/v1/forms/iban/submit",
            token: token,
            fields: fields,
            fileFieldName: "file",
            file: file
        )
    }

    func formRinnovoCertificato(token: String) async throws -> CertificateRenewalConfigDTO {
        try await request(path: "/api/v1/forms/certificate-renewal", token: token)
    }

    func inviaRinnovoCertificato(
        token: String,
        certType: String,
        releaseDate: String,
        expiryDate: String,
        issuer: String,
        note: String,
        file: FileSelezionatoApp
    ) async throws -> EsitoOperazioneDTO {
        try await multipartRequest(
            path: "/api/v1/forms/certificate-renewal/submit",
            token: token,
            fields: [
                "cert_type": certType,
                "release_date": releaseDate,
                "expiry_date": expiryDate,
                "issuer": issuer,
                "note": note
            ],
            fileFieldName: "file",
            file: file
        )
    }

    func formIndisponibilita(token: String) async throws -> IndisponibilitaConfigDTO {
        try await request(path: "/api/v1/forms/indisponibilita", token: token)
    }

    func inviaIndisponibilita(
        token: String,
        startDate: String,
        endDate: String,
        typeValue: String,
        reasonValue: String,
        note: String,
        file: FileSelezionatoApp?
    ) async throws -> EsitoOperazioneDTO {
        try await multipartRequest(
            path: "/api/v1/forms/indisponibilita/submit",
            token: token,
            fields: [
                "start_date": startDate,
                "end_date": endDate,
                "type_value": typeValue,
                "reason_value": reasonValue,
                "note": note
            ],
            fileFieldName: "file",
            file: file
        )
    }

    func formCongedo(token: String) async throws -> CongedoConfigDTO {
        try await request(path: "/api/v1/forms/congedo", token: token)
    }

    func inviaCongedo(
        token: String,
        startDate: String,
        endDate: String,
        reasonValue: String,
        note: String,
        file: FileSelezionatoApp?
    ) async throws -> EsitoOperazioneDTO {
        try await multipartRequest(
            path: "/api/v1/forms/congedo/submit",
            token: token,
            fields: [
                "start_date": startDate,
                "end_date": endDate,
                "reason_value": reasonValue,
                "note": note
            ],
            fileFieldName: "file",
            file: file
        )
    }

    func formPreclusione(token: String) async throws -> PreclusioneConfigDTO {
        try await request(path: "/api/v1/forms/preclusione", token: token)
    }

    func cercaPreclusione(
        token: String,
        preclType: String,
        filterField: String,
        filterScope: String,
        filterResult: String,
        term: String
    ) async throws -> [RisultatoPreclusioneDTO] {
        var components = URLComponents(string: baseURLString + "/api/v1/forms/preclusione/search")
        components?.queryItems = [
            URLQueryItem(name: "precl_type", value: preclType),
            URLQueryItem(name: "filter_field", value: filterField),
            URLQueryItem(name: "filter_scope", value: filterScope),
            URLQueryItem(name: "filter_result", value: filterResult),
            URLQueryItem(name: "term", value: term)
        ]
        guard let url = components?.url else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)

        do {
            return try decoder.decode(RicercaPreclusioneDTO.self, from: data).results
        } catch {
            throw APIError.decodifica
        }
    }

    func inviaPreclusione(
        token: String,
        endDate: String,
        specialCase: String,
        preclType: String,
        selectionId: String,
        selectionLabel: String,
        note: String,
        filterField: String,
        filterScope: String,
        filterResult: String,
        searchTerm: String
    ) async throws -> EsitoOperazioneDTO {
        try await jsonRequest(
            path: "/api/v1/forms/preclusione/submit",
            token: token,
            payload: [
                "end_date": endDate,
                "special_case": specialCase,
                "precl_type": preclType,
                "selection_id": selectionId,
                "selection_label": selectionLabel,
                "note": note,
                "filter_field": filterField,
                "filter_scope": filterScope,
                "filter_result": filterResult,
                "search_term": searchTerm
            ]
        )
    }

    func formDomande(token: String) async throws -> DomandeConfigDTO {
        try await request(path: "/api/v1/forms/domande", token: token)
    }

    func inviaDomanda(
        token: String,
        questionValue: String,
        note: String,
        file: FileSelezionatoApp
    ) async throws -> EsitoOperazioneDTO {
        try await multipartRequest(
            path: "/api/v1/forms/domande/submit",
            token: token,
            fields: [
                "question_value": questionValue,
                "note": note
            ],
            fileFieldName: "file",
            file: file
        )
    }

    func formDocumenti(token: String) async throws -> DocumentsConfigDTO {
        // Eseguo tre tentativi in sequenza e trasformo sempre la risposta finale
        // nello stesso DTO, così la vista documenti legge un solo formato lato app.
        do {
            return try await request(path: "/api/v1/forms/documents", token: token)
        } catch let error as APIError {
            switch error {
            case .server, .decodifica, .rispostaNonValida:
                do {
                    let legacyItems: [DocumentoConfigItemDTO] = try await request(path: "/api/v1/documents", token: token)
                    return DocumentsConfigDTO(
                        title: "Gestione Documenti",
                        maxSizeBytes: 1024 * 1024,
                        allowedExtensions: [".pdf"],
                        items: legacyItems
                    )
                } catch let legacyError as APIError {
                    switch legacyError {
                    case .server, .decodifica, .rispostaNonValida:
                        let snapshot = try await snapshotModulo(token: token, moduleId: "documents")
                        return Self.documentsConfig(from: snapshot)
                    default:
                        throw legacyError
                    }
                }
            default:
                throw error
            }
        }
    }

    private static func documentsConfig(from snapshot: SnapshotModuloDTO) -> DocumentsConfigDTO {
        // Traduco il formato generico del modulo in un config documenti nativo per l'app.
        let items = snapshot.rows.map { row in
            let actionField = row.fields.first { field in
                field.label.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Azione") == .orderedSame
            }
            let attachmentURL = row.attachments.first?.url ?? ""
            let normalizedStatus = normalizedDocumentStatus(
                status: row.status,
                uploadedAt: row.subtitle,
                attachmentURL: attachmentURL
            )

            return DocumentoConfigItemDTO(
                typeId: row.id,
                title: row.title,
                statusLabel: row.status,
                statusCode: normalizedStatus,
                uploadedAt: row.subtitle,
                attachmentUrl: attachmentURL,
                actionLabel: actionField?.value ?? row.actionLabel ?? ""
            )
        }

        return DocumentsConfigDTO(
            title: snapshot.title.isEmpty ? "Gestione Documenti" : snapshot.title,
            maxSizeBytes: 1024 * 1024,
            allowedExtensions: [".pdf"],
            items: items
        )
    }

    private static func normalizedDocumentStatus(
        status: String,
        uploadedAt: String,
        attachmentURL: String
    ) -> String {
        // Normalizzazione volutamente semplice:
        // - "attesa" -> pending
        // - se esiste data o allegato -> uploaded
        // - altrimenti -> missing
        let normalized = status
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.contains("attesa") {
            return "pending"
        }
        if !uploadedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !attachmentURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || normalized.contains("approv")
            || normalized.contains("caricat")
            || normalized.contains("presente") {
            return "uploaded"
        }
        return "missing"
    }

    func caricaDocumento(
        token: String,
        typeId: String,
        file: FileSelezionatoApp
    ) async throws -> EsitoOperazioneDTO {
        guard let encoded = typeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw APIError.urlNonValido
        }
        return try await multipartRequest(
            path: "/api/v1/forms/documents/" + encoded + "/upload",
            token: token,
            fields: [:],
            fileFieldName: "file",
            file: file
        )
    }

    func formAccount(token: String) async throws -> AccountPasswordConfigDTO {
        try await request(path: "/api/v1/forms/account", token: token)
    }

    func cambiaPassword(
        token: String,
        oldPassword: String,
        newPassword: String,
        confirmPassword: String
    ) async throws -> EsitoOperazioneDTO {
        try await jsonRequest(
            path: "/api/v1/forms/account/change-password",
            token: token,
            payload: [
                "old_password": oldPassword,
                "new_password": newPassword,
                "confirm_password": confirmPassword
            ]
        )
    }

    func eseguiAzioneGara(
        token: String,
        designazioneId: String,
        action: String
    ) async throws -> DettaglioGaraDTO {
        guard let encoded = designazioneId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: baseURLString + "/api/v1/matches/" + encoded + "/action") else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["action": action])

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)

        struct RispostaAzioneGaraDTO: Codable {
            let detail: DettaglioGaraDTO
        }

        do {
            return try decoder.decode(RispostaAzioneGaraDTO.self, from: data).detail
        } catch {
            throw APIError.decodifica
        }
    }

    func matches(token: String) async throws -> [MatchAssignmentDTO] {
        try await request(path: "/api/v1/matches", token: token)
    }

    func eventi(token: String) async throws -> [EventoItemDTO] {
        try await request(path: "/api/v1/events", token: token)
    }

    func accettaEvento(token: String, eventId: String) async throws -> [EventoItemDTO] {
        guard let encoded = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: baseURLString + "/api/v1/events/" + encoded + "/accept") else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)

        do {
            return try decoder.decode(EventiActionResponseDTO.self, from: data).items
        } catch {
            throw APIError.decodifica
        }
    }

    // MARK: - URL di download
    //
    // Queste URL finiscono in superfici di sistema (AsyncImage, Link,
    // QuickLook) che non permettono di impostare header HTTP. Prima ci finiva
    // dentro il token di sessione come `?token=...`: un token valido per ore,
    // scritto nei log di accesso del server e nella cronologia dei proxy.
    //
    // Ora l'app chiede prima un ticket monouso con una normale richiesta
    // autenticata. Il ticket vale pochi secondi, si consuma al primo uso ed e'
    // valido solo per quel preciso percorso.

    /// Ottiene un ticket monouso per una risorsa scaricabile.
    func ticketDownload(token: String, scope: String) async throws -> String {
        guard let url = URL(string: baseURLString + "/api/v1/auth/download-ticket") else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["scope": scope])

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)

        struct TicketDTO: Codable {
            let ticket: String
        }

        do {
            return try decoder.decode(TicketDTO.self, from: data).ticket
        } catch {
            throw APIError.decodifica
        }
    }

    /// Compone una URL scaricabile aggiungendo un ticket monouso.
    private func urlConTicket(
        token: String,
        path: String,
        extraItems: [URLQueryItem] = []
    ) async -> URL? {
        guard var components = URLComponents(string: baseURLString + path) else {
            return nil
        }

        guard let ticket = try? await ticketDownload(token: token, scope: path) else {
            return nil
        }

        var queryItems = [URLQueryItem(name: "ticket", value: ticket)]
        queryItems.append(contentsOf: extraItems)
        components.queryItems = queryItems
        return components.url
    }

    func urlDownloadAllegatoEvento(token: String, eventId: String) async -> URL? {
        guard let encoded = eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return await urlConTicket(
            token: token,
            path: "/api/v1/events/" + encoded + "/attachment"
        )
    }

    func urlFotoProfilo(token: String) async -> URL? {
        await urlConTicket(
            token: token,
            path: "/api/v1/profile/photo",
            extraItems: [URLQueryItem(name: "ts", value: String(Int(Date().timeIntervalSince1970)))]
        )
    }

    func urlSchedaTecnicaPDF(token: String, section: String, seasonId: String = "") async -> URL? {
        guard let encoded = section.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return await urlConTicket(
            token: token,
            path: "/api/v1/technical-sheet/pdf/" + encoded,
            extraItems: technicalSheetQueryItems(seasonId: seasonId)
        )
    }

    func urlSchedaTecnicaStatistichePDF(token: String, seasonId: String = "") async -> URL? {
        await urlConTicket(
            token: token,
            path: "/api/v1/technical-sheet/reimbursements/statistics-pdf",
            extraItems: technicalSheetQueryItems(seasonId: seasonId)
        )
    }

    func urlDownloadPortale(token: String, remoteURL: String, suggestedName: String) async -> URL? {
        await urlConTicket(
            token: token,
            path: "/api/v1/files/download",
            extraItems: [
                URLQueryItem(name: "url", value: remoteURL),
                URLQueryItem(name: "name", value: suggestedName),
            ]
        )
    }

    func urlDownloadAllegatoComunicazione(token: String, communicationId: String) async -> URL? {
        guard let encoded = communicationId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return await urlConTicket(
            token: token,
            path: "/api/v1/communications/" + encoded + "/attachment"
        )
    }

    private func valida(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.rispostaNonValida
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            var detailMessage = ""
            if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                detailMessage = formatErrorDetail(from: payload["detail"])
            }

            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                let message = detailMessage.isEmpty
                    ? "Sessione Sinfonia scaduta. Effettua di nuovo il login."
                    : detailMessage
                notifySessioneScaduta(message: message)
                throw APIError.sessioneScaduta(message)
            }

            if isSessioneScadutaMessage(detailMessage) {
                notifySessioneScaduta(message: detailMessage)
                throw APIError.sessioneScaduta(detailMessage)
            }

            if !detailMessage.isEmpty {
                throw APIError.server(detailMessage)
            }

            throw APIError.server("Il server ha restituito errore \(httpResponse.statusCode).")
        }
    }

    private func formatErrorDetail(from rawDetail: Any?) -> String {
        guard let rawDetail else { return "" }

        if let detail = rawDetail as? String {
            return detail.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let items = rawDetail as? [[String: Any]] {
            let messages = items.compactMap { item -> String? in
                let message = (item["msg"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !message.isEmpty else { return nil }

                if let loc = item["loc"] as? [Any] {
                    let cleanedLoc = loc
                        .compactMap { value -> String? in
                            let text = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
                            return text.isEmpty || text == "body" ? nil : text
                        }
                        .joined(separator: " -> ")
                    if !cleanedLoc.isEmpty {
                        return "\(cleanedLoc): \(message)"
                    }
                }

                return message
            }

            return messages
                .reduce(into: [String]()) { partialResult, message in
                    guard !partialResult.contains(message) else { return }
                    partialResult.append(message)
                }
                .joined(separator: "\n")
        }

        if let items = rawDetail as? [String] {
            return items.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return String(describing: rawDetail).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isSessioneScadutaMessage(_ message: String) -> Bool {
        let normalized = message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return false }

        let containsSessionToken = normalized.contains("sessione")
        let containsExpiryToken = normalized.contains("scadut")
            || normalized.contains("non valida")
            || normalized.contains("session invalid")
            || normalized.contains("unauthorized")
            || normalized.contains("non autorizz")
        let containsLoginToken = normalized.contains("login")
            || normalized.contains("autentic")

        return (containsSessionToken && containsExpiryToken)
            || (containsSessionToken && containsLoginToken)
    }

    private func notifySessioneScaduta(message: String) {
        let safeMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()

        Self.sessioneScadutaNotificationLock.lock()
        let interval = now.timeIntervalSince(Self.lastSessioneScadutaNotificationAt)
        if interval < 1.5 {
            Self.sessioneScadutaNotificationLock.unlock()
            return
        }
        Self.lastSessioneScadutaNotificationAt = now
        Self.sessioneScadutaNotificationLock.unlock()

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .sinfoniaSessioneScaduta,
                object: nil,
                userInfo: ["message": safeMessage]
            )
        }
    }

    private enum RetryPolicy {
        case none
        case retryOnceOnTransientFailure
    }

    private func esegui(request: URLRequest, retryPolicy: RetryPolicy = .none) async throws -> (Data, URLResponse) {
        let candidateBaseURLs = endpointStore.orderedBaseURLs(for: request.url)
        var lastFallbackError: APIError?

        for (index, candidateBaseURL) in candidateBaseURLs.enumerated() {
            let candidateRequest: URLRequest
            do {
                candidateRequest = try rebuildRequest(request, withBaseURLString: candidateBaseURL)
            } catch let apiError as APIError {
                throw apiError
            } catch {
                throw APIError.urlNonValido
            }

            do {
                let result = try await performSingleRequest(
                    candidateRequest,
                    retryPolicy: index == 0 ? retryPolicy : .none
                )
                endpointStore.registerSuccessfulResponse(
                    requestURL: candidateRequest.url,
                    response: result.1
                )
                return result
            } catch let failure as EndpointTransportFailure {
                if failure.canTryAnotherEndpoint, index < candidateBaseURLs.count - 1 {
                    lastFallbackError = failure.apiError
                    continue
                }
                throw failure.apiError
            }
        }

        throw lastFallbackError
            ?? APIError.backendNonRaggiungibile(
                "Non riesco a raggiungere nessun endpoint Sinfonia4You configurato."
            )
    }

    private func performSingleRequest(
        _ request: URLRequest,
        retryPolicy: RetryPolicy
    ) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            if case .retryOnceOnTransientFailure = retryPolicy, shouldRetry(urlError) {
                try? await Task.sleep(nanoseconds: 800_000_000)
                do {
                    return try await session.data(for: request)
                } catch let retryError as URLError {
                    throw EndpointTransportFailure(
                        apiError: mappa(urlError: retryError, request: request),
                        canTryAnotherEndpoint: shouldTryAnotherEndpoint(retryError)
                    )
                } catch {
                    throw error
                }
            }
            throw EndpointTransportFailure(
                apiError: mappa(urlError: urlError, request: request),
                canTryAnotherEndpoint: shouldTryAnotherEndpoint(urlError)
            )
        } catch {
            throw error
        }
    }

    private func rebuildRequest(
        _ request: URLRequest,
        withBaseURLString baseURLString: String
    ) throws -> URLRequest {
        guard let originalURL = request.url,
              var baseComponents = URLComponents(string: baseURLString) else {
            throw APIError.urlNonValido
        }
        let originalComponents = URLComponents(url: originalURL, resolvingAgainstBaseURL: false)

        baseComponents.path = originalURL.path
        baseComponents.percentEncodedQuery = originalComponents?.percentEncodedQuery
        baseComponents.fragment = originalURL.fragment

        guard let rebuiltURL = baseComponents.url else {
            throw APIError.urlNonValido
        }

        var rebuiltRequest = request
        rebuiltRequest.url = rebuiltURL
        return rebuiltRequest
    }

    private func shouldRetry(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut,
             .networkConnectionLost,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private func shouldTryAnotherEndpoint(_ error: URLError) -> Bool {
        switch error.code {
        case .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private func mappa(urlError: URLError, request: URLRequest) -> APIError {
        let path = request.url?.path ?? ""
        let isLogin = path == "/api/v1/auth/login"

        switch urlError.code {
        case .timedOut:
            let message = isLogin
                ? "Il server di accesso Sinfonia4You non sta rispondendo in tempo. In questo momento il problema e sul backend: riprova tra poco."
                : "Il server Sinfonia4You non sta rispondendo in tempo. Riprova tra poco."
            return .timeout(message)

        case .notConnectedToInternet:
            return .backendNonRaggiungibile("Connessione internet assente. Controlla Wi-Fi o rete dati e riprova.")

        case .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed:
            return .backendNonRaggiungibile("Non riesco a raggiungere il server Sinfonia4You. Verifica la connessione e riprova.")

        case .networkConnectionLost:
            return .backendNonRaggiungibile("La connessione con il server Sinfonia4You si e interrotta durante la richiesta. Riprova.")

        default:
            return .backendNonRaggiungibile("Non riesco a completare la richiesta verso Sinfonia4You in questo momento. Riprova.")
        }
    }

    private func request<T: Decodable>(
        path: String,
        token: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        guard var components = URLComponents(string: baseURLString + path) else {
            throw APIError.urlNonValido
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw APIError.urlNonValido
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodifica
        }
    }

    private func technicalSheetQueryItems(seasonId: String) -> [URLQueryItem] {
        let cleanSeasonId = seasonId.trimmingCharacters(in: .whitespacesAndNewlines)
        // Se non passo nulla mantengo il comportamento legacy: il backend usa la
        // stagione di default restituita dal portale.
        guard !cleanSeasonId.isEmpty else { return [] }
        return [URLQueryItem(name: "season_id", value: cleanSeasonId)]
    }

    private func jsonRequest<T: Decodable>(path: String, token: String, payload: [String: String]) async throws -> T {
        guard let url = URL(string: baseURLString + path) else {
            throw APIError.urlNonValido
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodifica
        }
    }

    private func multipartRequest<T: Decodable>(
        path: String,
        token: String,
        fields: [String: String],
        fileFieldName: String,
        file: FileSelezionatoApp?
    ) async throws -> T {
        guard let url = URL(string: baseURLString + path) else {
            throw APIError.urlNonValido
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildMultipartBody(
            fields: fields,
            fileFieldName: fileFieldName,
            file: file,
            boundary: boundary
        )

        let (data, response) = try await esegui(request: request)
        try valida(response: response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodifica
        }
    }

    private func buildMultipartBody(
        fields: [String: String],
        fileFieldName: String,
        file: FileSelezionatoApp?,
        boundary: String
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        for (key, value) in fields {
            body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
            body.append("\(value)\(lineBreak)".data(using: .utf8)!)
        }

        if let file {
            body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(file.fileName)\"\(lineBreak)".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
            body.append(file.data)
            body.append(lineBreak.data(using: .utf8)!)
        }

        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return body
    }
}
