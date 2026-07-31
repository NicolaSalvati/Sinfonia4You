import Combine
import Foundation
import SwiftUI

struct RapportoGaraWatchRootView: View {
    @EnvironmentObject private var store: RapportoGaraWatchStore

    var body: some View {
        NavigationStack {
            Group {
                if let sessioneAttiva = store.sessioneAttiva {
                    RapportoGaraWatchMatchModeView(sessionID: sessioneAttiva.id)
                } else if !store.isAbbinato && store.sessioniConcluse.isEmpty {
                    RapportoGaraWatchPairingView()
                } else {
                    RapportoGaraWatchHomeView()
                }
            }
        }
    }
}

private struct RapportoGaraWatchPairingView: View {
    @EnvironmentObject private var store: RapportoGaraWatchStore

    var body: some View {
        RapportoGaraWatchScreen(
            title: "Collega iPhone",
            subtitle: "Inserisci il codice a 6 cifre generato nell'app iPhone."
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 42, height: 42)

                        Image(systemName: "applewatch.side.right")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(Color(hex: 0xCFE4FF))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Setup rapido")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Collega il Watch una volta sola, poi lavori anche offline.")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                RapportoGaraWatchRowDivider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Codice")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.70))

                    TextField("123456", text: $store.codiceAbbinamento)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.09))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                RapportoGaraWatchPrimaryButton(
                    title: "Collega Watch",
                    icon: "wave.3.right",
                    accent: Color(hex: 0x2E7BE0)
                ) {
                    store.collegaConCodiceInserito()
                }

                RapportoGaraWatchRowDivider()

                VStack(alignment: .leading, spacing: 10) {
                    RapportoGaraWatchStatusLine(
                        titolo: store.companionAppInstallata ? "App iPhone rilevata" : "Installa prima l'app iPhone",
                        dettaglio: store.companionAppInstallata ? "Companion pronta per la sincronizzazione." : "Apri Sinfonia4You su iPhone e installa la companion.",
                        color: store.companionAppInstallata ? Color(hex: 0x7EE5A1) : Color(hex: 0xFFD27B)
                    )

                    RapportoGaraWatchStatusLine(
                        titolo: store.telefonoRaggiungibile ? "iPhone vicino" : "Watch pronto anche offline",
                        dettaglio: store.telefonoRaggiungibile ? "Lo scambio dati e immediato." : "Le sessioni restano salvate e si sincronizzano quando torni vicino.",
                        color: store.telefonoRaggiungibile ? Color(hex: 0x7EE5A1) : Color(hex: 0x9BC7FF)
                    )
                }

                if !store.messaggioStato.isEmpty {
                    RapportoGaraWatchRowDivider()
                    RapportoGaraWatchMessageCard(message: store.messaggioStato)
                }
            }
        }
        .navigationTitle("Collega")
    }
}

private struct RapportoGaraWatchHomeView: View {
    @EnvironmentObject private var store: RapportoGaraWatchStore
    @State private var sessioneDaEliminare: SessioneLocaleRapportoGaraWatch?

    var body: some View {
        ZStack(alignment: .bottom) {
            RapportoGaraWatchScreen(
                title: "Rapporto Gara",
                subtitle: store.telefonoRaggiungibile ? "Pronto al sync con iPhone" : "Modalita offline pronta"
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        RapportoGaraWatchMiniPill(
                            title: store.telefonoRaggiungibile ? "iPhone vicino" : "Offline",
                            icon: store.telefonoRaggiungibile ? "dot.radiowaves.left.and.right" : "icloud.slash",
                            accent: store.telefonoRaggiungibile ? Color(hex: 0x7EE5A1) : Color(hex: 0x9BC7FF)
                        )

                        RapportoGaraWatchMiniPill(
                            title: "\(store.sessioniConcluse.count) archiviate",
                            icon: "tray.full.fill",
                            accent: Color(hex: 0x9BC7FF)
                        )
                    }
                    .padding(.bottom, 6)

                    Text("Tocca una gara e parti subito. Il Watch salva tutto anche senza iPhone vicino.")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)

                    RapportoGaraWatchRowDivider()

                    Text("Gare disponibili")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.68))

                    if store.gareDisponibili.isEmpty {
                        RapportoGaraWatchMessageCard(
                            title: "Nessuna gara ricevuta",
                            message: "Apri Rapporto Gara su iPhone e invia le partite disponibili al Watch."
                        )
                        .padding(.top, 10)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.gareDisponibili.enumerated()), id: \.element.id) { index, referto in
                                Button {
                                    store.avviaSessione(per: referto)
                                } label: {
                                    RapportoGaraWatchMatchRow(referto: referto)
                                }
                                .buttonStyle(.plain)

                                if index < store.gareDisponibili.count - 1 {
                                    RapportoGaraWatchRowDivider()
                                }
                            }
                        }
                        .padding(.top, 8)
                    }

                    if !store.sessioniConcluse.isEmpty {
                        RapportoGaraWatchRowDivider()

                        Text("Sessioni archiviate")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.68))

                        VStack(spacing: 0) {
                            ForEach(Array(store.sessioniConcluse.enumerated()), id: \.element.id) { index, sessione in
                                RapportoGaraWatchSessionRow(sessione: sessione.sessione) {
                                    sessioneDaEliminare = sessione
                                }

                                if index < store.sessioniConcluse.count - 1 {
                                    RapportoGaraWatchRowDivider()
                                }
                            }
                        }
                        .padding(.top, 8)
                    }

                    if !store.messaggioStato.isEmpty {
                        RapportoGaraWatchRowDivider()
                        RapportoGaraWatchMessageCard(message: store.messaggioStato)
                    }
                }
                .blur(radius: sessioneDaEliminare == nil ? 0 : 2)
                .allowsHitTesting(sessioneDaEliminare == nil)
            }

            if let sessioneDaEliminare {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                    .onTapGesture {
                        self.sessioneDaEliminare = nil
                    }

                RapportoGaraWatchDeleteConfirmationSheet(
                    titoloGara: sessioneDaEliminare.sessione.titoloGara,
                    onConfirm: {
                        store.eliminaSessione(id: sessioneDaEliminare.id)
                        self.sessioneDaEliminare = nil
                    },
                    onCancel: {
                        self.sessioneDaEliminare = nil
                    }
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Rapporto")
        .animation(.easeInOut(duration: 0.18), value: sessioneDaEliminare != nil)
    }
}

private struct RapportoGaraWatchActiveSessionRow: View {
    let sessione: SessioneRapportoGara

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 34, height: 34)

                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: 0x9BC7FF))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(sessione.titoloGara)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Text("\(CalcolatoreCronometroRapportoGara.snapshot(per: sessione).labelMinuto) · \(sessione.statoCronometro.titolo)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.68))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.44))
        }
        .padding(.vertical, 10)
    }
}

private enum AzioneConfermaRapportoGaraWatch {
    case pausa
    case termina

    var titolo: String {
        switch self {
        case .pausa:
            return "Mettere in pausa?"
        case .termina:
            return "Terminare partita?"
        }
    }

    var messaggio: String {
        switch self {
        case .pausa:
            return "Sei sicuro di voler mettere in pausa il cronometro?"
        case .termina:
            return "Sei sicuro di voler terminare la partita?"
        }
    }

    var confermaLabel: String {
        switch self {
        case .pausa:
            return "Si"
        case .termina:
            return "Si"
        }
    }

    var accessibilitaConferma: String {
        switch self {
        case .pausa:
            return "Si, metti in pausa il cronometro"
        case .termina:
            return "Si, termina la partita"
        }
    }

    var icona: String {
        switch self {
        case .pausa:
            return "pause.circle.fill"
        case .termina:
            return "flag.checkered.circle.fill"
        }
    }
}

private struct RapportoGaraWatchMatchModeView: View {
    @EnvironmentObject private var store: RapportoGaraWatchStore
    @State private var ritornoTimerWorkItem: DispatchWorkItem?
    @State private var ritornoTimerProgrammato = false
    @State private var azioneDaConfermare: AzioneConfermaRapportoGaraWatch?
    @State private var triggerRitornoAlTimer = 0

    let sessionID: UUID
    private let timerAnchorID = "match-timer-top"

    var body: some View {
        ZStack {
            RapportoGaraWatchBackgroundView()
                .ignoresSafeArea()

            if let sessioneLocale = store.sessioneLocale(id: sessionID) {
                let sessione = sessioneLocale.sessione
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        Color.clear
                            .frame(height: 1)
                            .id(timerAnchorID)

                        RapportoGaraWatchLiveCanvas(
                            sessione: sessione,
                            sessioneLocale: sessioneLocale,
                            prompt: store.promptRecuperoAttivo,
                            voiceState: store.statoDettaturaDiretta,
                            secondaryControl: controlloSecondario(sessione: sessione),
                            onPrimaryAction: {
                                primaryAction(for: sessione)
                            },
                            onRecoverySelect: { minuti in
                                store.impostaRecupero(minuti, sessionID: sessionID)
                            },
                            onEventListReveal: {
                                programmaRitornoAlTimer(using: proxy)
                            }
                        )
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .blur(radius: azioneDaConfermare == nil ? 0 : 3)
                    .allowsHitTesting(azioneDaConfermare == nil)
                    .onChange(of: triggerRitornoAlTimer) { _, _ in
                        withAnimation(.easeInOut(duration: 0.24)) {
                            proxy.scrollTo(timerAnchorID, anchor: .top)
                        }
                    }
                }
            } else {
                RapportoGaraWatchScreen(
                    title: "Live Match",
                    subtitle: "Sessione non disponibile"
                ) {
                    RapportoGaraWatchMessageCard(
                        title: "Sessione non trovata",
                        message: "Torna alla schermata principale e riapri il Match Mode."
                    )
                }
            }

            if let azioneDaConfermare {
                RapportoGaraWatchActionConfirmationOverlay(
                    azione: azioneDaConfermare,
                    onConfirm: confermaAzioneCritica,
                    onCancel: annullaConfermaAzioneCritica
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(2)
            }
        }
        .onDisappear {
            annullaRitornoAlTimer()
            azioneDaConfermare = nil
        }
        .animation(.easeInOut(duration: 0.18), value: azioneDaConfermare != nil)
    }

    private func controlloSecondario(sessione: SessioneRapportoGara) -> (title: String, icon: String, action: () -> Void)? {
        switch sessione.statoCronometro {
        case .prepartita, .finale:
            return nil
        case .primoTempo, .recuperoPrimoTempo:
            return ("Pausa 1T", "pause.fill", {
                azioneDaConfermare = .pausa
            })
        case .intervallo:
            return ("Chiudi gara", "flag.checkered", {
                azioneDaConfermare = .termina
            })
        case .secondoTempo, .recuperoSecondoTempo:
            return ("Fine gara", "stop.fill", {
                azioneDaConfermare = .termina
            })
        }
    }
    
    private func primaryAction(for sessione: SessioneRapportoGara) {
        switch sessione.statoCronometro {
        case .prepartita:
            store.avviaPrimoTempo(sessionID: sessionID)
        case .primoTempo, .recuperoPrimoTempo, .secondoTempo, .recuperoSecondoTempo:
            switch store.statoDettaturaDiretta {
            case .inattiva:
                store.avviaDettaturaDiretta(sessionID: sessionID)
            case .ascolto:
                store.concludiDettaturaDiretta()
            case .elaborazione:
                store.avviaDettaturaDiretta(sessionID: sessionID)
            }
        case .intervallo:
            store.avviaSecondoTempo(sessionID: sessionID)
        case .finale:
            break
        }
    }

    private func programmaRitornoAlTimer(using proxy: ScrollViewProxy) {
        guard !ritornoTimerProgrammato else { return }

        ritornoTimerWorkItem?.cancel()
        ritornoTimerProgrammato = true

        let item = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.28)) {
                proxy.scrollTo(timerAnchorID, anchor: .top)
            }
            ritornoTimerProgrammato = false
            ritornoTimerWorkItem = nil
        }

        ritornoTimerWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: item)
    }

    private func annullaRitornoAlTimer() {
        ritornoTimerWorkItem?.cancel()
        ritornoTimerWorkItem = nil
        ritornoTimerProgrammato = false
    }

    private func confermaAzioneCritica() {
        guard let azioneDaConfermare else { return }
        self.azioneDaConfermare = nil
        annullaRitornoAlTimer()

        switch azioneDaConfermare {
        case .pausa:
            store.pausaFinePrimoTempo(sessionID: sessionID)
        case .termina:
            store.terminaPartita(sessionID: sessionID)
        }

        DispatchQueue.main.async {
            triggerRitornoAlTimer += 1
        }
    }

    private func annullaConfermaAzioneCritica() {
        azioneDaConfermare = nil
    }
}

private struct RapportoGaraWatchLiveCanvas: View {
    let sessione: SessioneRapportoGara
    let sessioneLocale: SessioneLocaleRapportoGaraWatch
    let prompt: PromptRecuperoRapportoGara?
    let voiceState: StatoDettaturaDirettaRapportoGara
    let secondaryControl: (title: String, icon: String, action: () -> Void)?
    let onPrimaryAction: () -> Void
    let onRecoverySelect: (Int) -> Void
    let onEventListReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RapportoGaraWatchLiveTimerSection(sessioneLocale: sessioneLocale)
                .padding(.bottom, prompt == nil && sessione.statoCronometro != .finale ? 18 : 12)

            if let prompt {
                VStack(alignment: .center, spacing: 12) {
                    Text(prompt.titolo)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .center)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6)
                    ], spacing: 6) {
                        ForEach(0...6, id: \.self) { minuto in
                            Button {
                                onRecoverySelect(minuto)
                            } label: {
                                Text("\(minuto)'")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.white.opacity(0.08))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 18)
            } else if sessione.statoCronometro != .finale {
                HStack {
                    Spacer(minLength: 0)
                    HStack(spacing: 12) {
                        if let secondaryControl {
                            Button(action: secondaryControl.action) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 44, height: 44)

                                    Circle()
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                        .frame(width: 44, height: 44)

                                    Image(systemName: secondaryControl.icon)
                                        .font(.system(size: 16, weight: .black))
                                        .foregroundStyle(.white.opacity(0.92))
                                }
                                .frame(width: 58, height: 58)
                                .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(secondaryControl.title)
                        }

                        Button(action: onPrimaryAction) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: primaryGradient,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 56, height: 56)

                                Circle()
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                    .frame(width: 56, height: 56)

                                Image(systemName: primaryIcon)
                                    .font(.system(size: 21, weight: .black))
                                    .foregroundStyle(.white)
                            }
                            .shadow(color: Color(hex: 0x2E7BE0).opacity(0.22), radius: 8, y: 4)
                            .frame(width: 72, height: 72)
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(primaryActionLabel)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, eventiDaMostrare.isEmpty ? 0 : 16)
            }

            if !eventiDaMostrare.isEmpty {
                Color.clear
                    .frame(height: 1)
                    .onAppear(perform: onEventListReveal)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(eventiDaMostrare.enumerated()), id: \.element.id) { index, evento in
                        RapportoGaraWatchEventRow(evento: evento)

                        if index < eventiDaMostrare.count - 1 {
                            RapportoGaraWatchRowDivider()
                                .padding(.vertical, 0)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var primaryActionLabel: String {
        switch sessione.statoCronometro {
        case .prepartita:
            return "Avvia primo tempo"
        case .primoTempo, .recuperoPrimoTempo, .secondoTempo, .recuperoSecondoTempo:
            switch voiceState {
            case .inattiva:
                return "Registra evento"
            case .ascolto:
                return "Concludi ascolto"
            case .elaborazione:
                return "Registra evento"
            }
        case .intervallo:
            return "Avvia secondo tempo"
        case .finale:
            return "Partita chiusa"
        }
    }

    private var primaryIcon: String {
        switch sessione.statoCronometro {
        case .prepartita, .intervallo:
            return "play.fill"
        case .primoTempo, .recuperoPrimoTempo, .secondoTempo, .recuperoSecondoTempo:
            switch voiceState {
            case .inattiva:
                return "mic.fill"
            case .ascolto:
                return "waveform"
            case .elaborazione:
                return "mic.fill"
            }
        case .finale:
            return "checkmark.circle.fill"
        }
    }

    private var primaryGradient: [Color] {
        switch sessione.statoCronometro {
        case .prepartita, .intervallo:
            return [Color(hex: 0x2E7BE0), Color(hex: 0x1B5AB0)]
        case .primoTempo, .recuperoPrimoTempo, .secondoTempo, .recuperoSecondoTempo:
            switch voiceState {
            case .inattiva:
                return [Color(hex: 0x5CA4FF), Color(hex: 0x2567CC)]
            case .ascolto:
                return [Color(hex: 0x3E95FF), Color(hex: 0x0F5CCB)]
            case .elaborazione:
                return [Color(hex: 0x5CA4FF), Color(hex: 0x2567CC)]
            }
        case .finale:
            return [Color(hex: 0x3E7F63), Color(hex: 0x255442)]
        }
    }

    private var eventiDaMostrare: [EventoRapportoGara] {
        Array(sessione.eventiOrdinati.reversed())
    }
}

private struct RapportoGaraWatchLiveTimerSection: View {
    let sessioneLocale: SessioneLocaleRapportoGaraWatch

    var body: some View {
        TimelineView(.periodic(
            from: .now,
            by: sessioneLocale.sessione.statoCronometro.isInCorso ? (1.0 / 20.0) : 1.0
        )) { context in
            let referenceDate = sessioneLocale.sessione.statoCronometro.isInCorso
                ? max(context.date, sessioneLocale.faseAvviataIl ?? context.date)
                : sessioneLocale.sessione.aggiornataIl
            let sessione = sessioneLocale.sessioneRenderizzata(alla: referenceDate)
            let cronometroDisplay = sessioneLocale.cronometroDisplay(alla: referenceDate)
            let snapshot = CalcolatoreCronometroRapportoGara.snapshot(per: sessione)

            VStack(spacing: 8) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(cronometroDisplay.principale)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.60)

                    if let decimi = cronometroDisplay.decimi {
                        Text(".\(decimi)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .allowsTightening(true)
                            .foregroundStyle(Color.white.opacity(0.92))
                            .padding(.bottom, 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

                Text(snapshot.labelMinuto)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct RapportoGaraWatchDeleteConfirmationSheet: View {
    let titoloGara: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 38, height: 38)

                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFFB59F))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Eliminare sessione?")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(titoloGara)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(2)
                }
            }

            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text("Annulla")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text("Elimina")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: 0x2E7BE0), Color(hex: 0x1B5AB0)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x153965).opacity(0.98), Color(hex: 0x0A1F3D).opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 10, y: 6)
    }
}

private struct RapportoGaraWatchRecoveryPrompt: View {
    let prompt: PromptRecuperoRapportoGara
    let onSelect: (Int) -> Void

    private let colonne = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        RapportoGaraWatchGlassCard(accent: Color(hex: 0x5CA4FF).opacity(0.24)) {
            VStack(alignment: .leading, spacing: 10) {
                Text(prompt.titolo)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text("Il cronometro continua: scegli subito i minuti di recupero.")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.74))

                LazyVGrid(columns: colonne, spacing: 6) {
                    ForEach(0...6, id: \.self) { minuto in
                        Button {
                            onSelect(minuto)
                        } label: {
                            Text("\(minuto)'")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct RapportoGaraWatchActionConfirmationOverlay: View {
    let azione: AzioneConfermaRapportoGaraWatch
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            RapportoGaraWatchBackgroundView()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    Color(hex: 0x081B38).opacity(0.68),
                    Color(hex: 0x061426).opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 66, height: 66)

                    Circle()
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        .frame(width: 66, height: 66)

                    Image(systemName: azione.icona)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(Color(hex: 0x9BC7FF))
                }
                .padding(.bottom, 16)

                VStack(spacing: 8) {
                    Text(azione.titolo)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(azione.messaggio)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.84))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8)

                Spacer(minLength: 18)

                HStack(spacing: 8) {
                    Button(action: onCancel) {
                        Text("No")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("No, annulla")

                    Button(action: onConfirm) {
                        Text(azione.confermaLabel)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: 0x2E7BE0), Color(hex: 0x1B5AB0)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(azione.accessibilitaConferma)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct RapportoGaraWatchMatchCard: View {
    let referto: RefertoDisponibileRapportoGara

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(referto.titolo)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            HStack(spacing: 8) {
                if !referto.ruoloLabel.isEmpty {
                    RapportoGaraWatchMiniPill(
                        title: referto.ruoloLabel,
                        icon: "person.fill",
                        accent: Color(hex: 0x9BC7FF)
                    )
                }

                RapportoGaraWatchMiniPill(
                    title: "Avvio rapido",
                    icon: "play.fill",
                    accent: Color(hex: 0x5CA4FF)
                )
            }

            Text(referto.sottotitolo)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x163A6A).opacity(0.90), Color(hex: 0x0E2545).opacity(0.96)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct RapportoGaraWatchPastSessionCard: View {
    let sessione: SessioneRapportoGara

    var body: some View {
        RapportoGaraWatchGlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(sessione.titoloGara)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    RapportoGaraWatchMiniPill(
                        title: "\(sessione.eventi.count) eventi",
                        icon: "waveform.badge.mic",
                        accent: Color(hex: 0x9BC7FF)
                    )

                    RapportoGaraWatchMiniPill(
                        title: sessione.statoCronometro.titolo,
                        icon: "flag.checkered",
                        accent: Color(hex: 0x5CA4FF)
                    )
                }
            }
        }
    }
}

private struct RapportoGaraWatchEventRow: View {
    let evento: EventoRapportoGara

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            minutoBadge

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 8) {
                    RapportoGaraWatchEventCardIcons(tipoEvento: evento.tipoEvento)
                        .frame(width: 20, height: 20, alignment: .center)

                    Text(labelPrincipale)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                RapportoGaraWatchEventBadge(
                    title: descrizioneEvento,
                    accent: coloreAccento
                )

                if evento.tipoEvento == .sostituzione,
                   evento.numeroMaglia != nil || evento.numeroMagliaEntrata != nil {
                    RapportoGaraWatchSostituzioneFlowView(
                        numeroUscita: evento.numeroMaglia,
                        numeroEntrata: evento.numeroMagliaEntrata
                    )
                }

                if let testoSupporto {
                    Text(testoSupporto)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
    }

    private var minutoBadge: some View {
        VStack(spacing: 2) {
            Text(evento.minuto.labelMinuto)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(evento.minuto.labelPeriodo)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.60))
                .lineLimit(1)
        }
        .frame(width: 40, height: 42)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var labelPrincipale: String {
        if evento.tipoEvento == .sostituzione {
            return evento.latoSquadra?.titolo ?? "Sostituzione"
        }
        if let squadra = evento.latoSquadra?.titolo, let numero = evento.numeroMaglia {
            return "\(squadra) #\(numero)"
        }
        if let squadra = evento.latoSquadra?.titolo {
            return squadra
        }
        if let numero = evento.numeroMaglia {
            return "#\(numero)"
        }
        return "Evento gara"
    }

    private var coloreAccento: Color {
        switch evento.tipoEvento {
        case .ammonizione:
            return Color(hex: 0xFFD15B)
        case .espulsione:
            return Color(hex: 0xFF5B68)
        case .doppioGialloRosso:
            return Color(hex: 0xFFA15A)
        case .gol:
            return Color(hex: 0x84B8FF)
        case .sostituzione:
            return Color(hex: 0x84B8FF)
        case .notaLibera:
            return Color(hex: 0x9BC7FF)
        }
    }

    private var testoSupporto: String? {
        let motivazione = evento.motivazione?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let motivazione, Self.testoSupportoSignificativo(motivazione) {
            return motivazione
        }

        let clean = evento.testoDettato.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        guard evento.tipoEvento == .notaLibera
            || evento.latoSquadra == nil
            || evento.numeroMaglia == nil
            || (evento.tipoEvento == .sostituzione && evento.numeroMagliaEntrata == nil) else {
            return nil
        }
        return Self.testoSupportoSignificativo(clean) ? clean : nil
    }

    private var descrizioneEvento: String {
        switch evento.tipoEvento {
        case .doppioGialloRosso:
            return "2G -> R"
        case .espulsione:
            return "Rosso"
        case .gol:
            return "Gol"
        case .sostituzione:
            return "Cambio"
        case .ammonizione:
            return "Giallo"
        default:
            return evento.tipoEvento.titoloBreve
        }
    }

    private static func testoSupportoSignificativo(_ value: String) -> Bool {
        let normalizzato = value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizzato.count >= 5 else { return false }

        let frammentiDaNascondere: Set<String> = [
            "squadra",
            "squadra di",
            "di casa",
            "di ospiti",
            "di ospite",
            "casa",
            "ospiti",
            "ospite"
        ]
        return !frammentiDaNascondere.contains(normalizzato)
    }
}

private struct RapportoGaraWatchEventBadge: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .font(.system(size: 10.5, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.84)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.18))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent.opacity(0.22), lineWidth: 1)
            )
    }
}

private struct RapportoGaraWatchEventCardIcons: View {
    let tipoEvento: TipoEventoRapportoGara

    var body: some View {
        switch tipoEvento {
        case .ammonizione:
            RapportoGaraWatchCardGlyph(color: Color(hex: 0xFFD15B))
        case .espulsione:
            RapportoGaraWatchCardGlyph(color: Color(hex: 0xFF5B68))
        case .doppioGialloRosso:
            HStack(spacing: 2) {
                RapportoGaraWatchCardGlyph(color: Color(hex: 0xFFD15B), angle: -8)
                RapportoGaraWatchCardGlyph(color: Color(hex: 0xFFD15B), angle: 0)
                RapportoGaraWatchCardGlyph(color: Color(hex: 0xFF5B68), angle: 8)
            }
        case .gol:
            Image(systemName: "soccerball")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        case .sostituzione:
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: 0x84B8FF))
        case .notaLibera:
            Image(systemName: "note.text")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: 0x9BC7FF))
        }
    }
}

private struct RapportoGaraWatchSostituzioneFlowView: View {
    let numeroUscita: Int?
    let numeroEntrata: Int?

    var body: some View {
        HStack(spacing: 8) {
            movimento(icon: "arrow.left.circle.fill", color: Color(hex: 0xFF7676), label: numeroUscita)
            movimento(icon: "arrow.right.circle.fill", color: Color(hex: 0x64D39A), label: numeroEntrata)
        }
    }

    private func movimento(icon: String, color: Color, label: Int?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)

            Text(label.map { "#\($0)" } ?? "--")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
        }
    }
}

private struct RapportoGaraWatchCardGlyph: View {
    let color: Color
    var angle: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: 8, height: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.black.opacity(0.16), lineWidth: 0.6)
            )
            .rotationEffect(.degrees(angle))
            .shadow(color: color.opacity(0.18), radius: 1.5, y: 1)
    }
}

private struct RapportoGaraWatchConnectionBadge: View {
    let titolo: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(titolo)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct RapportoGaraWatchStatusLine: View {
    let titolo: String
    let dettaglio: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(titolo)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)

                Text(dettaglio)
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct RapportoGaraWatchMatchRow: View {
    let referto: RefertoDisponibileRapportoGara

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: 0x5CA4FF))

            VStack(alignment: .leading, spacing: 2) {
                Text(referto.titolo)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Text(matchSubtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.44))
        }
        .padding(.vertical, 10)
    }

    private var matchSubtitle: String {
        if referto.ruoloLabel.isEmpty {
            return referto.sottotitolo
        }
        return "\(referto.ruoloLabel) · \(referto.sottotitolo)"
    }
}

private struct RapportoGaraWatchSessionRow: View {
    let sessione: SessioneRapportoGara
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(hex: 0x9BC7FF))

            VStack(alignment: .leading, spacing: 2) {
                Text(sessione.titoloGara)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Text("\(sessione.eventi.count) eventi · \(sessione.statoCronometro.titolo)")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.66))
            }

            Spacer(minLength: 0)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: 0xFF9B8E))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }
}

private struct RapportoGaraWatchTopBadge: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            )
    }
}

private struct RapportoGaraWatchRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.vertical, 12)
    }
}

private struct RapportoGaraWatchMiniPill: View {
    let title: String
    let icon: String
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent)

            Text(title)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct RapportoGaraWatchPrimaryButton: View {
    let title: String
    let icon: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))

                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.72)],
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
        .buttonStyle(.plain)
    }
}

private struct RapportoGaraWatchMessageCard: View {
    let title: String
    let message: String

    init(title: String = "Stato", message: String) {
        self.title = title
        self.message = message
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color(hex: 0x9BC7FF))
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.68))
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct RapportoGaraWatchScreen<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ZStack {
            RapportoGaraWatchBackgroundView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text(subtitle)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    RapportoGaraWatchRowDivider()
                    content
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x113864).opacity(0.95), Color(hex: 0x0A223F).opacity(0.98)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 22)
            }
        }
    }
}

private struct RapportoGaraWatchGlassCard<Content: View>: View {
    let accent: Color?
    let content: Content

    init(
        accent: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x173760).opacity(0.90), Color(hex: 0x0D223E).opacity(0.96)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke((accent ?? Color.white.opacity(0.10)), lineWidth: 1)
        )
    }
}

private struct RapportoGaraWatchBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x07162F),
                    Color(hex: 0x0A2450),
                    Color(hex: 0x0E3264)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(hex: 0x2E7BE0).opacity(0.28))
                .frame(width: 160, height: 160)
                .blur(radius: 22)
                .offset(x: 54, y: -84)

            Circle()
                .fill(Color(hex: 0x5CA4FF).opacity(0.16))
                .frame(width: 140, height: 140)
                .blur(radius: 18)
                .offset(x: -58, y: 112)
        }
    }
}

private extension Color {
    init(hex: UInt) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
