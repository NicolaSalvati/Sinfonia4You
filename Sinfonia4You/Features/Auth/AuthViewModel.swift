//
//  AuthViewModel.swift
//  Sinfonia4You
//
//  Gestisce autenticazione e caricamento sessione iniziale.
//

import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    private static let sessionePersistitaKey = "sinfonia4you.sessione.persistita"
    private static let ultimoUsernameKey = "sinfonia4you.sessione.username"
    private static let ultimoBackgroundKey = "sinfonia4you.sessione.background_at"
    private static let timeoutInattivitaSecondi: TimeInterval = 300
    private static let messaggioLogoutAutomatico = "Sessione chiusa per inattivita. Accedi di nuovo per continuare."

    private enum OrigineChiusuraSessione {
        case nessuna
        case logoutManuale
        case sessioneScadutaAllAvvio
        case timeoutDaBackground
    }

    @Published var username = ""
    @Published var password = ""
    @Published var sessione: SessioneApp?
    @Published var inCaricamento = false
    @Published var messaggioErrore = ""
    @Published var biometricMessage = ""

    private let apiClient: APIClient
    private let biometricAuthManager: BiometricAuthManager
    private var biometricState: BiometricAuthState
    private var lastSuccessfulCredentials: StoredPortalCredentials?
    private var ultimaOrigineChiusuraSessione: OrigineChiusuraSessione = .nessuna
    private var haSubitoTimeoutDaBackground = false

    init() {
        self.apiClient = .shared
        self.biometricAuthManager = .shared
        self.biometricState = BiometricAuthManager.shared.currentState()
        ripristinaSessionePersistita()
    }

    init(apiClient: APIClient, biometricAuthManager: BiometricAuthManager? = nil) {
        let resolvedBiometricAuthManager = biometricAuthManager ?? .shared
        self.apiClient = apiClient
        self.biometricAuthManager = resolvedBiometricAuthManager
        self.biometricState = resolvedBiometricAuthManager.currentState()
        ripristinaSessionePersistita()
    }

    var autenticato: Bool {
        sessione != nil
    }

    var biometricSupported: Bool {
        biometricState.isAvailable
    }

    var biometricEnabled: Bool {
        biometricState.isEnabled
    }

    var biometricDisplayName: String {
        biometricState.displayName
    }

    var biometricIconName: String {
        biometricState.iconName
    }

    var canUseBiometricLogin: Bool {
        biometricState.canLogin && !inCaricamento
    }

    var biometricHint: String {
        if biometricEnabled {
            return "Sblocca il login con \(biometricDisplayName) e accedi senza reinserire la password."
        }
        if biometricSupported {
            return "Attiva \(biometricDisplayName) per entrare più velocemente e usare il Portachiavi protetto di iPhone."
        }
        return "La biometria non è disponibile su questo dispositivo o non è ancora configurata."
    }

    func refreshBiometricState() {
        biometricState = biometricAuthManager.currentState()
    }

    func eseguiLogin() async {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUsername.isEmpty else {
            messaggioErrore = "Inserisci lo username."
            return
        }
        guard !password.isEmpty else {
            messaggioErrore = "Inserisci la password."
            return
        }

        await eseguiLogin(
            con: StoredPortalCredentials(username: cleanUsername, password: password),
            origineBiometrica: false
        )
    }

    func aggiornaHome(silent: Bool = false) async {
        guard let sessione else { return }
        let currentToken = sessione.token

        do {
            let homeAggiornata = try await apiClient.home(token: currentToken)
            let homeNormalizzata = try await homeConStatisticheOperativeAffidabili(
                homeAggiornata,
                token: currentToken
            )

            guard self.sessione?.token == currentToken else { return }
            self.sessione = SessioneApp(
                token: currentToken,
                profile: homeNormalizzata.profile,
                home: homeNormalizzata
            )
            salvaSessionePersistita()
        } catch {
            if !silent {
                messaggioErrore = error.localizedDescription
            }
        }
    }

    func enableBiometricLogin() async {
        biometricMessage = ""
        refreshBiometricState()

        guard biometricSupported else {
            biometricMessage = biometricHint
            return
        }

        guard let credentials = credenzialiDisponibiliPerBiometria() else {
            biometricMessage = "Per attivare \(biometricDisplayName), esegui prima un login manuale con username e password."
            refreshBiometricState()
            return
        }

        do {
            try biometricAuthManager.enable(with: credentials)
            lastSuccessfulCredentials = credentials
            biometricMessage = "\(biometricDisplayName) attivato. Dalla prossima apertura potrai entrare con un solo passaggio."
        } catch {
            biometricMessage = error.localizedDescription
        }

        refreshBiometricState()
    }

    func disableBiometricLogin() {
        biometricAuthManager.disable()
        biometricMessage = "Accesso con \(biometricDisplayName) disattivato."
        refreshBiometricState()
    }

    func eseguiLoginBiometrico() async {
        refreshBiometricState()
        guard biometricState.canLogin else {
            messaggioErrore = biometricState.isAvailable
                ? "Attiva prima \(biometricDisplayName) nelle impostazioni dell'app."
                : biometricHint
            return
        }

        inCaricamento = true
        messaggioErrore = ""
        biometricMessage = ""

        do {
            let credentials = try biometricAuthManager.loadCredentials(
                prompt: "Accedi a Sinfonia4You con \(biometricDisplayName)"
            )
            username = credentials.username
            password = credentials.password
            await eseguiLogin(con: credentials, origineBiometrica: true)
        } catch {
            if case BiometricAuthError.cancelled = error {
                messaggioErrore = ""
            } else {
                messaggioErrore = error.localizedDescription
            }
            inCaricamento = false
            refreshBiometricState()
        }
    }

    func eseguiLogout(messaggio: String = "", preservaUsername: Bool = false) {
        eseguiLogoutInterno(
            messaggio: messaggio,
            preservaUsername: preservaUsername,
            origine: .logoutManuale
        )
    }

    func applicazioneEntrataInBackground(at date: Date = Date()) {
        guard sessione != nil else {
            UserDefaults.standard.removeObject(forKey: Self.ultimoBackgroundKey)
            return
        }

        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: Self.ultimoBackgroundKey)
    }

    func applicazioneTornataAttiva(at date: Date = Date()) {
        guard sessione != nil else {
            UserDefaults.standard.removeObject(forKey: Self.ultimoBackgroundKey)
            return
        }

        guard let ultimoBackground = Self.ultimoIstanteBackground() else { return }
        UserDefaults.standard.removeObject(forKey: Self.ultimoBackgroundKey)

        guard date.timeIntervalSince(ultimoBackground) >= Self.timeoutInattivitaSecondi else { return }
        // Uso il logout interno perché qui devo fare lo stesso reset di cache e sessione
        // del logout normale, ma preservando username e messaggio del timeout.
        eseguiLogoutInterno(
            messaggio: Self.messaggioLogoutAutomatico,
            preservaUsername: true,
            origine: .timeoutDaBackground
        )
    }

    private func eseguiLogin(
        con credentials: StoredPortalCredentials,
        origineBiometrica: Bool
    ) async {
        inCaricamento = true
        messaggioErrore = ""
        if !origineBiometrica {
            biometricMessage = ""
        }

        do {
            let risposta = try await apiClient.login(
                username: credentials.username,
                password: credentials.password
            )
            sessione = SessioneApp(
                token: risposta.accessToken,
                profile: risposta.profile,
                home: risposta.home
            )
            ultimaOrigineChiusuraSessione = .nessuna
            haSubitoTimeoutDaBackground = false
            username = credentials.username
            password = credentials.password
            lastSuccessfulCredentials = credentials
            salvaSessionePersistita()

            if biometricEnabled {
                do {
                    try biometricAuthManager.enable(with: credentials)
                    if !origineBiometrica {
                        biometricMessage = "\(biometricDisplayName) aggiornato con le credenziali correnti."
                    }
                } catch {
                    biometricMessage = error.localizedDescription
                }
            }

            refreshBiometricState()
            inCaricamento = false
            return
        } catch {
            messaggioErrore = error.localizedDescription
        }

        inCaricamento = false
        refreshBiometricState()
    }

    private func credenzialiDisponibiliPerBiometria() -> StoredPortalCredentials? {
        if let lastSuccessfulCredentials {
            return lastSuccessfulCredentials
        }

        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUsername.isEmpty, !password.isEmpty else {
            return nil
        }

        return StoredPortalCredentials(username: cleanUsername, password: password)
    }

    private func homeConStatisticheOperativeAffidabili(
        _ home: HomePayloadDTO,
        token: String
    ) async throws -> HomePayloadDTO {
        guard necessitaFallbackStatisticheOperative(home) else {
            return home
        }

        let overview = try await apiClient.schedaTecnicaOverview(token: token)
        let stats = HomeOperationalStatsDTO(
            completedMatches: max(home.operationalStats?.completedMatches ?? 0, overview.summary.completedMatches),
            upcomingMatches: max(home.operationalStats?.upcomingMatches ?? 0, overview.summary.matchesCount - overview.summary.completedMatches),
            estimatedRefundsTotal: testoStatisticoValido(home.operationalStats?.estimatedRefundsTotal)
                ? (home.operationalStats?.estimatedRefundsTotal ?? overview.summary.totalRefunds)
                : overview.summary.totalRefunds,
            distanceTotal: testoStatisticoValido(home.operationalStats?.distanceTotal)
                ? (home.operationalStats?.distanceTotal ?? overview.summary.totalDistance)
                : overview.summary.totalDistance
        )

        return HomePayloadDTO(
            profile: home.profile,
            isPartial: home.isPartial,
            todayMatches: home.todayMatches,
            nextMatch: home.nextMatch,
            recentMatch: home.recentMatch,
            operationalStats: stats,
            quickActions: home.quickActions,
            news: home.news
        )
    }

    private func necessitaFallbackStatisticheOperative(_ home: HomePayloadDTO) -> Bool {
        guard let stats = home.operationalStats else { return true }
        return !testoStatisticoValido(stats.estimatedRefundsTotal) || !testoStatisticoValido(stats.distanceTotal)
    }

    private func testoStatisticoValido(_ value: String?) -> Bool {
        let cleanValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !cleanValue.isEmpty else { return false }
        return cleanValue != "—"
    }

    private func ripristinaSessionePersistita() {
        if let savedUsername = UserDefaults.standard.string(forKey: Self.ultimoUsernameKey) {
            username = savedUsername
        }

        guard let data = UserDefaults.standard.data(forKey: Self.sessionePersistitaKey) else {
            UserDefaults.standard.removeObject(forKey: Self.ultimoBackgroundKey)
            ultimaOrigineChiusuraSessione = .nessuna
            haSubitoTimeoutDaBackground = false
            return
        }

        if Self.sessionePersistitaScadutaPerInattivita() {
            // Cancello subito sessione e timestamp persistiti, così il login parte pulito
            // e non trova più un vecchio stato di background al successivo avvio.
            ultimaOrigineChiusuraSessione = .sessioneScadutaAllAvvio
            haSubitoTimeoutDaBackground = false
            cancellaSessionePersistita(preservaUsername: true)
            return
        }

        guard let sessioneRipristinata = try? JSONDecoder().decode(SessioneApp.self, from: data) else {
            UserDefaults.standard.removeObject(forKey: Self.sessionePersistitaKey)
            UserDefaults.standard.removeObject(forKey: Self.ultimoBackgroundKey)
            ultimaOrigineChiusuraSessione = .nessuna
            haSubitoTimeoutDaBackground = false
            return
        }

        UserDefaults.standard.removeObject(forKey: Self.ultimoBackgroundKey)
        ultimaOrigineChiusuraSessione = .nessuna
        haSubitoTimeoutDaBackground = false
        sessione = sessioneRipristinata
    }

    private func salvaSessionePersistita() {
        guard let sessione else { return }

        if let data = try? JSONEncoder().encode(sessione) {
            UserDefaults.standard.set(data, forKey: Self.sessionePersistitaKey)
        }

        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanUsername.isEmpty {
            UserDefaults.standard.set(cleanUsername, forKey: Self.ultimoUsernameKey)
        }

        UserDefaults.standard.removeObject(forKey: Self.ultimoBackgroundKey)
    }

    private func cancellaSessionePersistita(preservaUsername: Bool) {
        UserDefaults.standard.removeObject(forKey: Self.sessionePersistitaKey)
        UserDefaults.standard.removeObject(forKey: Self.ultimoBackgroundKey)
        if !preservaUsername {
            UserDefaults.standard.removeObject(forKey: Self.ultimoUsernameKey)
        }
    }

    private func eseguiLogoutInterno(
        messaggio: String,
        preservaUsername: Bool,
        origine: OrigineChiusuraSessione
    ) {
        ultimaOrigineChiusuraSessione = origine
        haSubitoTimeoutDaBackground = origine == .timeoutDaBackground
        EventiNotificationStore.shared.resetSession()
        ComunicazioniNotificationStore.shared.resetSession()
        PromemoriaGareStore.shared.resetSession()
        cancellaSessionePersistita(preservaUsername: preservaUsername)
        sessione = nil
        password = ""
        inCaricamento = false
        messaggioErrore = messaggio
        biometricMessage = ""
        refreshBiometricState()
    }

    private static func ultimoIstanteBackground() -> Date? {
        guard let timestamp = UserDefaults.standard.object(forKey: ultimoBackgroundKey) as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    private static func sessionePersistitaScadutaPerInattivita(referenceDate: Date = Date()) -> Bool {
        guard let ultimoBackground = ultimoIstanteBackground() else { return false }
        return referenceDate.timeIntervalSince(ultimoBackground) >= timeoutInattivitaSecondi
    }
}
