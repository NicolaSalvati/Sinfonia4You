//
//  ContentView.swift
//  Sinfonia4You
//
//  Created by Nicola on 14/03/26.
//

import SwiftUI
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authViewModel = AuthViewModel()
    @State private var mostraSchermataProtetta = false

    var body: some View {
        ZStack {
            if let sessione = authViewModel.sessione {
                ContenitoreDashboardView(
                    authViewModel: authViewModel,
                    sessione: sessione,
                    onRequireLogout: {
                        authViewModel.eseguiLogout()
                    }
                )
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                VistaLogin(
                    username: $authViewModel.username,
                    password: $authViewModel.password,
                    inCaricamento: authViewModel.inCaricamento,
                    messaggioErrore: authViewModel.messaggioErrore,
                    biometricDisplayName: authViewModel.biometricDisplayName,
                    biometricIconName: authViewModel.biometricIconName,
                    canUseBiometricLogin: authViewModel.canUseBiometricLogin,
                    onLogin: {
                        Task {
                            await authViewModel.eseguiLogin()
                        }
                    },
                    onBiometricLogin: {
                        Task {
                            await authViewModel.eseguiLoginBiometrico()
                        }
                    }
                )
                .transition(.opacity)
            }

            if mostraSchermataProtetta, authViewModel.sessione != nil {
                SchermataProtezioneSessioneView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            authViewModel.refreshBiometricState()
        }
        .onChange(of: scenePhase) { _, nuovaFase in
            switch nuovaFase {
            case .active:
                authViewModel.applicazioneTornataAttiva()
                withAnimation(.easeOut(duration: 0.18)) {
                    mostraSchermataProtetta = false
                }
            case .inactive:
                withAnimation(.easeOut(duration: 0.12)) {
                    mostraSchermataProtetta = true
                }
            case .background:
                mostraSchermataProtetta = true
                authViewModel.applicazioneEntrataInBackground()
            @unknown default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sinfoniaSessioneScaduta)) { notification in
            guard authViewModel.sessione != nil else { return }
            let message = (notification.userInfo?["message"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = "Sessione Sinfonia scaduta. Effettua di nuovo il login."
            authViewModel.eseguiLogout(messaggio: message?.isEmpty == false ? (message ?? fallback) : fallback)
        }
    }
}

private struct SchermataProtezioneSessioneView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x071632),
                    Color(hex: 0x0A2150),
                    Color(hex: 0x071632)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color(hex: 0x2E7BE0).opacity(0.20), .clear],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 260
            )

            VStack(spacing: 18) {
                Image("LogoAIA")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )

                Text("Sinfonia4You")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Sessione protetta")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
            }
            .padding(28)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Login

private struct VistaLogin: View {
    @Binding var username: String
    @Binding var password: String
    let inCaricamento: Bool
    let messaggioErrore: String
    let biometricDisplayName: String
    let biometricIconName: String
    let canUseBiometricLogin: Bool
    let onLogin: () -> Void
    let onBiometricLogin: () -> Void

    var body: some View {
        ZStack {
            SfondoAutenticazioneView()

            VStack(spacing: 0) {
                Spacer(minLength: 54)

                Image("LogoAIA")
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(hex: 0xD0AC63), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)

                Text("Sinfonia4You")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 26)

                Text("Portale Ufficiale Arbitri AIA")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .padding(.top, 6)

                Rectangle()
                    .fill(Color(hex: 0xC8A96B))
                    .frame(width: 126, height: 2)
                    .cornerRadius(1)
                    .padding(.top, 28)

                VStack(spacing: 14) {
                    CampoCredenziale(
                        titolo: "Username",
                        iconaSistema: "person",
                        testo: $username
                    )

                    CampoCredenziale(
                        titolo: "Password",
                        iconaSistema: "lock",
                        testo: $password,
                        sicuro: true
                    )
                }
                .padding(.top, 42)

                if !messaggioErrore.isEmpty {
                    Text(messaggioErrore)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: 0xFF8F8F))
                        .multilineTextAlignment(.center)
                        .padding(.top, 18)
                }

                Button(action: onLogin) {
                    ZStack {
                        Text(inCaricamento ? "ACCESSO IN CORSO..." : "ACCEDI")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white.opacity(inCaricamento ? 0.88 : 1))
                            .opacity(inCaricamento ? 0.25 : 1)

                        if inCaricamento {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x1864B7),
                                Color(hex: 0x2E7BE0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: 0x2E7BE0).opacity(0.22), radius: 14, y: 6)
                }
                .disabled(inCaricamento)
                .padding(.top, 52)

                if canUseBiometricLogin {
                    Button(action: onBiometricLogin) {
                        HStack(spacing: 12) {
                            Image(systemName: biometricIconName)
                                .font(.system(size: 20, weight: .bold))
                            Text("Accedi con \(biometricDisplayName)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(inCaricamento)
                    .padding(.top, 14)
                }

                if let recuperoPasswordURL = URL(string: "https://servizi.aia-figc.it/sinfonia4you/area_assistenza/recupero_password/") {
                    Link(destination: recuperoPasswordURL) {
                        Text("Password dimenticata?")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(hex: 0x6D9AD3))
                    }
                    .padding(.top, 18)
                }

                Spacer()

                Text("© FIGC")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.22))
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, 34)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Dashboard Container

private struct ContenitoreDashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var tabSelezionata: TabDashboard = .home
    @State private var percorso = NavigationPath()
    @StateObject private var eventiNotifier = EventiNotificationStore.shared
    @StateObject private var comunicazioniNotifier = ComunicazioniNotificationStore.shared
    @StateObject private var promemoriaStore = PromemoriaGareStore.shared
    @ObservedObject var authViewModel: AuthViewModel
    let sessione: SessioneApp
    let onRequireLogout: () -> Void

    private var badgeNotizie: Int {
        eventiNotifier.unreadCount + comunicazioniNotifier.unreadCount
    }

    var body: some View {
        NavigationStack(path: $percorso) {
            TabView(selection: $tabSelezionata) {
                Tab(
                    TabDashboard.home.titolo,
                    systemImage: TabDashboard.home.iconaSistema,
                    value: .home
                ) {
                    scenaTab {
                        VistaHomeDashboard(
                            token: sessione.token,
                            home: sessione.home,
                            onApriGara: apriDettaglioGara,
                            onApriComunicazione: apriDettaglioComunicazione
                        )
                    }
                }

                Tab(
                    TabDashboard.gare.titolo,
                    systemImage: TabDashboard.gare.iconaSistema,
                    value: .gare
                ) {
                    scenaTab {
                        VistaElencoReparti(
                            token: sessione.token,
                            titolo: "Gestione Gare",
                            moduliVisibili: ["matches", "technical_sheet", "referti"]
                        )
                    }
                }

                Tab(
                    TabDashboard.profilo.titolo,
                    systemImage: TabDashboard.profilo.iconaSistema,
                    value: .profilo
                ) {
                    scenaTab {
                        VistaProfiloDashboard(
                            token: sessione.token,
                            profilo: sessione.profile,
                            moduliVisibili: [
                                "profile",
                                "curriculum",
                                "iban",
                                "documents",
                                "quotes",
                                "certificate_renewal",
                                "certificate_history",
                                "indisponibilita_request",
                                "indisponibilita_history",
                                "congedo_request",
                                "congedo_history",
                                "preclusione_request",
                                "preclusione_history",
                                "domande_request",
                                "domande_history",
                            ]
                        )
                    }
                }

                Tab(
                    TabDashboard.notizie.titolo,
                    systemImage: TabDashboard.notizie.iconaSistema,
                    value: .notizie
                ) {
                    scenaTab {
                        VistaElencoReparti(
                            token: sessione.token,
                            titolo: "Eventi e Comunicazioni",
                            moduliVisibili: ["events", "communications"]
                        )
                    }
                }
                .badge(badgeNotizie)

                Tab(
                    TabDashboard.impostazioni.titolo,
                    systemImage: TabDashboard.impostazioni.iconaSistema,
                    value: .impostazioni
                ) {
                    scenaTab {
                        VistaImpostazioniDashboard(
                            authViewModel: authViewModel,
                            onRequireLogout: onRequireLogout
                        )
                    }
                }
            }
            .stileTabBarSistemaSinfonia()
            .navigationDestination(for: RepartoSintesiDTO.self) { modulo in
                vistaDestinazioneModulo(
                    token: sessione.token,
                    modulo: modulo,
                    onRequireLogout: onRequireLogout
                )
            }
            .navigationDestination(for: DestinazioneGaraHome.self) { destinazione in
                VistaDettaglioGara(
                    token: sessione.token,
                    designazioneId: destinazione.designazioneId,
                    titolo: destinazione.titolo
                )
            }
            .navigationDestination(for: DestinazioneComunicazioneHome.self) { destinazione in
                VistaDettaglioComunicazioneDashboard(
                    token: sessione.token,
                    communicationID: destinazione.communicationID,
                    fallbackTitle: destinazione.title,
                    fallbackExcerpt: destinazione.excerpt,
                    fallbackDate: destinazione.date
                )
            }
        }
        .sinfoniaNavigationRoot()
        .task(id: sessione.token) {
            await eventiNotifier.configureSession(userIdentifier: sessione.profile.code)
            await comunicazioniNotifier.configureSession(userIdentifier: sessione.profile.code)
            promemoriaStore.configureSession(userIdentifier: sessione.profile.code)
            await authViewModel.aggiornaHome(silent: true)
            await sincronizzaStatoInizialeNotizie()
        }
        .task(id: sessione.profile.code) {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            while !Task.isCancelled {
                guard scenePhase == .active else {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    continue
                }
                await sincronizzaNotificheDashboard()
                try? await Task.sleep(nanoseconds: 180_000_000_000)
            }
        }
        .onChange(of: scenePhase) { _, nuovaFase in
            guard nuovaFase == .active else { return }
            Task {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard scenePhase == .active else { return }
                await sincronizzaNotificheDashboard()
            }
        }
    }

    // Eseguiamo le chiamate indipendenti in parallelo per ridurre la latenza percepita.
    private func sincronizzaStatoInizialeNotizie() async {
        async let comunicazioniTask: Void = comunicazioniNotifier.sync(
            token: sessione.token,
            userIdentifier: sessione.profile.code
        )
        async let promemoriaTask: Void = promemoriaStore.sync(
            token: sessione.token,
            userIdentifier: sessione.profile.code
        )
        _ = await (comunicazioniTask, promemoriaTask)
    }

    // Polling periodico: aggiorna eventi/comunicazioni/promemoria senza serializzare le richieste.
    private func sincronizzaNotificheDashboard() async {
        async let eventiTask: Void = eventiNotifier.sync(
            token: sessione.token,
            userIdentifier: sessione.profile.code,
            notifyOnNewItems: true
        )
        async let comunicazioniTask: Void = comunicazioniNotifier.sync(
            token: sessione.token,
            userIdentifier: sessione.profile.code
        )
        async let promemoriaTask: Void = promemoriaStore.sync(
            token: sessione.token,
            userIdentifier: sessione.profile.code
        )
        _ = await (eventiTask, comunicazioniTask, promemoriaTask)
    }

    private func scenaTab<Contenuto: View>(
        @ViewBuilder contenuto: () -> Contenuto
    ) -> some View {
        ZStack {
            SfondoDashboardView()
                .ignoresSafeArea()

            contenuto()
        }
    }

    private func apriDettaglioGara(_ gara: GaraHomeDTO) {
        let designazioneId = gara.idDesignazione.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !designazioneId.isEmpty else { return }
        percorso.append(
            DestinazioneGaraHome(
                designazioneId: designazioneId,
                titolo: gara.title
            )
        )
    }

    private func apriDettaglioComunicazione(_ notizia: NotiziaHomeDTO) {
        let communicationID = notizia.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !communicationID.isEmpty else { return }
        percorso.append(
            DestinazioneComunicazioneHome(
                communicationID: communicationID,
                title: notizia.title,
                excerpt: notizia.excerpt,
                date: notizia.date
            )
        )
    }
}

private struct DestinazioneGaraHome: Hashable {
    let designazioneId: String
    let titolo: String
}

private struct DestinazioneComunicazioneHome: Hashable {
    let communicationID: String
    let title: String
    let excerpt: String
    let date: String
}

// MARK: - Modifiers iOS

private extension View {
    @ViewBuilder
    func stileTabBarSistemaSinfonia() -> some View {
        #if os(iOS)
        self
            .tint(Color(hex: 0x2E7BE0))
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        #else
        self
            .tint(Color(hex: 0x2E7BE0))
        #endif
    }
}

// MARK: - Home Dashboard

private struct VistaHomeDashboard: View {
    @ObservedObject private var comunicazioniNotifier = ComunicazioniNotificationStore.shared
    let token: String
    let home: HomePayloadDTO
    let onApriGara: (GaraHomeDTO) -> Void
    let onApriComunicazione: (NotiziaHomeDTO) -> Void

    private var gareDelGiorno: [GaraHomeDTO] {
        var items: [GaraHomeDTO] = []

        if let todayMatches = home.todayMatches, !todayMatches.isEmpty {
            items.append(contentsOf: todayMatches)
        } else {
            if let prossima = home.nextMatch, Self.isTodayMatch(prossima) {
                items.append(prossima)
            }
            if let recente = home.recentMatch,
               Self.isTodayMatch(recente),
               !items.contains(where: { $0.idDesignazione == recente.idDesignazione }) {
                items.append(recente)
            }
        }

        return items
            .filter { Self.shouldShowPreMatchDashboard(for: $0) }
            .sorted { lhs, rhs in
                let lhsDate = Self.parseKickoff(for: lhs) ?? .distantFuture
                let rhsDate = Self.parseKickoff(for: rhs) ?? .distantFuture
                return lhsDate < rhsDate
            }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                IntestazioneDashboardView()

                if home.isPartial {
                    StatoAggiornamentoHomeView()
                }

                if !gareDelGiorno.isEmpty {
                    TitoloSezioneView(testo: "Dashboard intelligente pre-partita")

                    VStack(spacing: 16) {
                        ForEach(gareDelGiorno) { gara in
                            DashboardPrePartitaHomeView(
                                token: token,
                                gara: gara,
                                onApriGara: onApriGara
                            )
                        }
                    }
                }

                TitoloSezioneView(testo: "Agenda Arbitrale")

                VistaAgendaHomeView(
                    prossimaGara: home.nextMatch,
                    ultimaGara: home.recentMatch,
                    onApriGara: onApriGara
                )

                TitoloSezioneView(testo: "Riepilogo Operativo")

                BachecaOperativaArbitroHomeView(home: home)

                TitoloSezioneView(testo: "Comunicazioni Recenti")

                VStack(spacing: 14) {
                    if home.news.isEmpty {
                        SchedaNessunaNotiziaView(
                            titolo: home.isPartial ? "Sto aggiornando le comunicazioni..." : "Nessuna comunicazione recente",
                            sottotitolo: home.isPartial
                                ? "Sto caricando le ultime notizie del portale."
                                : "Le ultime comunicazioni appariranno qui."
                        )
                    } else {
                        ForEach(home.news.prefix(3)) { notizia in
                            Button {
                                onApriComunicazione(notizia)
                            } label: {
                                SchedaNotiziaView(
                                    notizia: notizia,
                                    isNew: comunicazioniNotifier.unreadCommunicationIDs.contains(notizia.id)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
    }

    private static func isTodayMatch(_ gara: GaraHomeDTO) -> Bool {
        if gara.isToday == true {
            return true
        }

        let todayLabel = DateFormatter.homeDateOnly.string(from: Date())
        if gara.dateValue?.trimmingCharacters(in: .whitespacesAndNewlines) == todayLabel {
            return true
        }

        guard let kickoff = parseKickoff(for: gara) else { return false }
        return Calendar(identifier: .gregorian).isDateInToday(kickoff)
    }

    private static func shouldShowPreMatchDashboard(for gara: GaraHomeDTO) -> Bool {
        guard isTodayMatch(gara) else {
            return false
        }

        guard let kickoff = parseKickoff(for: gara) else {
            // Se la gara e' confermata per oggi ma l'orario non e' parsabile,
            // e' meglio mostrare la dashboard piuttosto che nasconderla.
            return true
        }

        let now = Date()
        let calendar = Calendar(identifier: .gregorian)

        // In assenza dell'orario di fine reale nel portale, assumiamo
        // una durata standard di 2 ore e manteniamo la dashboard per
        // un'ulteriore ora dopo la fine stimata.
        let hideDate = calendar.date(byAdding: .hour, value: 3, to: kickoff) ?? kickoff
        return now <= hideDate
    }

    private static func parseKickoff(for gara: GaraHomeDTO) -> Date? {
        if let dateValue = gara.dateValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !dateValue.isEmpty {
            let timeValue = gara.timeValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "00:00"
            if let date = DateFormatter.homeDateTime.date(from: "\(dateValue) \(timeValue)") {
                return date
            }
        }

        let cleaned = gara.scheduleLabel.replacingOccurrences(of: "·", with: " ")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"

        let regex = try? NSRegularExpression(pattern: #"(\d{2}/\d{2}/\d{4}).*?(\d{1,2}:\d{2})"#)
        let nsRange = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
        if let match = regex?.firstMatch(in: cleaned, options: [], range: nsRange),
           let dateRange = Range(match.range(at: 1), in: cleaned),
           let timeRange = Range(match.range(at: 2), in: cleaned) {
            return formatter.date(from: "\(cleaned[dateRange]) \(cleaned[timeRange])")
        }
        return nil
    }
}

private extension DateFormatter {
    static let homeDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    static let homeDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()
}

// MARK: - Sezioni Dashboard

private struct IntestazioneDashboardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image("LogoAIA")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(hex: 0xD0AC63).opacity(0.8), lineWidth: 1.8)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 8, y: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sinfonia4You")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("FIGC · AIA")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Color(hex: 0x4E95E8))
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }
}

private struct BachecaOperativaArbitroHomeView: View {
    let home: HomePayloadDTO

    private var stats: HomeOperationalStatsDTO? { home.operationalStats }

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            SchedaStatisticaArbitroHomeView(
                icon: "trophy.fill",
                titolo: "Gare Arbitrate",
                valore: "\(stats?.completedMatches ?? 0)",
                dettaglio: "gare già disputate"
            )

            SchedaStatisticaArbitroHomeView(
                icon: "calendar.badge.clock",
                titolo: "Gare in Arrivo",
                valore: "\(stats?.upcomingMatches ?? 0)",
                dettaglio: "designazioni da svolgere"
            )

            SchedaStatisticaArbitroHomeView(
                icon: "eurosign.circle.fill",
                titolo: "Rimborsi Stimati",
                valore: testoPulitoHome(stats?.estimatedRefundsTotal ?? "—"),
                dettaglio: "totale gare arbitrate"
            )

            SchedaStatisticaArbitroHomeView(
                icon: "road.lanes",
                titolo: "Chilometri",
                valore: testoPulitoHome(stats?.distanceTotal ?? "—"),
                dettaglio: "percorrenza complessiva"
            )
        }
    }
}

private struct InfoBadgeHomeView: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: 0x9EC8FF))

            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.50))

                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct SchedaStatisticaArbitroHomeView: View {
    let icon: String
    let titolo: String
    let valore: String
    let dettaglio: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: 0x9EC8FF))

            Text(titolo.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.54))

            Text(valore)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.80)

            Text(dettaglio)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.68))
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct SchedaPrioritaArbitraleHomeView: View {
    let titolo: String
    let valore: String
    let badge: String
    let righe: [(String, String)]
    var ctaLabel: String = "Apri scheda gara"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(titolo.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: 0x8FC1FF))

                    Text(valore)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text(badge)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: 0xCFF1FF))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(righe.enumerated()), id: \.offset) { _, riga in
                    if !riga.1.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: riga.0)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x9EC8FF))
                                .frame(width: 18)

                            Text(riga.1)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.82))
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            HStack {
                Text(ctaLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: 0x7FC8FF))

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: 0x7FC8FF))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct SchedaSintesiOperativaHomeView: View {
    let icon: String
    let titolo: String
    let valore: String
    let dettaglio: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: 0x9EC8FF))

            Text(titolo.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.54))

            Text(valore)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.80)

            Text(dettaglio)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.70))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 144, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct SchedaNotiziaView: View {
    let notizia: NotiziaHomeDTO
    let isNew: Bool

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hexString: notizia.accentColor))
                .frame(width: 6)
                .padding(.vertical, 12)
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Text(notizia.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    if isNew {
                        Text("NUOVA")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFFD28C))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(hex: 0xF08A24).opacity(0.18))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color(hex: 0xF08A24).opacity(0.34), lineWidth: 1)
                            )
                    }
                }

                Text(notizia.excerpt)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("Apri comunicazione")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: 0x7FC8FF))

                    Spacer()

                    Spacer()

                    Text(notizia.date)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.62))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: 0x7FC8FF))
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct VistaDettaglioComunicazioneDashboard: View {
    let token: String
    let communicationID: String
    let fallbackTitle: String
    let fallbackExcerpt: String
    let fallbackDate: String

    @ObservedObject private var comunicazioniNotifier = ComunicazioniNotificationStore.shared
    @State private var snapshot: SnapshotModuloDTO?
    @State private var isLoading = true
    @State private var messaggioErrore = ""

    private var row: RigaModuloDTO? {
        snapshot?.rows.first(where: { $0.id == communicationID })
    }

    var body: some View {
        ZStack {
            SfondoDashboardView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if isLoading {
                        StatoAggiornamentoHomeView()
                    } else if let row {
                        SchedaComunicazioneView(
                            token: token,
                            row: row,
                            isNew: comunicazioniNotifier.unreadCommunicationIDs.contains(row.id)
                        )

                        if let legalText = snapshot?.legalText,
                           !legalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            BloccoInformativoComunicazioniView(
                                titolo: "Nota",
                                testo: legalText
                            )
                        }
                    } else if !messaggioErrore.isEmpty {
                        SchedaNessunaNotiziaView(
                            titolo: fallbackTitle.isEmpty ? "Comunicazione non disponibile" : fallbackTitle,
                            sottotitolo: messaggioErrore
                        )
                    } else {
                        SchedaNessunaNotiziaView(
                            titolo: fallbackTitle.isEmpty ? "Comunicazione non trovata" : fallbackTitle,
                            sottotitolo: fallbackExcerpt.isEmpty
                                ? "La comunicazione non e più presente nell'elenco attuale."
                                : fallbackExcerpt
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(fallbackDate.isEmpty ? "Comunicazione" : fallbackDate)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: communicationID) {
            await caricaComunicazione()
        }
    }

    private func caricaComunicazione() async {
        isLoading = true
        messaggioErrore = ""

        do {
            let loadedSnapshot = try await APIClient.shared.snapshotModulo(
                token: token,
                moduleId: "communications"
            )
            snapshot = loadedSnapshot
            if let row = loadedSnapshot.rows.first(where: { $0.id == communicationID }) {
                comunicazioniNotifier.markItemsAsRead([row])
            }
        } catch {
            messaggioErrore = error.localizedDescription
        }

        isLoading = false
    }
}

private struct TitoloSezioneView: View {
    let testo: String

    var body: some View {
        HStack {
            Text(testo)
                .font(.system(size: 23, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.74))

            Spacer()
        }
        .padding(.top, 2)
    }
}

// MARK: - Viste di supporto

private struct VistaSegnapostoDashboard: View {
    let titolo: String
    let sottotitolo: String

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 46, weight: .medium))
                .foregroundStyle(Color(hex: 0x5EA6FF))

            Text(titolo)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(sottotitolo)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SfondoDashboardView())
    }
}

private struct SfondoAutenticazioneView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x081B49),
                    Color(hex: 0x0B1D4B),
                    Color(hex: 0x06163C)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(hex: 0x183A80).opacity(0.40),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 320
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.05),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 250
            )
        }
    }
}

private struct StatoAggiornamentoHomeView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Color(hex: 0x63A8FF))

            Text("Sto aggiornando gare e comunicazioni dal portale...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.78))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct VistaAgendaHomeView: View {
    let prossimaGara: GaraHomeDTO?
    let ultimaGara: GaraHomeDTO?
    let onApriGara: (GaraHomeDTO) -> Void

    var body: some View {
        VStack(spacing: 14) {
            if let prossimaGara {
                SchedaGaraInEvidenzaView(
                    gara: prossimaGara,
                    accentColor: Color(hex: 0x4EA0FF),
                    azioneTap: {
                        onApriGara(prossimaGara)
                    }
                )
            }

            if let ultimaGara {
                SchedaGaraInEvidenzaView(
                    gara: ultimaGara,
                    accentColor: Color(hex: 0x65D7A2),
                    azioneTap: {
                        onApriGara(ultimaGara)
                    }
                )
            }

            if prossimaGara == nil && ultimaGara == nil {
                SchedaNessunaNotiziaView(
                    titolo: "Nessuna gara in evidenza",
                    sottotitolo: "Quando sarà disponibile una prossima o ultima gara, la vedrai qui."
                )
            }
        }
    }
}

private struct SchedaGaraInEvidenzaView: View {
    let gara: GaraHomeDTO
    let accentColor: Color
    let azioneTap: () -> Void

    var body: some View {
        Button(action: azioneTap) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(gara.heading.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)

                        Text(gara.title)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "sportscourt.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    RigaDettaglioGaraHomeView(icona: "calendar", testo: gara.scheduleLabel)
                    RigaDettaglioGaraHomeView(icona: "trophy", testo: gara.competitionLabel)
                }

                FlussoBadgeGaraHomeView(
                    badges: [
                        (gara.activityLabel, "figure.soccer"),
                        (gara.statusLabel, "checkmark.seal"),
                        (gara.refundLabel ?? "", "eurosign.circle"),
                        (gara.distanceLabel ?? "", "road.lanes")
                    ],
                    accentColor: accentColor
                )

                HStack {
                    Text("Apri dettagli gara")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accentColor)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accentColor)
                }
                .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(accentColor.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FlussoBadgeGaraHomeView: View {
    let badges: [(String, String)]
    let accentColor: Color

    var body: some View {
        let validBadges = badges.filter { !testoPulitoHome($0.0).isEmpty }
        if !validBadges.isEmpty {
            HStack(spacing: 8) {
                ForEach(Array(validBadges.enumerated()), id: \.offset) { _, badge in
                    HStack(spacing: 6) {
                        Image(systemName: badge.1)
                            .font(.system(size: 11, weight: .semibold))

                        Text(testoPulitoHome(badge.0))
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accentColor.opacity(0.18))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(accentColor.opacity(0.28), lineWidth: 1)
                    )
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct RigaDettaglioGaraHomeView: View {
    let icona: String
    let testo: String

    var body: some View {
        if !testo.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: icona)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.56))
                    .frame(width: 16)

                Text(testo)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
        }
    }
}

private func testoPulitoHome(_ raw: String) -> String {
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

private func descrizioneCompetizioneHome(_ raw: String) -> (principale: String, dettaglio: String) {
    let cleaned = testoPulitoHome(raw)
    guard !cleaned.isEmpty else {
        return ("Competizione non disponibile", "I dettagli compariranno qui appena caricati.")
    }

    let parti = cleaned
        .split(separator: "|")
        .map { testoPulitoHome(String($0)) }
        .filter { !$0.isEmpty }

    guard let prima = parti.first else {
        return (cleaned, "")
    }

    let dettaglio = parti.dropFirst().joined(separator: " · ")
    return (prima, dettaglio)
}

private struct SchedaNessunaNotiziaView: View {
    let titolo: String
    let sottotitolo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titolo)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(sottotitolo)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}


private struct SfondoDashboardView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x0A1E4D),
                    Color(hex: 0x0C2A63),
                    Color(hex: 0x081735)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(hex: 0x2E7BE0).opacity(0.30),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 420
            )

            RadialGradient(
                colors: [
                    Color(hex: 0x1A94FF).opacity(0.18),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 18,
                endRadius: 340
            )

            RadialGradient(
                colors: [
                    Color(hex: 0x5F9DFF).opacity(0.08),
                    .clear
                ],
                center: .center,
                startRadius: 30,
                endRadius: 360
            )
        }
    }
}

private struct CampoCredenziale: View {
    private enum CampoAttivo: Hashable {
        case protetto
        case visibile
    }

    let titolo: String
    let iconaSistema: String
    @Binding var testo: String
    var sicuro = false
    @State private var mostraTestoSensibile = false
    @FocusState private var campoAttivo: CampoAttivo?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconaSistema)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(width: 20)

            Group {
                if usaCampoProtetto {
                    SecureField("", text: $testo, prompt: prompt)
                        .focused($campoAttivo, equals: .protetto)
                } else {
                    TextField("", text: $testo, prompt: prompt)
                        .focused($campoAttivo, equals: .visibile)
                }
            }
            .foregroundStyle(Color.white)
            .font(.system(size: 18, weight: .medium))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)

            if sicuro {
                // Alterno SecureField e TextField nello stesso contenitore,
                // così bordo, altezza e focus restano stabili quando cambio visibilità.
                Button(action: alternaVisibilitaPassword) {
                    Image(systemName: mostraTestoSensibile ? "eye.slash" : "eye")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.34), lineWidth: 1)
        )
    }

    private var prompt: Text {
        Text(titolo)
            .foregroundStyle(Color.white.opacity(0.42))
    }

    private var usaCampoProtetto: Bool {
        sicuro && !mostraTestoSensibile
    }

    private func alternaVisibilitaPassword() {
        mostraTestoSensibile.toggle()
        let destinazione: CampoAttivo = usaCampoProtetto ? .protetto : .visibile
        Task { @MainActor in
            campoAttivo = destinazione
        }
    }
}

// MARK: - Utility

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    init(hexString: String) {
        let clean = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard let value = UInt(clean, radix: 16) else {
            self.init(hex: 0xFFFFFF)
            return
        }

        self.init(hex: value)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
