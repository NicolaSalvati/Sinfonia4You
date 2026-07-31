import AVFoundation
import Combine
import SwiftUI

private enum RapportoGaraPalette {
    static let accent = Color(hex: 0x4EA0FF)
    static let accentSoft = Color(hex: 0x9EC8FF)
    static let primaryStart = accent
    static let primaryEnd = Color(hex: 0x2C6FD6)
    static let surface = Color.white.opacity(0.045)
    static let surfaceStrong = Color.white.opacity(0.045)
    static let inlineSurface = Color.white.opacity(0.08)
    static let textMuted = Color.white.opacity(0.66)
}

struct VistaRapportoGaraModulo: View {
    let token: String

    @StateObject private var viewModel = SnapshotModuloViewModel()
    @StateObject private var homeViewModel = RapportoGaraHomeMatchesViewModel()

    private var refertiCombinati: [RigaModuloDTO] {
        Self.componiRigheRapportoGara(
            referti: viewModel.snapshot?.rows ?? [],
            gareHome: homeViewModel.gare
        )
    }

    var body: some View {
        Group {
            if let snapshot = viewModel.snapshot {
                VistaRapportoGara(
                    token: token,
                    referti: Self.componiRigheRapportoGara(
                        referti: snapshot.rows,
                        gareHome: homeViewModel.gare
                    )
                )
            } else if viewModel.inCaricamento {
                ZStack {
                    SfondoDettaglioRepartoView()
                        .ignoresSafeArea()

                    ProgressView("Sto preparando Rapporto Gara...")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
            } else {
                VistaRapportoGara(token: token, referti: refertiCombinati)
                    .overlay(alignment: .top) {
                        if !viewModel.errore.isEmpty {
                            VStack {
                                BloccoTestoView(
                                    titolo: "Dati gare non disponibili",
                                    testo: viewModel.errore
                                )
                                .padding(.horizontal, 18)
                                .padding(.top, 18)

                                Spacer()
                            }
                        }
                    }
            }
        }
        .task {
            guard viewModel.snapshot == nil, !viewModel.inCaricamento else { return }
            await viewModel.carica(token: token, moduleId: "referti")
        }
        .task {
            guard homeViewModel.gare.isEmpty, !homeViewModel.inCaricamento else { return }
            await homeViewModel.carica(token: token)
        }
    }

    private static func componiRigheRapportoGara(
        referti: [RigaModuloDTO],
        gareHome: [GaraHomeDTO]
    ) -> [RigaModuloDTO] {
        let righeHome = gareHome.compactMap { gara -> RigaModuloDTO? in
            let designazioneId = gara.idDesignazione.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !designazioneId.isEmpty else { return nil }

            let subtitleParts = [
                gara.scheduleLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                gara.competitionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            ].filter { !$0.isEmpty }

            return RigaModuloDTO(
                id: designazioneId,
                title: gara.title.trimmingCharacters(in: .whitespacesAndNewlines),
                subtitle: subtitleParts.joined(separator: " · "),
                status: gara.statusLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                fields: [],
                attachments: [],
                roleKind: nil,
                roleLabel: gara.activityLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                actionKind: nil,
                actionLabel: nil,
                canPrint: nil,
                canSubmit: nil
            )
        }

        var orderedIDs: [String] = []
        var rowsByID: [String: RigaModuloDTO] = [:]

        for row in righeHome + referti {
            guard !row.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            if rowsByID[row.id] == nil {
                orderedIDs.append(row.id)
            }
            rowsByID[row.id] = row
        }

        return orderedIDs.compactMap { rowsByID[$0] }
    }
}

struct VistaRapportoGara: View {
    let token: String
    let referti: [RigaModuloDTO]

    @StateObject private var store = RapportoGaraStore.shared
    @State private var sessioneDaEliminareID: UUID?

    private var sessioneDaEliminare: SessioneRapportoGara? {
        guard let sessioneDaEliminareID else { return nil }
        return store.sessione(per: sessioneDaEliminareID)
    }

    private var firmaRefertiDisponibili: String {
        referti.map(\.id).joined(separator: "|")
    }

    private var codiceAttivo: CodiceVerificaRapportoGara? {
        store.codiceVerificaAttivo
    }

    private var sessioniOrdinate: [SessioneRapportoGara] {
        store.sessioni.sorted { $0.aggiornataIl > $1.aggiornataIl }
    }

    var body: some View {
        let hasPairings = !store.abbinamenti.isEmpty
        let isDeleteSheetPresented = sessioneDaEliminare != nil

        ZStack(alignment: .bottom) {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            RapportoGaraAmbientBackgroundView()
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .blur(radius: isDeleteSheetPresented ? 18 : 0)
                .opacity(isDeleteSheetPresented ? 0.55 : 1)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    RapportoGaraOverviewHeaderView(
                        totaleSessioni: store.sessioni.count,
                        totaleOrologi: store.abbinamenti.count,
                        watchRaggiungibile: store.watchRaggiungibile,
                        watchAppInstallata: store.watchAppInstallata,
                        totaleGareDisponibili: referti.count
                    )

                    if !store.ultimoMessaggio.isEmpty {
                        RapportoGaraSyncBannerView(message: store.ultimoMessaggio)
                    }

                    RapportoGaraControlDeckView(
                        codice: codiceAttivo,
                        watchAppInstallata: store.watchAppInstallata,
                        hasPairings: hasPairings,
                        watchRaggiungibile: store.watchRaggiungibile,
                        onGenerateCode: {
                            store.generaCodiceVerifica()
                        }
                    )

                    if hasPairings {
                        RapportoGaraDashboardPanel(
                            titolo: "Apple Watch collegati",
                            icona: "applewatch.side.right",
                            badge: "\(store.abbinamenti.count)"
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(store.abbinamenti) { pairing in
                                    RapportoGaraWatchPairRowView(pairing: pairing)
                                }
                            }
                        }
                    }

                    RapportoGaraDashboardPanel(
                        titolo: "Sessioni sincronizzate",
                        icona: "tray.full.fill",
                        badge: "\(sessioniOrdinate.count)"
                    ) {
                        if sessioniOrdinate.isEmpty {
                            RapportoGaraDashboardEmptyState(
                                icona: "tray",
                                titolo: "Nessuna sessione",
                                messaggio: "Le sessioni sincronizzate dal Watch compariranno qui."
                            )
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(sessioniOrdinate) { sessione in
                                    NavigationLink {
                                        VistaDettaglioRapportoGara(
                                            token: token,
                                            sessionId: sessione.id,
                                            referti: referti
                                        )
                                    } label: {
                                        RapportoGaraSessionRowView(sessione: sessione)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            sessioneDaEliminareID = sessione.id
                                        } label: {
                                            Label("Elimina sessione", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
            .compositingGroup()
            .blur(radius: isDeleteSheetPresented ? 8 : 0)
            .scaleEffect(isDeleteSheetPresented ? 0.985 : 1)
            .saturation(isDeleteSheetPresented ? 0.78 : 1)
            .allowsHitTesting(!isDeleteSheetPresented)

            if let sessioneDaEliminare {
                ZStack {
                    Color.black.opacity(0.50)
                    Color(hex: 0x08101F).opacity(0.28)
                }
                .ignoresSafeArea()
                    .onTapGesture {
                        sessioneDaEliminareID = nil
                    }
                .transition(.opacity)
                .zIndex(1)

                RapportoGaraDeleteSessionSheet(
                    titoloGara: sessioneDaEliminare.titoloGara,
                    messaggio: "Vengono rimossi anche gli audio archiviati e i dati locali legati a questa sessione.",
                    onConfirm: {
                        store.eliminaSessione(id: sessioneDaEliminare.id)
                        sessioneDaEliminareID = nil
                    },
                    onCancel: {
                        sessioneDaEliminareID = nil
                    }
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .navigationTitle("Rapporto Gara")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            store.ripulisciCodiceSeScaduto()
        }
        .task(id: firmaRefertiDisponibili) {
            store.aggiornaRefertiDisponibili(referti)
        }
        .task(id: store.codiceVerificaAttivo?.scadeIl) {
            await attendiScadenzaCodiceSeNecessario()
        }
        .animation(.easeInOut(duration: 0.18), value: sessioneDaEliminareID != nil)
    }

    private func attendiScadenzaCodiceSeNecessario() async {
        guard let scadeIl = store.codiceVerificaAttivo?.scadeIl else { return }

        let attesa = max(0, scadeIl.timeIntervalSinceNow)
        if attesa > 0 {
            try? await Task.sleep(nanoseconds: UInt64(attesa * 1_000_000_000))
        }

        guard !Task.isCancelled else { return }
        await MainActor.run {
            store.ripulisciCodiceSeScaduto()
        }
    }
}

@MainActor
private final class RapportoGaraHomeMatchesViewModel: ObservableObject {
    @Published var gare: [GaraHomeDTO] = []
    @Published var inCaricamento = false

    private let apiClient: APIClient

    init(apiClient: APIClient? = nil) {
        self.apiClient = apiClient ?? APIClient.shared
    }

    func carica(token: String) async {
        guard !inCaricamento else { return }
        inCaricamento = true
        defer { inCaricamento = false }

        do {
            let home = try await apiClient.home(token: token)
            gare = Self.gareRilevanti(from: home)
        } catch {
            gare = []
        }
    }

    private static func gareRilevanti(from home: HomePayloadDTO) -> [GaraHomeDTO] {
        var items: [GaraHomeDTO] = []

        if let prossima = home.nextMatch {
            items.append(prossima)
        }
        if let oggi = home.todayMatches, !oggi.isEmpty {
            items.append(contentsOf: oggi)
        }

        var risultati: [GaraHomeDTO] = []
        for gara in items {
            let designazioneId = gara.idDesignazione.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !designazioneId.isEmpty else { continue }
            if risultati.contains(where: { $0.idDesignazione == designazioneId }) {
                continue
            }
            risultati.append(gara)
        }
        return risultati
    }
}

struct RapportoGaraIngressoCardView: View {
    let totaleSessioni: Int
    let totaleOrologi: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 54, height: 54)

                Image(systemName: "applewatch.watchface")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(RapportoGaraPalette.accentSoft)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Rapporto Gara")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Apple Watch, cronometro live ed eventi vocali sincronizzati.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RapportoGaraPalette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    RapportoGaraTagView(label: "Sessioni", value: "\(totaleSessioni)")
                    RapportoGaraTagView(label: "Watch", value: "\(totaleOrologi)")
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.46))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [RapportoGaraPalette.primaryStart, RapportoGaraPalette.primaryEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct RapportoGaraOverviewHeaderView: View {
    let totaleSessioni: Int
    let totaleOrologi: Int
    let watchRaggiungibile: Bool
    let watchAppInstallata: Bool
    let totaleGareDisponibili: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GESTIONE GARA")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(RapportoGaraPalette.accent)
                        .tracking(1.2)

                    Text("Rapporto Gara")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Cronometro live, pairing rapido e archivio sessioni sincronizzate.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RapportoGaraPalette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 46, height: 46)

                    Image(systemName: "applewatch.watchface")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RapportoGaraPalette.accentSoft)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                spacing: 10
            ) {
                RapportoGaraHeaderMetricView(label: "Sessioni", value: "\(totaleSessioni)")
                RapportoGaraHeaderMetricView(label: "Watch", value: "\(totaleOrologi)")
                RapportoGaraHeaderMetricView(label: "Gare", value: "\(totaleGareDisponibili)")
            }

            HStack(spacing: 8) {
                RapportoGaraOverviewStatusChip(
                    titolo: watchRaggiungibile ? "iPhone vicino" : "Offline pronto",
                    icona: watchRaggiungibile ? "dot.radiowaves.left.and.right" : "icloud.and.arrow.down",
                    accent: RapportoGaraPalette.accentSoft
                )

                RapportoGaraOverviewStatusChip(
                    titolo: watchAppInstallata ? "Companion pronta" : "Companion da installare",
                    icona: watchAppInstallata ? "checkmark.seal.fill" : "applewatch.side.right",
                    accent: RapportoGaraPalette.accentSoft
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(RapportoGaraPalette.surfaceStrong)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(RapportoGaraPalette.accent.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct RapportoGaraHeaderMetricView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.50))

            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RapportoGaraPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RapportoGaraPalette.accent.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct RapportoGaraOverviewStatusChip: View {
    let titolo: String
    let icona: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: 30, height: 30)

                Image(systemName: icona)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
            }

            Text(titolo)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RapportoGaraPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(RapportoGaraPalette.accent.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct RapportoGaraControlDeckView: View {
    let codice: CodiceVerificaRapportoGara?
    let watchAppInstallata: Bool
    let hasPairings: Bool
    let watchRaggiungibile: Bool
    let onGenerateCode: () -> Void

    private var titoloBottone: String {
        if codice != nil {
            return "Rigenera codice"
        }
        return hasPairings ? "Autorizza un altro Watch" : "Genera codice di collegamento"
    }

    var body: some View {
        RapportoGaraDashboardPanel(
            titolo: "Collegamento rapido",
            icona: "wave.3.right.circle.fill",
            badge: codice == nil ? "Setup" : "Codice attivo"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let codice {
                    RapportoGaraCodiceCardView(codice: codice)
                } else {
                    RapportoGaraPairingPlaceholderView(
                        watchAppInstallata: watchAppInstallata,
                        hasPairings: hasPairings
                    )
                }

                HStack(spacing: 10) {
                    RapportoGaraInlineInfoCard(
                        titolo: "Companion",
                        valore: watchAppInstallata ? "Installata" : "Da installare",
                        icona: watchAppInstallata ? "checkmark.circle.fill" : "arrow.down.app.fill"
                    )
                    RapportoGaraInlineInfoCard(
                        titolo: "Sync",
                        valore: watchRaggiungibile ? "iPhone vicino" : "Modalita offline",
                        icona: watchRaggiungibile ? "dot.radiowaves.left.and.right" : "icloud.slash"
                    )
                }

                Button(action: onGenerateCode) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(RapportoGaraPalette.inlineSurface)
                                .frame(width: 36, height: 36)

                            Image(systemName: "wave.3.right.circle.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(RapportoGaraPalette.accentSoft)
                        }

                        Text(titoloBottone)
                            .font(.system(size: 15, weight: .bold, design: .rounded))

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.88))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(RapportoGaraPalette.surfaceStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(RapportoGaraPalette.accent.opacity(0.24), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RapportoGaraInlineInfoCard: View {
    let titolo: String
    let valore: String
    let icona: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icona)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(RapportoGaraPalette.accentSoft)

            VStack(alignment: .leading, spacing: 2) {
                Text(titolo.uppercased())
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.46))

                Text(valore)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RapportoGaraPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RapportoGaraPalette.accent.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDashboardPanel<Content: View>: View {
    let titolo: String
    let icona: String
    let badge: String?
    let content: Content

    init(
        titolo: String,
        icona: String,
        badge: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.titolo = titolo
        self.icona = icona
        self.badge = badge
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(RapportoGaraPalette.inlineSurface)
                        .frame(width: 38, height: 38)

                    Image(systemName: icona)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RapportoGaraPalette.accent)
                }

                Text(titolo)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                if let badge, !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(RapportoGaraPalette.inlineSurface)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(RapportoGaraPalette.accent.opacity(0.16), lineWidth: 1)
                        )
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RapportoGaraGlassBackground(cornerRadius: 26, accent: RapportoGaraPalette.accent)
        }
    }
}

private struct RapportoGaraPairingPlaceholderView: View {
    let watchAppInstallata: Bool
    let hasPairings: Bool

    private var titolo: String {
        if !watchAppInstallata {
            return "Companion Watch da installare"
        }
        return hasPairings ? "Nessun codice attivo" : "Nessun Watch collegato"
    }

    private var messaggio: String {
        if !watchAppInstallata {
            return "Installa l'app Apple Watch dall'iPhone e poi autorizza il dispositivo con un codice temporaneo."
        }
        if hasPairings {
            return "Il pairing esiste gia. Genera un codice solo quando devi collegare un altro Apple Watch."
        }
        return "Genera un codice per collegare il primo Apple Watch e iniziare a registrare le sessioni."
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 58, height: 58)

                Image(systemName: watchAppInstallata ? "applewatch.side.right" : "apps.iphone")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(RapportoGaraPalette.accentSoft)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(titolo)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(messaggio)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RapportoGaraPalette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(RapportoGaraPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(RapportoGaraPalette.accent.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDashboardEmptyState: View {
    let icona: String
    let titolo: String
    let messaggio: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 58, height: 58)

                Image(systemName: icona)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(RapportoGaraPalette.accentSoft)
            }

            VStack(spacing: 4) {
                Text(titolo)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(messaggio)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RapportoGaraPalette.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(RapportoGaraPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(RapportoGaraPalette.accent.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct VistaDettaglioRapportoGara: View {
    let token: String
    let sessionId: UUID
    let referti: [RigaModuloDTO]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = RapportoGaraStore.shared
    @StateObject private var audioPlayer = RapportoGaraAudioPlayer()
    @State private var mostraConfermaEliminazione = false
    @State private var eventoInModifica: EventoRapportoGara?
    @State private var coloreMagliaCasa = ""
    @State private var coloreMagliaOspiti = ""
    @State private var sezioneDettaglio: RapportoGaraDettaglioSezione = .live
    @State private var archivioSelezionato: RapportoGaraArchivioSezione = .eventi

    private var sessione: SessioneRapportoGara? {
        store.sessione(per: sessionId)
    }

    private var firmaColoriSessione: String {
        guard let sessione else { return "" }
        return "\(sessione.id.uuidString)|\(sessione.coloreMagliaCasa)|\(sessione.coloreMagliaOspiti)"
    }

    private var coloriMagliaModificati: Bool {
        guard let sessione else { return false }
        return coloreMagliaCasa.trimmingCharacters(in: .whitespacesAndNewlines) != sessione.coloreMagliaCasa
            || coloreMagliaOspiti.trimmingCharacters(in: .whitespacesAndNewlines) != sessione.coloreMagliaOspiti
    }

    var body: some View {
        let isDeleteSheetPresented = mostraConfermaEliminazione && sessione != nil

        ZStack(alignment: .bottom) {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            RapportoGaraAmbientBackgroundView()
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .blur(radius: isDeleteSheetPresented ? 18 : 0)
                .opacity(isDeleteSheetPresented ? 0.55 : 1)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if let sessione {
                        let registrazioni = store.registrazioniAudio(per: sessione.id)
                        let refertoCollegato = referti.first(where: { $0.id == sessione.designazioneId })
                        RapportoGaraDettaglioHeroView(
                            sessione: sessione,
                            watchRaggiungibile: store.watchRaggiungibile
                        )

                        RapportoGaraDettaglioSectionPicker(selection: $sezioneDettaglio)

                        if sezioneDettaglio == .live {
                            RapportoGaraDettaglioLiveSectionView(
                                token: token,
                                sessione: sessione,
                                refertoCollegato: refertoCollegato,
                                watchRaggiungibile: store.watchRaggiungibile,
                                registrazioniCount: registrazioni.count,
                                coloreMagliaCasa: $coloreMagliaCasa,
                                coloreMagliaOspiti: $coloreMagliaOspiti,
                                coloriMagliaModificati: coloriMagliaModificati,
                                onSaveColori: {
                                    store.aggiornaColoriMaglia(
                                        sessionID: sessione.id,
                                        coloreCasa: coloreMagliaCasa,
                                        coloreOspiti: coloreMagliaOspiti
                                    )
                                }
                            )
                        } else if sezioneDettaglio == .distinte {
                            RapportoGaraDettaglioDistinteSectionView(sessione: sessione)
                        } else {
                            RapportoGaraDettaglioArchivioSectionView(
                                sessione: sessione,
                                registrazioni: registrazioni,
                                archivioSelezionato: $archivioSelezionato,
                                audioInRiproduzioneID: audioPlayer.audioInRiproduzioneID,
                                onEventoTap: { evento in
                                    eventoInModifica = evento
                                },
                                onPlayAudio: { registrazione in
                                    audioPlayer.togglePlayback(
                                        registrazione: registrazione,
                                        store: store
                                    )
                                },
                                onDeleteAudio: { registrazione in
                                    if audioPlayer.audioInRiproduzioneID == registrazione.id {
                                        audioPlayer.stop()
                                    }
                                    store.eliminaRegistrazioneAudio(id: registrazione.id)
                                }
                            )
                        }
                    } else {
                        StatoVuotoView(
                            titolo: "Sessione non disponibile",
                            messaggio: "Non riesco a trovare questa sessione di rapporto gara."
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 110)
            }
            .compositingGroup()
            .blur(radius: isDeleteSheetPresented ? 8 : 0)
            .scaleEffect(isDeleteSheetPresented ? 0.985 : 1)
            .saturation(isDeleteSheetPresented ? 0.78 : 1)
            .allowsHitTesting(!isDeleteSheetPresented)

            if mostraConfermaEliminazione, let sessione {
                ZStack {
                    Color.black.opacity(0.50)
                    Color(hex: 0x08101F).opacity(0.28)
                }
                .ignoresSafeArea()
                    .onTapGesture {
                        mostraConfermaEliminazione = false
                    }
                .transition(.opacity)
                .zIndex(1)

                RapportoGaraDeleteSessionSheet(
                    titoloGara: sessione.titoloGara,
                    messaggio: "Vengono eliminati anche audio originali, file locali e cache collegati a questa sessione.",
                    onConfirm: {
                        audioPlayer.stop()
                        store.eliminaSessione(id: sessione.id)
                        mostraConfermaEliminazione = false
                        dismiss()
                    },
                    onCancel: {
                        mostraConfermaEliminazione = false
                    }
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .navigationTitle("Dettaglio Sessione")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if sessione != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        mostraConfermaEliminazione = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(RapportoGaraPalette.accentSoft)
                }
            }
        }
        .onDisappear {
            audioPlayer.stop()
        }
        .task {
            sincronizzaCampiColori()
        }
        .onChange(of: firmaColoriSessione) {
            sincronizzaCampiColori()
        }
        .animation(.easeInOut(duration: 0.18), value: mostraConfermaEliminazione)
        .sheet(item: $eventoInModifica) { evento in
            NavigationStack {
                RapportoGaraEventoEditorView(
                    sessione: sessione,
                    evento: evento,
                    onSave: { eventoAggiornato in
                        store.aggiornaEvento(sessionID: sessionId, eventoAggiornato: eventoAggiornato)
                    },
                    onDelete: {
                        store.eliminaEvento(sessionID: sessionId, eventID: evento.id)
                    }
                )
            }
            .sinfoniaNavigationRoot()
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func sincronizzaCampiColori() {
        guard let sessione else { return }
        coloreMagliaCasa = sessione.coloreMagliaCasa
        coloreMagliaOspiti = sessione.coloreMagliaOspiti
    }
}

private enum RapportoGaraDettaglioSezione: String, CaseIterable, Identifiable {
    case live
    case distinte
    case archivio

    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .live:
            return "Live"
        case .distinte:
            return "Distinte"
        case .archivio:
            return "Archivio"
        }
    }

    var icona: String {
        switch self {
        case .live:
            return "dot.radiowaves.left.and.right"
        case .distinte:
            return "doc.text.viewfinder"
        case .archivio:
            return "tray.full"
        }
    }
}

private enum RapportoGaraArchivioSezione: String, CaseIterable, Identifiable {
    case eventi
    case audio

    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .eventi:
            return "Eventi"
        case .audio:
            return "Audio"
        }
    }

    var icona: String {
        switch self {
        case .eventi:
            return "list.bullet.rectangle.portrait"
        case .audio:
            return "waveform"
        }
    }
}

private struct RapportoGaraDettaglioSectionPicker: View {
    @Binding var selection: RapportoGaraDettaglioSezione

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RapportoGaraDettaglioSezione.allCases) { sezione in
                Button {
                    selection = sezione
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: sezione.icona)
                            .font(.system(size: 12, weight: .bold))
                        Text(sezione.titolo)
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selection == sezione ? RapportoGaraPalette.inlineSurface : Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(selection == sezione ? RapportoGaraPalette.accent.opacity(0.24) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RapportoGaraDettaglioLiveSectionView: View {
    let token: String
    let sessione: SessioneRapportoGara
    let refertoCollegato: RigaModuloDTO?
    let watchRaggiungibile: Bool
    let registrazioniCount: Int
    @Binding var coloreMagliaCasa: String
    @Binding var coloreMagliaOspiti: String
    let coloriMagliaModificati: Bool
    let onSaveColori: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RapportoGaraSectionCard(
                titolo: "Sessione live",
                sottotitolo: "Le informazioni fondamentali sono in primo piano."
            ) {
                RapportoGaraDettaglioSyncStripView(
                    watchRaggiungibile: watchRaggiungibile,
                    statoCronometro: sessione.statoCronometro
                )

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    RapportoGaraDettaglioQuickStatCard(
                        titolo: "Watch",
                        valore: watchRaggiungibile ? "Vicino" : "In attesa",
                        icona: "applewatch.side.right"
                    )
                    RapportoGaraDettaglioQuickStatCard(
                        titolo: "Cronometro",
                        valore: sessione.statoCronometro.titolo,
                        icona: "timer"
                    )
                    RapportoGaraDettaglioQuickStatCard(
                        titolo: "Eventi",
                        valore: "\(sessione.eventi.count)",
                        icona: "list.bullet.rectangle.portrait"
                    )
                    RapportoGaraDettaglioQuickStatCard(
                        titolo: "Audio",
                        valore: "\(registrazioniCount)",
                        icona: "waveform"
                    )
                }

                if let row = refertoCollegato {
                    NavigationLink {
                        VistaDettaglioReferto(token: token, designazioneId: row.id, titolo: row.title)
                    } label: {
                        RapportoGaraDettaglioPrimaryLinkView(
                            titolo: "Apri referto collegato",
                            icona: "square.and.pencil"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            RapportoGaraSectionCard(
                titolo: "Colori maglia",
                sottotitolo: "Configurazione rapida per il riconoscimento vocale."
            ) {
                RapportoGaraDettaglioColorHintsView(
                    coloreCasa: sessione.coloreMagliaCasa,
                    coloreOspiti: sessione.coloreMagliaOspiti
                )

                VStack(spacing: 12) {
                    RapportoGaraDettaglioColorField(
                        titolo: "Squadra di casa",
                        placeholder: "Es. blu",
                        icon: "house.fill",
                        text: $coloreMagliaCasa
                    )
                    RapportoGaraDettaglioColorField(
                        titolo: "Squadra ospite",
                        placeholder: "Es. bianco",
                        icon: "airplane",
                        text: $coloreMagliaOspiti
                    )
                }

                Button(action: onSaveColori) {
                    HStack(spacing: 10) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(coloriMagliaModificati ? "Salva colori maglia" : "Colori aggiornati")
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [RapportoGaraPalette.primaryStart, RapportoGaraPalette.primaryEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!coloriMagliaModificati)
                .opacity(coloriMagliaModificati ? 1 : 0.72)
            }
        }
    }
}

private struct RapportoGaraDettaglioDistinteSectionView: View {
    let sessione: SessioneRapportoGara

    var body: some View {
        RapportoGaraSectionCard(
            titolo: "Distinte",
            sottotitolo: "Controlla OCR, documenti, staff e titolari in una sezione dedicata."
        ) {
            RapportoGaraDistinteSectionView(sessione: sessione)
        }
    }
}

private struct RapportoGaraDettaglioArchivioSectionView: View {
    let sessione: SessioneRapportoGara
    let registrazioni: [RegistrazioneAudioRapportoGara]
    @Binding var archivioSelezionato: RapportoGaraArchivioSezione
    let audioInRiproduzioneID: UUID?
    let onEventoTap: (EventoRapportoGara) -> Void
    let onPlayAudio: (RegistrazioneAudioRapportoGara) -> Void
    let onDeleteAudio: (RegistrazioneAudioRapportoGara) -> Void

    var body: some View {
        RapportoGaraSectionCard(
            titolo: "Archivio sessione",
            sottotitolo: archivioSelezionato == .eventi
                ? "Eventi sincronizzati e modificabili."
                : "Audio originali disponibili sul telefono."
        ) {
            RapportoGaraArchivioPickerView(selection: $archivioSelezionato)

            if archivioSelezionato == .eventi {
                if sessione.eventiOrdinati.isEmpty {
                    StatoVuotoView(
                        titolo: "Nessun evento registrato",
                        messaggio: "La sessione e stata sincronizzata, ma non contiene ancora eventi vocali dal Watch."
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(sessione.eventiOrdinati) { evento in
                            RapportoGaraEventoTimelineRowView(evento: evento)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onEventoTap(evento)
                                }
                        }
                    }
                }
            } else {
                if registrazioni.isEmpty {
                    StatoVuotoView(
                        titolo: "Nessun audio archiviato",
                        messaggio: "Quando il Watch invia una dettatura al telefono, qui trovi il clip originale da riascoltare o rimuovere."
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(registrazioni) { registrazione in
                            RapportoGaraAudioRowView(
                                registrazione: registrazione,
                                inRiproduzione: audioInRiproduzioneID == registrazione.id,
                                onPlay: {
                                    onPlayAudio(registrazione)
                                },
                                onDelete: {
                                    onDeleteAudio(registrazione)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct RapportoGaraDettaglioQuickStatCard: View {
    let titolo: String
    let valore: String
    let icona: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icona)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(RapportoGaraPalette.accentSoft)

                Text(titolo.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.52))
            }

            Text(valore)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RapportoGaraPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RapportoGaraPalette.accent.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct RapportoGaraArchivioPickerView: View {
    @Binding var selection: RapportoGaraArchivioSezione

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RapportoGaraArchivioSezione.allCases) { sezione in
                Button {
                    selection = sezione
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: sezione.icona)
                            .font(.system(size: 12, weight: .bold))
                        Text(sezione.titolo)
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selection == sezione ? RapportoGaraPalette.inlineSurface : Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(selection == sezione ? RapportoGaraPalette.accent.opacity(0.24) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RapportoGaraSyncBannerView: View {
    let message: String

    private var accent: Color {
        let lowercased = message.lowercased()
        if lowercased.contains("erro") || lowercased.contains("non") {
            return Color(hex: 0x6D9AD3)
        }
        return Color(hex: 0xB7DEFF)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .frame(width: 42, height: 42)

                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
            }

            Text(message)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RapportoGaraGlassBackground(cornerRadius: 22, accent: accent)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accent.opacity(0.90))
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 8)
        }
    }
}

private struct RapportoGaraDeleteSessionSheet: View {
    let titoloGara: String
    let messaggio: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var titoloSecondario: String? {
        let valore = titoloGara.trimmingCharacters(in: .whitespacesAndNewlines)
        return valore.isEmpty ? nil : valore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            dragHandle
            header
            messageView
            actions
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(RapportoGaraPalette.surfaceStrong)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(RapportoGaraPalette.accent.opacity(0.24), lineWidth: 1)
        )
    }

    private var dragHandle: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.18))
            .frame(width: 42, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(RapportoGaraPalette.inlineSurface)
                    .frame(width: 46, height: 46)

                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(RapportoGaraPalette.accentSoft)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Eliminare questa sessione?")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let titoloSecondario {
                    Text(titoloSecondario)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.70))
                        .lineLimit(2)
                }
            }
        }
    }

    private var messageView: some View {
        Text(messaggio)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.74))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            secondaryActionButton(title: "Annulla", action: onCancel)
            primaryActionButton(title: "Elimina sessione", action: onConfirm)
        }
    }

    private func secondaryActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(RapportoGaraPalette.inlineSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func primaryActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(RapportoGaraPalette.inlineSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(RapportoGaraPalette.accent.opacity(0.24), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private enum RapportoGaraEventoEditorPeriodo: String, CaseIterable, Identifiable {
    case prepartita
    case primoTempo
    case intervallo
    case secondoTempo
    case finale

    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .prepartita:
            return "Pre"
        case .primoTempo:
            return "1T"
        case .intervallo:
            return "HT"
        case .secondoTempo:
            return "2T"
        case .finale:
            return "FT"
        }
    }
}

private struct RapportoGaraEventoEditorDraft: Identifiable {
    let id: UUID
    let creatoIl: Date
    let testoOriginale: String

    var tipoEvento: TipoEventoRapportoGara
    var periodo: RapportoGaraEventoEditorPeriodo
    var minuto: String
    var recupero: String
    var latoSquadra: LatoSquadraRapportoGara?
    var numeroMaglia: String
    var numeroMagliaEntrata: String
    var note: String

    init(evento: EventoRapportoGara) {
        id = evento.id
        creatoIl = evento.creatoIl
        testoOriginale = evento.testoDettato
        tipoEvento = evento.tipoEvento
        latoSquadra = evento.latoSquadra
        numeroMaglia = evento.numeroMaglia.map(String.init) ?? ""
        numeroMagliaEntrata = evento.numeroMagliaEntrata.map(String.init) ?? ""
        note = evento.tipoEvento == .notaLibera
            ? evento.testoDettato
            : (evento.motivazione ?? "")

        let snapshot = evento.minuto
        switch snapshot.labelPeriodo {
        case "Pre":
            periodo = .prepartita
            minuto = ""
            recupero = ""
        case "HT":
            periodo = .intervallo
            minuto = ""
            recupero = ""
        case "FT":
            periodo = .finale
            minuto = ""
            recupero = ""
        case "2T":
            periodo = .secondoTempo
            if let recuperoSnapshot = snapshot.recupero {
                minuto = "45"
                recupero = "\(recuperoSnapshot)"
            } else {
                minuto = "\(max(1, snapshot.minuto - 45))"
                recupero = ""
            }
        default:
            periodo = .primoTempo
            if let recuperoSnapshot = snapshot.recupero {
                minuto = "45"
                recupero = "\(recuperoSnapshot)"
            } else {
                minuto = "\(max(1, snapshot.minuto))"
                recupero = ""
            }
        }
    }

    var richiedeMinutoManuale: Bool {
        periodo == .primoTempo || periodo == .secondoTempo
    }

    var mostraLatoSquadra: Bool {
        tipoEvento != .notaLibera
    }

    var mostraNumeroMaglia: Bool {
        tipoEvento != .notaLibera
    }

    var mostraNumeroEntrata: Bool {
        tipoEvento == .sostituzione
    }

    var snapshotValido: MinutoRapportoGaraSnapshot? {
        switch periodo {
        case .prepartita:
            return MinutoRapportoGaraSnapshot(
                minuto: 0,
                recupero: nil,
                labelMinuto: "0'",
                labelPeriodo: "Pre",
                secondiCronometro: 0
            )
        case .intervallo:
            return MinutoRapportoGaraSnapshot(
                minuto: 45,
                recupero: nil,
                labelMinuto: "Intervallo",
                labelPeriodo: "HT",
                secondiCronometro: 45 * 60
            )
        case .finale:
            return MinutoRapportoGaraSnapshot(
                minuto: 90,
                recupero: nil,
                labelMinuto: "FT",
                labelPeriodo: "FT",
                secondiCronometro: 90 * 60
            )
        case .primoTempo:
            guard let minutoBase = Self.clampedPositiveInt(from: minuto, min: 1, max: 45) else { return nil }
            let recuperoValue = Self.clampedOptionalInt(from: recupero, min: 1, max: 30)
            if let recuperoValue {
                return MinutoRapportoGaraSnapshot(
                    minuto: 45,
                    recupero: recuperoValue,
                    labelMinuto: "45+\(recuperoValue)'",
                    labelPeriodo: "1T",
                    secondiCronometro: (45 * 60) + ((recuperoValue - 1) * 60)
                )
            }
            return MinutoRapportoGaraSnapshot(
                minuto: minutoBase,
                recupero: nil,
                labelMinuto: "\(minutoBase)'",
                labelPeriodo: "1T",
                secondiCronometro: (minutoBase - 1) * 60
            )
        case .secondoTempo:
            guard let minutoBase = Self.clampedPositiveInt(from: minuto, min: 1, max: 45) else { return nil }
            let recuperoValue = Self.clampedOptionalInt(from: recupero, min: 1, max: 30)
            if let recuperoValue {
                return MinutoRapportoGaraSnapshot(
                    minuto: 90,
                    recupero: recuperoValue,
                    labelMinuto: "90+\(recuperoValue)'",
                    labelPeriodo: "2T",
                    secondiCronometro: (90 * 60) + ((recuperoValue - 1) * 60)
                )
            }
            let minutoGlobale = minutoBase + 45
            return MinutoRapportoGaraSnapshot(
                minuto: minutoGlobale,
                recupero: nil,
                labelMinuto: "\(minutoGlobale)'",
                labelPeriodo: "2T",
                secondiCronometro: (45 * 60) + ((minutoBase - 1) * 60)
            )
        }
    }

    func buildEvento() -> EventoRapportoGara? {
        guard let snapshot = snapshotValido else { return nil }

        let notePulite = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let numeroPrincipale = Self.clampedOptionalInt(from: numeroMaglia, min: 1, max: 99)
        let numeroEntrata = Self.clampedOptionalInt(from: numeroMagliaEntrata, min: 1, max: 99)

        return EventoRapportoGara(
            id: id,
            minuto: snapshot,
            latoSquadra: mostraLatoSquadra ? latoSquadra : nil,
            numeroMaglia: mostraNumeroMaglia ? numeroPrincipale : nil,
            numeroMagliaEntrata: mostraNumeroEntrata ? numeroEntrata : nil,
            tipoEvento: tipoEvento,
            motivazione: tipoEvento == .notaLibera || notePulite.isEmpty ? nil : notePulite,
            testoDettato: testoSintetico(notePulite: notePulite, numeroPrincipale: numeroPrincipale, numeroEntrata: numeroEntrata),
            origine: .inserimentoManuale,
            creatoIl: creatoIl
        )
    }

    private func testoSintetico(
        notePulite: String,
        numeroPrincipale: Int?,
        numeroEntrata: Int?
    ) -> String {
        if tipoEvento == .notaLibera {
            return notePulite.isEmpty ? testoOriginale.trimmingCharacters(in: .whitespacesAndNewlines) : notePulite
        }

        var parti: [String] = [tipoEvento.titolo]

        if let latoSquadra {
            parti.append(latoSquadra.titolo)
        }

        if tipoEvento == .sostituzione {
            if let numeroPrincipale {
                parti.append("esce #\(numeroPrincipale)")
            }
            if let numeroEntrata {
                parti.append("entra #\(numeroEntrata)")
            }
        } else if let numeroPrincipale {
            parti.append("#\(numeroPrincipale)")
        }

        if !notePulite.isEmpty {
            parti.append(notePulite)
        }

        return parti.joined(separator: " · ")
    }

    private static func clampedPositiveInt(from rawValue: String, min lowerBound: Int, max upperBound: Int) -> Int? {
        guard let value = Int(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return Swift.max(lowerBound, Swift.min(upperBound, value))
    }

    private static func clampedOptionalInt(from rawValue: String, min lowerBound: Int, max upperBound: Int) -> Int? {
        let pulito = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pulito.isEmpty else { return nil }
        return clampedPositiveInt(from: pulito, min: lowerBound, max: upperBound)
    }
}

private struct RapportoGaraEventoEditorView: View {
    let sessione: SessioneRapportoGara?
    let onSave: (EventoRapportoGara) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: RapportoGaraEventoEditorDraft
    @State private var mostraConfermaEliminazione = false

    init(
        sessione: SessioneRapportoGara?,
        evento: EventoRapportoGara,
        onSave: @escaping (EventoRapportoGara) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.sessione = sessione
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: RapportoGaraEventoEditorDraft(evento: evento))
    }

    private var puoSalvare: Bool {
        draft.buildEvento() != nil
    }

    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            RapportoGaraAmbientBackgroundView()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    RapportoGaraSectionCard(
                        titolo: "Evento gara",
                        sottotitolo: "Correggi il dato strutturato e salva la versione giusta del tuo rapporto."
                    ) {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(TipoEventoRapportoGara.allCases) { tipo in
                                RapportoGaraSelectableOptionCard(
                                    titolo: tipo.titolo,
                                    icona: tipo.iconaSistema,
                                    selezionata: draft.tipoEvento == tipo
                                ) {
                                    draft.tipoEvento = tipo
                                }
                            }
                        }
                    }

                    RapportoGaraSectionCard(
                        titolo: "Tempo di gioco",
                        sottotitolo: "Imposta periodo e minuto corretto dell'evento."
                    ) {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(RapportoGaraEventoEditorPeriodo.allCases) { periodo in
                                RapportoGaraSelectableOptionCard(
                                    titolo: periodo.titolo,
                                    icona: "clock",
                                    selezionata: draft.periodo == periodo
                                ) {
                                    draft.periodo = periodo
                                }
                            }
                        }

                        if draft.richiedeMinutoManuale {
                            HStack(spacing: 12) {
                                RapportoGaraDettaglioColorField(
                                    titolo: "Minuto",
                                    placeholder: "Es. 17",
                                    icon: "timer",
                                    text: $draft.minuto
                                )
                                RapportoGaraDettaglioColorField(
                                    titolo: "Recupero",
                                    placeholder: "Facoltativo",
                                    icon: "plus.circle.fill",
                                    text: $draft.recupero
                                )
                            }
                        }
                    }

                    RapportoGaraSectionCard(
                        titolo: "Dettaglio evento",
                        sottotitolo: "Squadra, numeri di maglia e note correttive."
                    ) {
                        if draft.mostraLatoSquadra {
                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                                spacing: 10
                            ) {
                                RapportoGaraSelectableOptionCard(
                                    titolo: "Nessuna",
                                    icona: "minus",
                                    selezionata: draft.latoSquadra == nil
                                ) {
                                    draft.latoSquadra = nil
                                }
                                RapportoGaraSelectableOptionCard(
                                    titolo: labelLato(.casa),
                                    icona: "house.fill",
                                    selezionata: draft.latoSquadra == .casa
                                ) {
                                    draft.latoSquadra = .casa
                                }
                                RapportoGaraSelectableOptionCard(
                                    titolo: labelLato(.ospiti),
                                    icona: "airplane",
                                    selezionata: draft.latoSquadra == .ospiti
                                ) {
                                    draft.latoSquadra = .ospiti
                                }
                            }
                        }

                        if draft.mostraNumeroMaglia {
                            VStack(spacing: 12) {
                                RapportoGaraDettaglioColorField(
                                    titolo: draft.mostraNumeroEntrata ? "Numero uscita" : "Numero maglia",
                                    placeholder: "Es. 8",
                                    icon: draft.mostraNumeroEntrata ? "arrow.left.circle.fill" : "number.circle.fill",
                                    text: $draft.numeroMaglia
                                )

                                if draft.mostraNumeroEntrata {
                                    RapportoGaraDettaglioColorField(
                                        titolo: "Numero entrata",
                                        placeholder: "Es. 18",
                                        icon: "arrow.right.circle.fill",
                                        text: $draft.numeroMagliaEntrata
                                    )
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(draft.tipoEvento == .notaLibera ? "Testo evento" : "Note / motivazione")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.76))

                            TextEditor(text: $draft.note)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 118)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(RapportoGaraPalette.inlineSurface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                                .foregroundColor(.white)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                    }

                    Button(role: .destructive) {
                        mostraConfermaEliminazione = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .bold))
                            Text("Elimina evento")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(RapportoGaraPalette.inlineSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Modifica evento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Chiudi") {
                    dismiss()
                }
                .foregroundStyle(.white)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Salva") {
                    guard let eventoAggiornato = draft.buildEvento() else { return }
                    onSave(eventoAggiornato)
                    dismiss()
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .disabled(!puoSalvare)
                .opacity(puoSalvare ? 1 : 0.45)
            }
        }
        .confirmationDialog(
            "Eliminare questo evento?",
            isPresented: $mostraConfermaEliminazione,
            titleVisibility: .visible
        ) {
            Button("Elimina evento", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("L'evento verra rimosso dalla sessione e dal rapporto locale.")
        }
    }

    private func labelLato(_ lato: LatoSquadraRapportoGara) -> String {
        guard let sessione else { return lato.titolo }

        switch lato {
        case .casa:
            let colore = sessione.coloreMagliaCasa.trimmingCharacters(in: .whitespacesAndNewlines)
            return colore.isEmpty ? "Casa" : "Casa · \(colore)"
        case .ospiti:
            let colore = sessione.coloreMagliaOspiti.trimmingCharacters(in: .whitespacesAndNewlines)
            return colore.isEmpty ? "Ospiti" : "Ospiti · \(colore)"
        }
    }
}

private struct RapportoGaraSelectableOptionCard: View {
    let titolo: String
    let icona: String
    let selezionata: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icona)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(selezionata ? .white : RapportoGaraPalette.accentSoft)

                Text(titolo)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selezionata ? RapportoGaraPalette.primaryStart.opacity(0.42) : RapportoGaraPalette.inlineSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selezionata ? RapportoGaraPalette.accent.opacity(0.55) : Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RapportoGaraDettaglioSyncStripView: View {
    let watchRaggiungibile: Bool
    let statoCronometro: StatoCronometroRapportoGara

    var body: some View {
        HStack(spacing: 10) {
            RapportoGaraTagView(
                label: "Watch",
                value: watchRaggiungibile ? "Vicino" : "Lontano"
            )
            RapportoGaraTagView(
                label: "Cronometro",
                value: watchRaggiungibile && statoCronometro.isInCorso ? "Live" : statoCronometro.titolo
            )
        }
    }
}

private struct RapportoGaraDettaglioPrimaryLinkView: View {
    let titolo: String
    let icona: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icona)
                .font(.system(size: 15, weight: .bold))

            Text(titolo)
                .font(.system(size: 15, weight: .bold, design: .rounded))

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [RapportoGaraPalette.primaryStart, RapportoGaraPalette.primaryEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDettaglioColorHintsView: View {
    let coloreCasa: String
    let coloreOspiti: String

    var body: some View {
        HStack(spacing: 10) {
            hintCard(
                titolo: "Casa",
                valore: coloreCasa.isEmpty ? "Non impostato" : coloreCasa,
                accent: RapportoGaraPalette.accentSoft
            )
            hintCard(
                titolo: "Ospiti",
                valore: coloreOspiti.isEmpty ? "Non impostato" : coloreOspiti,
                accent: RapportoGaraPalette.accent
            )
        }
    }

    private func hintCard(titolo: String, valore: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(titolo.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.48))

            Text(valore)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RapportoGaraGlassBackground(cornerRadius: 18, accent: accent)
        }
    }
}

private struct RapportoGaraDettaglioColorField: View {
    let titolo: String
    let placeholder: String
    let icon: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(RapportoGaraPalette.accentSoft)

                Text(titolo)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.76))
            }

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(RapportoGaraPalette.inlineSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
    }
}

private struct RapportoGaraPanoramicaCardView: View {
    let totaleSessioni: Int
    let totaleOrologi: Int
    let watchRaggiungibile: Bool
    let watchAppInstallata: Bool

    var body: some View {
        RapportoGaraSectionCard(
            titolo: "Panoramica",
            sottotitolo: ""
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                RapportoGaraTagMetricView(label: "Sessioni", value: "\(totaleSessioni)", icon: "tray.full.fill")
                RapportoGaraTagMetricView(label: "Watch", value: "\(totaleOrologi)", icon: "applewatch")
                RapportoGaraTagMetricView(label: "App Watch", value: watchAppInstallata ? "Pronta" : "Assente", icon: "apps.iphone")
                RapportoGaraTagMetricView(label: "Stato", value: watchRaggiungibile ? "Vicino" : "Offline", icon: "dot.radiowaves.left.and.right")
            }
        }
    }
}

private struct RapportoGaraDettaglioHeroView: View {
    let sessione: SessioneRapportoGara
    let watchRaggiungibile: Bool

    var body: some View {
        RapportoGaraSectionCard(
            titolo: sessione.titoloGara.isEmpty ? "Sessione gara" : sessione.titoloGara,
            sottotitolo: sessione.ruoloLabel
        ) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sessione.dataGara.isEmpty ? "Data gara non disponibile" : sessione.dataGara)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.82))

                        if let sincronizzataIl = sessione.sincronizzataIl {
                            Text("Ultimo sync \(Self.syncFormatter.string(from: sincronizzataIl))")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.58))
                        }
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        RapportoGaraStatusBadge(title: sessione.statoCronometro.titolo)
                        RapportoGaraTagView(
                            label: watchRaggiungibile ? "Watch" : "Sync",
                            value: watchRaggiungibile ? "Vicino" : "In attesa"
                        )
                    }
                }

                RapportoGaraDettaglioLiveMetricsView(
                    sessione: sessione,
                    watchRaggiungibile: watchRaggiungibile
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        RapportoGaraSessionMetaPill(icon: "applewatch.side.right", title: "Watch", value: sessione.nomeOrologio.isEmpty ? "Sconosciuto" : sessione.nomeOrologio)
                        RapportoGaraSessionMetaPill(icon: "list.bullet.rectangle.portrait", title: "Eventi", value: "\(sessione.eventi.count)")
                        RapportoGaraSessionMetaPill(icon: "clock.badge.checkmark", title: "Avvio", value: Self.timeFormatter.string(from: sessione.avviataIl))
                    }
                }
            }
        }
    }

    private static let syncFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct RapportoGaraDettaglioLiveMetricsView: View {
    let sessione: SessioneRapportoGara
    let watchRaggiungibile: Bool

    var body: some View {
        TimelineView(.periodic(
            from: .now,
            by: watchRaggiungibile && sessione.statoCronometro.isInCorso ? (1.0 / 20.0) : 1.0
        )) { context in
            let sessioneRenderizzata = watchRaggiungibile ? sessione.renderizzataLive(alla: context.date) : sessione
            let snapshot = CalcolatoreCronometroRapportoGara.snapshot(per: sessioneRenderizzata)
            let display = watchRaggiungibile
                ? sessione.cronometroDisplayLive(alla: context.date)
                : cronometroSincronizzato(sessioneRenderizzata)

            VStack(alignment: .leading, spacing: 18) {
                RapportoGaraLiveClockCardView(
                    display: display,
                    snapshot: snapshot,
                    stato: sessioneRenderizzata.statoCronometro,
                    sincronizzataIl: sessione.sincronizzataIl,
                    watchRaggiungibile: watchRaggiungibile
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    RapportoGaraCompactMetricView(
                        label: "1T",
                        value: formattaSecondi(sessioneRenderizzata.secondiPrimoTempo),
                        accent: RapportoGaraPalette.accentSoft,
                        isLive: watchRaggiungibile
                            && (sessioneRenderizzata.statoCronometro == .primoTempo
                                || sessioneRenderizzata.statoCronometro == .recuperoPrimoTempo)
                    )
                    RapportoGaraCompactMetricView(
                        label: "2T",
                        value: formattaSecondi(sessioneRenderizzata.secondiSecondoTempo),
                        accent: RapportoGaraPalette.accent,
                        isLive: watchRaggiungibile
                            && (sessioneRenderizzata.statoCronometro == .secondoTempo
                                || sessioneRenderizzata.statoCronometro == .recuperoSecondoTempo)
                    )

                    if let recupero1T = sessioneRenderizzata.minutiRecuperoPrimoTempo {
                        RapportoGaraCompactMetricView(
                            label: "Rec 1T",
                            value: "\(recupero1T)'",
                            accent: RapportoGaraPalette.accentSoft
                        )
                    }

                    if let recupero2T = sessioneRenderizzata.minutiRecuperoSecondoTempo {
                        RapportoGaraCompactMetricView(
                            label: "Rec 2T",
                            value: "\(recupero2T)'",
                            accent: RapportoGaraPalette.accent
                        )
                    }
                }
            }
        }
    }

    private func cronometroSincronizzato(_ sessione: SessioneRapportoGara) -> CronometroDisplayLiveRapportoGara {
        let secondiAttivi: Int
        switch sessione.statoCronometro {
        case .prepartita:
            secondiAttivi = 0
        case .primoTempo, .recuperoPrimoTempo, .intervallo:
            secondiAttivi = sessione.secondiPrimoTempo
        case .secondoTempo, .recuperoSecondoTempo, .finale:
            secondiAttivi = sessione.secondiSecondoTempo
        }

        return CronometroDisplayLiveRapportoGara(
            principale: formattaSecondi(secondiAttivi),
            decimi: nil
        )
    }

    private func formattaSecondi(_ total: Int) -> String {
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct RapportoGaraCodiceCardView: View {
    let codice: CodiceVerificaRapportoGara

    private var codiceFormattato: String {
        let raw = codice.codice
        guard raw.count == 6 else { return raw }
        let first = raw.prefix(3)
        let last = raw.suffix(3)
        return "\(first) \(last)"
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("CODICE ATTIVO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.52))
                            .tracking(1)

                        Text(codiceFormattato)
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text("Usalo sul Watch per completare il collegamento.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RapportoGaraPalette.textMuted)
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(RapportoGaraPalette.inlineSurface)
                            .frame(width: 46, height: 46)

                        Image(systemName: "number.circle.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(RapportoGaraPalette.accentSoft)
                    }
                }

                HStack(spacing: 10) {
                    RapportoGaraInlineInfoCard(
                        titolo: "Tempo residuo",
                        valore: codice.labelTempoResiduo(at: context.date),
                        icona: "timer"
                    )
                    RapportoGaraInlineInfoCard(
                        titolo: "Scadenza",
                        valore: Self.timeFormatter.string(from: codice.scadeIl),
                        icona: "clock.badge.checkmark"
                    )
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(RapportoGaraPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(RapportoGaraPalette.accent.opacity(0.24), lineWidth: 1)
            )
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct RapportoGaraWatchPairRowView: View {
    let pairing: AppleWatchAbbinatoRapportoGara

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(RapportoGaraPalette.inlineSurface)
                    .frame(width: 46, height: 46)

                Image(systemName: "applewatch.side.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(RapportoGaraPalette.accentSoft)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(pairing.watchName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(pairing.ultimoSyncIl.map { "Ultimo sync \(Self.dateFormatter.string(from: $0))" } ?? "Mai sincronizzato")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(RapportoGaraPalette.textMuted)
            }

            Spacer(minLength: 0)

            Text("Pronto")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(RapportoGaraPalette.inlineSurface)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(RapportoGaraPalette.accent.opacity(0.16), lineWidth: 1)
                )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RapportoGaraPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(RapportoGaraPalette.accent.opacity(0.16), lineWidth: 1)
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct RapportoGaraSessionRowView: View {
    let sessione: SessioneRapportoGara

    private var accent: Color {
        switch sessione.statoCronometro {
        case .primoTempo, .secondoTempo, .recuperoPrimoTempo, .recuperoSecondoTempo:
            return Color(hex: 0xB7DEFF)
        case .prepartita, .intervallo, .finale:
            return Color(hex: 0x6D9AD3)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(accent)
                .frame(width: 6)
                .padding(.vertical, 12)
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sessione.titoloGara.isEmpty ? "Sessione gara" : sessione.titoloGara)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(sessione.ruoloLabel.isEmpty ? sessione.dataGara : "\(sessione.ruoloLabel) · \(sessione.dataGara)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Text(sessione.statoCronometro.titolo)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accent.opacity(0.18))
                        )
                }

                HStack(spacing: 8) {
                    RapportoGaraSessionDataPill(label: "Eventi", value: "\(sessione.eventi.count)")
                    RapportoGaraSessionDataPill(label: "Watch", value: sessione.nomeOrologio.isEmpty ? "Watch" : sessione.nomeOrologio)
                    RapportoGaraSessionDataPill(label: "Sync", value: sessione.sincronizzataIl.map { Self.timeFormatter.string(from: $0) } ?? "--:--")
                }

                HStack {
                    Text("Apri sessione")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accent)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accent)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(RapportoGaraPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accent.opacity(0.24), lineWidth: 1)
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct RapportoGaraSessionDataPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.46))

            Text(value)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(RapportoGaraPalette.inlineSurface)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(RapportoGaraPalette.accent.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct RapportoGaraEventoTimelineRowView: View {
    let evento: EventoRapportoGara

    private var coloreAccento: Color {
        switch evento.tipoEvento {
        case .ammonizione:
            return Color(hex: 0xFFD15B)
        case .espulsione:
            return Color(hex: 0xFF7676)
        case .doppioGialloRosso:
            return Color(hex: 0xFFA15A)
        case .gol:
            return Color(hex: 0x9BC7FF)
        case .sostituzione:
            return Color(hex: 0x84B8FF)
        case .notaLibera:
            return Color(hex: 0x9BC7FF)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(minutoCardLabel)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(periodoCardLabel)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
            }
            .frame(width: 78, alignment: .leading)

            RapportoGaraEventCardIcons(tipoEvento: evento.tipoEvento)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(descrizioneEvento)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                let dettaglio = dettaglioEvento
                if !dettaglio.isEmpty {
                    Text(dettaglio)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.88))
                }

                if evento.tipoEvento == .sostituzione,
                   evento.numeroMaglia != nil || evento.numeroMagliaEntrata != nil {
                    RapportoGaraSostituzioneFlowView(
                        numeroUscita: evento.numeroMaglia,
                        numeroEntrata: evento.numeroMagliaEntrata
                    )
                }

                if let testoSupporto {
                    Text(testoSupporto)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RapportoGaraGlassBackground(cornerRadius: 20, accent: coloreAccento)
        }
    }

    private var dettaglioEvento: String {
        if evento.tipoEvento == .sostituzione {
            return evento.latoSquadra?.titolo ?? ""
        }
        if let lato = evento.latoSquadra, let numero = evento.numeroMaglia {
            return "\(lato.titolo) · #\(numero)"
        }
        if let lato = evento.latoSquadra {
            return lato.titolo
        }
        if let numero = evento.numeroMaglia {
            return "#\(numero)"
        }
        return ""
    }

    private var descrizioneEvento: String {
        switch evento.tipoEvento {
        case .doppioGialloRosso:
            return "Espulsione · doppia ammonizione"
        case .espulsione:
            return "Espulsione"
        case .ammonizione:
            return "Ammonizione"
        case .gol:
            return "Gol"
        case .sostituzione:
            return "Sostituzione"
        case .notaLibera:
            return "Nota gara"
        }
    }

    private var minutoCardLabel: String {
        let snapshot = evento.minuto

        switch snapshot.labelPeriodo {
        case "2T":
            if let recupero = snapshot.recupero {
                return "45+\(recupero)'"
            }
            let minutoRelativo = max(1, snapshot.minuto - 45)
            return "\(minutoRelativo)'"
        case "1T":
            if let recupero = snapshot.recupero {
                return "45+\(recupero)'"
            }
            return "\(max(1, snapshot.minuto))'"
        default:
            return snapshot.labelMinuto
        }
    }

    private var periodoCardLabel: String {
        evento.minuto.labelPeriodo
    }

    private var testoSupporto: String? {
        let motivazione = evento.motivazione?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let motivazione, !motivazione.isEmpty {
            return motivazione
        }

        let testoDettato = evento.testoDettato.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !testoDettato.isEmpty else { return nil }
        guard evento.tipoEvento == .notaLibera
            || evento.latoSquadra == nil
            || evento.numeroMaglia == nil
            || (evento.tipoEvento == .sostituzione && evento.numeroMagliaEntrata == nil) else {
            return nil
        }
        return testoDettato
    }
}

private struct RapportoGaraEventCardIcons: View {
    let tipoEvento: TipoEventoRapportoGara

    var body: some View {
        switch tipoEvento {
        case .ammonizione:
            RapportoGaraCardGlyph(color: Color(hex: 0xFFD15B))
        case .espulsione:
            RapportoGaraCardGlyph(color: Color(hex: 0xFF5B68))
        case .doppioGialloRosso:
            HStack(spacing: 2) {
                RapportoGaraCardGlyph(color: Color(hex: 0xFFD15B), angle: -8)
                RapportoGaraCardGlyph(color: Color(hex: 0xFFD15B), angle: 0)
                RapportoGaraCardGlyph(color: Color(hex: 0xFF5B68), angle: 8)
            }
        case .gol:
            Image(systemName: "soccerball")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white)
        case .sostituzione:
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: 0x84B8FF))
        case .notaLibera:
            Image(systemName: "note.text")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: 0x9BC7FF))
        }
    }
}

private struct RapportoGaraSostituzioneFlowView: View {
    let numeroUscita: Int?
    let numeroEntrata: Int?

    var body: some View {
        HStack(spacing: 10) {
            movimentoBadge(
                icon: "arrow.left.circle.fill",
                color: Color(hex: 0xFF7676),
                label: numeroUscita.map { "#\($0)" } ?? "--"
            )

            movimentoBadge(
                icon: "arrow.right.circle.fill",
                color: Color(hex: 0x64D39A),
                label: numeroEntrata.map { "#\($0)" } ?? "--"
            )
        }
    }

    private func movimentoBadge(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(color.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct RapportoGaraCardGlyph: View {
    let color: Color
    var angle: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: 8, height: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.black.opacity(0.16), lineWidth: 0.6)
            )
            .rotationEffect(.degrees(angle))
            .shadow(color: color.opacity(0.18), radius: 1.5, y: 1)
    }
}

private struct RapportoGaraAudioRowView: View {
    let registrazione: RegistrazioneAudioRapportoGara
    let inRiproduzione: Bool
    let onPlay: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            minutoCard

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text(registrazione.stato.titolo.uppercased())
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(statoColore)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(statoColore.opacity(0.14))
                        )

                    Text(Self.byteFormatter.string(fromByteCount: Int64(registrazione.byteCount)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.52))
                }

                Text(registrazione.creatoIl.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.64))

                if let testo = registrazione.testoTrascritto, !testo.isEmpty {
                    Text(testo)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                } else if let errore = registrazione.ultimoErrore, !errore.isEmpty {
                    Text(errore)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: 0xFFB0B0))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Trascrizione ancora in lavorazione.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.64))
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button(action: onPlay) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x4FA4FF), Color(hex: 0x2765C7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 46, height: 46)

                        Image(systemName: inRiproduzione ? "stop.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFF8A8A))
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RapportoGaraGlassBackground(cornerRadius: 20, accent: statoColore)
        }
    }

    private var minutoCard: some View {
        VStack(spacing: 4) {
            if let snapshot = registrazione.snapshot {
                Text(snapshot.labelMinuto)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(snapshot.labelPeriodo)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.62))
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))

                Text("Audio")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.62))
            }
        }
        .frame(width: 72, height: 72)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x204A84).opacity(0.92), Color(hex: 0x112C52).opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var statoColore: Color {
        switch registrazione.stato {
        case .inAttesa:
            return Color(hex: 0x9FD1FF)
        case .trascritta:
            return Color(hex: 0x8FE3A7)
        case .errore:
            return Color(hex: 0xFF9898)
        }
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()
}

private struct RapportoGaraSessionMetaPill: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: 0x9BC7FF))

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.48))

                Text(value)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct RapportoGaraStatusBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x366AB2).opacity(0.84), Color(hex: 0x234A85).opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
}

private struct RapportoGaraCompactMetricView: View {
    let label: String
    let value: String
    var accent: Color = Color(hex: 0x8CCFFF)
    var isLive: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.52))

                if isLive {
                    Text("LIVE")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accent.opacity(0.22))
                        )
                }
            }

            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .background {
            RapportoGaraGlassBackground(cornerRadius: 18, accent: accent)
        }
    }
}

private struct RapportoGaraTagMetricView: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: 0x9BC7FF))

            Text(label.uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.54))

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background {
            RapportoGaraGlassBackground(cornerRadius: 18, accent: Color(hex: 0x82C8FF))
        }
    }
}

private struct RapportoGaraTagView: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.52))
            Text(value)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(RapportoGaraPalette.inlineSurface)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct RapportoGaraSectionCard<Content: View>: View {
    let titolo: String
    let sottotitolo: String
    let content: Content

    init(
        titolo: String,
        sottotitolo: String,
        @ViewBuilder content: () -> Content
    ) {
        self.titolo = titolo
        self.sottotitolo = sottotitolo
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titolo)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if !sottotitolo.isEmpty {
                    Text(sottotitolo)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RapportoGaraGlassBackground(cornerRadius: 26, accent: Color(hex: 0x94C1FF))
        }
        .shadow(color: Color.black.opacity(0.10), radius: 12, y: 8)
    }
}

private struct RapportoGaraLiveClockCardView: View {
    let display: CronometroDisplayLiveRapportoGara
    let snapshot: MinutoRapportoGaraSnapshot
    let stato: StatoCronometroRapportoGara
    let sincronizzataIl: Date?
    let watchRaggiungibile: Bool

    private var accent: Color {
        watchRaggiungibile ? RapportoGaraPalette.accent : RapportoGaraPalette.accentSoft
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(watchRaggiungibile ? "CRONOMETRO LIVE" : "CRONOMETRO SINCRONIZZATO")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                    .tracking(1.0)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(display.principale)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    if let decimi = display.decimi {
                        Text(".\(decimi)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(accent)
                    }
                }

                HStack(spacing: 8) {
                    RapportoGaraTimerChip(title: snapshot.labelPeriodo, accent: accent)
                    RapportoGaraTimerChip(title: snapshot.labelMinuto, accent: Color.white.opacity(0.9))
                    RapportoGaraTimerChip(
                        title: watchRaggiungibile ? "Watch vicino" : "In attesa sync",
                        accent: watchRaggiungibile ? RapportoGaraPalette.accentSoft : Color.white.opacity(0.7)
                    )

                    if let sincronizzataIl {
                        RapportoGaraTimerChip(
                            title: Self.syncFormatter.string(from: sincronizzataIl),
                            accent: Color.white.opacity(0.7)
                        )
                    }
                }
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: 58, height: 58)

                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    .frame(width: 58, height: 58)

                Image(systemName: watchRaggiungibile && stato.isInCorso ? "waveform.and.mic" : "clock")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RapportoGaraGlassBackground(cornerRadius: 22, accent: accent)
        }
    }

    private static let syncFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct RapportoGaraTimerChip: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(RapportoGaraPalette.inlineSurface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent.opacity(0.16), lineWidth: 1)
            )
    }
}

private struct RapportoGaraAmbientBackgroundView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RapportoGaraPalette.accent.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 120)
                .offset(x: -140, y: -320)

            Circle()
                .fill(RapportoGaraPalette.accentSoft.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 110)
                .offset(x: 150, y: -160)
        }
    }
}

private struct RapportoGaraGlassBackground: View {
    let cornerRadius: CGFloat
    let accent: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            shape
                .fill(RapportoGaraPalette.surfaceStrong)
        }
        .clipShape(shape)
        .overlay(
            shape
                .stroke(accent.opacity(0.24), lineWidth: 1)
        )
    }
}

private final class RapportoGaraAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var audioInRiproduzioneID: UUID?

    private var player: AVAudioPlayer?
    private let audioSession = AVAudioSession.sharedInstance()

    func togglePlayback(registrazione: RegistrazioneAudioRapportoGara, store: RapportoGaraStore) {
        if audioInRiproduzioneID == registrazione.id {
            stop()
            return
        }

        guard let fileURL = store.urlRegistrazioneAudio(per: registrazione) else {
            stop()
            return
        }

        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)

            let nuovoPlayer = try AVAudioPlayer(contentsOf: fileURL)
            nuovoPlayer.delegate = self
            nuovoPlayer.volume = 1
            nuovoPlayer.prepareToPlay()
            guard nuovoPlayer.play() else {
                stop()
                return
            }
            player = nuovoPlayer
            audioInRiproduzioneID = registrazione.id
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        audioInRiproduzioneID = nil
        try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }
}
