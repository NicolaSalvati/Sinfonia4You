import Combine
import Foundation
import WatchConnectivity
import WatchKit

final class RapportoGaraWatchStore: NSObject, ObservableObject {
    static let shared = RapportoGaraWatchStore()

    @Published private(set) var contestoTelefono = ContestoTelefonoRapportoGara()
    @Published private(set) var sessioniLocali: [SessioneLocaleRapportoGaraWatch] = []
    @Published private(set) var telefonoRaggiungibile = false
    @Published private(set) var companionAppInstallata = false
    @Published private(set) var statoDettaturaDiretta: StatoDettaturaDirettaRapportoGara = .inattiva
    @Published var codiceAbbinamento = ""
    @Published var messaggioStato = ""
    @Published var promptRecuperoAttivo: PromptRecuperoRapportoGara?

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var wcSession: WCSession?
    private var ticker: AnyCancellable?
    private var persistenzaESyncWorkItem: DispatchWorkItem?
    private let voiceRecorder = RapportoGaraWatchVoiceRecorder()
    private var richiesteTrascrizioneAttive: [UUID: ContestoTrascrizioneDiretta] = [:]
    private var dettaturePendentiInInvio: Set<UUID> = []
    private(set) var oraCorrente = Date()
    private lazy var watchIdentifier: String = {
        if let existing = defaults.string(forKey: Self.chiaveWatchIdentifier) {
            return existing
        }
        let nuovo = UUID().uuidString
        defaults.set(nuovo, forKey: Self.chiaveWatchIdentifier)
        return nuovo
    }()

    private static let chiaveWatchIdentifier = "sinfonia4you.watch.identifier.v1"
    private static let chiaveContestoTelefono = "sinfonia4you.rapportogara.phone.context"
    private static let chiaveContestoPersistito = "sinfonia4you.watch.phonecontext.v1"
    private static let chiaveSessioniLocali = "sinfonia4you.watch.localsessions.v1"
    private static let chiaveRichiestaAbbinamento = "sinfonia4you.rapportogara.pairing.request"
    private static let chiaveRichiestaEliminazioneSessioni = "sinfonia4you.rapportogara.delete.request"
    private static let chiavePacchettoSync = "sinfonia4you.rapportogara.sync.payload"
    private static let intervalloSyncCronometro: TimeInterval = 15

    private struct ContestoTrascrizioneDiretta {
        var sessionID: UUID
        var snapshot: MinutoRapportoGaraSnapshot
        var registrataIl: Date
        var audioData: Data
        var pendingID: UUID?
        var aggiornaStatoUI: Bool
    }

    private struct ChiaveGiocatore: Hashable {
        var latoSquadra: LatoSquadraRapportoGara
        var numeroMaglia: Int
    }

    private override init() {
        defaults = .standard
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        super.init()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        ripristinaPersistenza()
        attivaWatchConnectivitySePossibile()
        attivaTicker()
    }

    var nomeOrologio: String {
        WKInterfaceDevice.current().name
    }

    var isAbbinato: Bool {
        contestoTelefono.pairedWatchIDs.contains(watchIdentifier)
    }

    var gareDisponibili: [RefertoDisponibileRapportoGara] {
        Array(contestoTelefono.availableMatches.prefix(1))
    }

    var sessioniConcluse: [SessioneLocaleRapportoGaraWatch] {
        sessioniLocali
            .filter { $0.sessione.statoCronometro == .finale }
            .sorted { $0.sessione.aggiornataIl > $1.sessione.aggiornataIl }
    }

    var sessioneAttiva: SessioneLocaleRapportoGaraWatch? {
        sessioniLocali
            .filter { $0.sessione.statoCronometro != .finale }
            .sorted { $0.sessione.aggiornataIl > $1.sessione.aggiornataIl }
            .first
    }

    func sessioneLocale(id: UUID) -> SessioneLocaleRapportoGaraWatch? {
        sessioniLocali.first(where: { $0.id == id })
    }

    func sessioneRenderizzata(id: UUID) -> SessioneRapportoGara? {
        sessioneRenderizzata(id: id, alla: oraCorrente)
    }

    func sessioneRenderizzata(id: UUID, alla data: Date) -> SessioneRapportoGara? {
        sessioniLocali
            .first(where: { $0.id == id })?
            .sessioneRenderizzata(alla: data)
    }

    func cronometroDisplay(id: UUID, alla data: Date) -> CronometroDisplayRapportoGara? {
        sessioniLocali
            .first(where: { $0.id == id })?
            .cronometroDisplay(alla: data)
    }

    func collegaConCodiceInserito() {
        let codice = codiceAbbinamento.filter(\.isNumber)
        guard codice.count == 6 else {
            segnalaErrore("Inserisci 6 cifre.")
            return
        }

        guard let session = wcSession else {
            segnalaErrore("Connessione Watch non pronta.")
            return
        }

        let richiesta = RichiestaAbbinamentoRapportoGara(
            watchIdentifier: watchIdentifier,
            watchName: nomeOrologio,
            verificationCode: codice,
            requestedAt: Date()
        )

        guard let data = try? encoder.encode(richiesta) else {
            segnalaErrore("Codice non inviabile.")
            return
        }

        if session.isReachable {
            session.sendMessageData(
                data,
                replyHandler: { [weak self] replyData in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.gestisciRispostaAbbinamento(replyData)
                    }
                },
                errorHandler: { [weak self] _ in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        session.transferUserInfo([Self.chiaveRichiestaAbbinamento: data])
                        self.messaggioStato = "Richiesta inviata all'iPhone."
                    }
                }
            )
        } else {
            session.transferUserInfo([Self.chiaveRichiestaAbbinamento: data])
            messaggioStato = "Richiesta inviata all'iPhone."
        }

        WKInterfaceDevice.current().play(.click)
    }

    func avviaSessione(per referto: RefertoDisponibileRapportoGara) {
        guard sessioneAttiva == nil else {
            segnalaErrore("C'e gia una gara aperta.")
            return
        }

        let configurazione = configurazioneColori(
            sessionKey: nil,
            designazioneId: referto.designazioneId
        )

        let sessione = SessioneRapportoGara(
            sessionId: UUID().uuidString,
            designazioneId: referto.designazioneId,
            titoloGara: referto.titolo,
            dataGara: referto.sottotitolo,
            ruoloLabel: referto.ruoloLabel,
            nomeOrologio: nomeOrologio,
            coloreMagliaCasa: configurazione?.coloreMagliaCasa ?? "",
            coloreMagliaOspiti: configurazione?.coloreMagliaOspiti ?? "",
            statoCronometro: .prepartita,
            secondiPrimoTempo: 0,
            secondiSecondoTempo: 0,
            eventi: [],
            avviataIl: Date(),
            aggiornataIl: Date()
        )

        sessioniLocali.insert(SessioneLocaleRapportoGaraWatch(sessione: sessione), at: 0)
        ordinaSessioni()
        salvaPersistenza()
        sincronizzaSessioniSePossibile()
        messaggioStato = "Partita pronta."
    }

    func eliminaSessione(id: UUID) {
        guard let locale = sessioniLocali.first(where: { $0.id == id }) else { return }
        let chiave = locale.sessione.chiaveSessione

        ripulisciDettature(sessionIDs: [id])
        sessioniLocali.removeAll { $0.id == id }
        promptRecuperoAttivo = nil
        salvaPersistenza()
        inviaRichiestaEliminazioneSessioni([chiave])
        messaggioStato = "Sessione eliminata dal Watch."
        WKInterfaceDevice.current().play(.click)
    }

    func avviaPrimoTempo(sessionID: UUID) {
        aggiornaSessione(id: sessionID) { locale, now in
            guard locale.sessione.statoCronometro == .prepartita else { return }
            locale.faseAvviataIl = now
            locale.sessione.statoCronometro = .primoTempo
            locale.sessione.aggiornataIl = now
            oraCorrente = now
            promptRecuperoAttivo = nil
            messaggioStato = "Primo tempo avviato."
            WKInterfaceDevice.current().play(.start)
        }
    }

    func pausaFinePrimoTempo(sessionID: UUID) {
        aggiornaSessione(id: sessionID) { locale, now in
            guard locale.sessione.statoCronometro == .primoTempo
                || locale.sessione.statoCronometro == .recuperoPrimoTempo else { return }
            cristallizza(&locale, at: now)
            locale.sessione.statoCronometro = .intervallo
            locale.faseAvviataIl = nil
            locale.sessione.aggiornataIl = now
            promptRecuperoAttivo = nil
            messaggioStato = "Primo tempo in pausa."
            WKInterfaceDevice.current().play(.stop)
        }
    }

    func avviaSecondoTempo(sessionID: UUID) {
        aggiornaSessione(id: sessionID) { locale, now in
            guard locale.sessione.statoCronometro == .intervallo else { return }
            locale.sessione.statoCronometro = .secondoTempo
            locale.faseAvviataIl = now
            locale.sessione.aggiornataIl = now
            oraCorrente = now
            promptRecuperoAttivo = nil
            messaggioStato = "Secondo tempo avviato."
            WKInterfaceDevice.current().play(.start)
        }
    }

    func impostaRecupero(_ minuti: Int, sessionID: UUID) {
        aggiornaSessione(id: sessionID) { locale, now in
            let valore = max(0, minuti)

            switch locale.sessione.statoCronometro {
            case .primoTempo, .recuperoPrimoTempo:
                cristallizza(&locale, at: now)
                locale.sessione.minutiRecuperoPrimoTempo = valore
                locale.sessione.statoCronometro = .recuperoPrimoTempo
                locale.faseAvviataIl = now
                locale.haRichiestoRecuperoPrimoTempo = true
                promptRecuperoAttivo = nil
                messaggioStato = "Recupero 1T: \(valore)'"
                WKInterfaceDevice.current().play(.directionUp)
            case .secondoTempo, .recuperoSecondoTempo:
                cristallizza(&locale, at: now)
                locale.sessione.minutiRecuperoSecondoTempo = valore
                locale.sessione.statoCronometro = .recuperoSecondoTempo
                locale.faseAvviataIl = now
                locale.haRichiestoRecuperoSecondoTempo = true
                promptRecuperoAttivo = nil
                messaggioStato = "Recupero 2T: \(valore)'"
                WKInterfaceDevice.current().play(.directionUp)
            case .prepartita, .intervallo, .finale:
                break
            }

            locale.sessione.aggiornataIl = now
        }
    }

    func terminaPartita(sessionID: UUID) {
        aggiornaSessione(id: sessionID) { locale, now in
            guard locale.sessione.statoCronometro == .secondoTempo
                || locale.sessione.statoCronometro == .recuperoSecondoTempo
                || locale.sessione.statoCronometro == .intervallo else { return }
            cristallizza(&locale, at: now)
            locale.sessione.statoCronometro = .finale
            locale.faseAvviataIl = nil
            locale.sessione.aggiornataIl = now
            promptRecuperoAttivo = nil
            messaggioStato = "Rapporto gara salvato."
            WKInterfaceDevice.current().play(.success)
        }
    }

    func registraDettatura(_ testo: String, sessionID: UUID) {
        registraDettatura(testo, sessionID: sessionID, snapshot: nil, registrataIl: nil, eventID: nil)
    }

    private func registraDettatura(
        _ testo: String,
        sessionID: UUID,
        snapshot: MinutoRapportoGaraSnapshot?,
        registrataIl: Date?,
        eventID: UUID?
    ) {
        let testoPulito = testo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !testoPulito.isEmpty else { return }
        guard let index = sessioniLocali.firstIndex(where: { $0.id == sessionID }) else { return }

        var locale = sessioniLocali[index]
        let now = Date()
        cristallizza(&locale, at: now)
        let snapshotEvento = snapshot ?? CalcolatoreCronometroRapportoGara.snapshot(per: locale.sessione)
        let istanteRegistrazione = registrataIl ?? now
        let eventiPrecedenti = locale.sessione.eventi.filter {
            eventoPrecede($0, snapshot: snapshotEvento, registrataIl: istanteRegistrazione)
        }
        var evento = ParserEventoVocaleRapportoGara.interpreta(
            testo: testoPulito,
            snapshot: snapshotEvento,
            eventiPrecedenti: eventiPrecedenti,
            coloriMaglia: locale.sessione.mappaColoriMaglia,
            eventID: eventID ?? UUID()
        ) ?? EventoRapportoGara(
            id: eventID ?? UUID(),
            minuto: snapshotEvento,
            latoSquadra: nil,
            numeroMaglia: nil,
            tipoEvento: .notaLibera,
            testoDettato: testoPulito,
            origine: .voceAppleWatch,
            creatoIl: istanteRegistrazione
        )
        evento.creatoIl = istanteRegistrazione

        locale.sessione.eventi.append(evento)
        normalizzaEventiCronologici(&locale.sessione.eventi)
        locale.sessione.aggiornataIl = now
        sessioniLocali[index] = locale
        ordinaSessioni()
        salvaPersistenza()
        sincronizzaSessioniSePossibile()
        messaggioStato = labelBrevePerEvento(evento)
        WKInterfaceDevice.current().play(.success)
    }

    func avviaDettaturaDiretta(sessionID: UUID) {
        guard statoDettaturaDiretta != .ascolto else { return }
        guard sessioniLocali.contains(where: { $0.id == sessionID }) else {
            segnalaErrore("Sessione gara non trovata.")
            return
        }

        statoDettaturaDiretta = .ascolto
        messaggioStato = "Parla ora."
        WKInterfaceDevice.current().play(.start)

        if let controller = controllerVisibilePerDettatura() {
            controller.presentTextInputController(
                withSuggestions: nil,
                allowedInputMode: .plain
            ) { [weak self] results in
                DispatchQueue.main.async {
                    guard let self else { return }

                    guard self.statoDettaturaDiretta == .ascolto else { return }
                    self.statoDettaturaDiretta = .elaborazione

                    guard let testo = self.testoDettatoDaWatch(results) else {
                        self.statoDettaturaDiretta = .inattiva
                        self.messaggioStato = "Dettatura annullata."
                        return
                    }

                    self.statoDettaturaDiretta = .inattiva
                    self.registraDettatura(testo, sessionID: sessionID)
                }
            }
            return
        }

        // Fallback tecnico: se la dettatura nativa non e disponibile, uso ancora
        // la registrazione audio e la trascrizione via iPhone.
        voiceRecorder.start { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let audioData):
                self.gestisciAudioRegistrato(audioData, sessionID: sessionID)
            case .failure(let error):
                self.statoDettaturaDiretta = .inattiva
                self.segnalaErrore(error.localizedDescription)
            }
        }
    }

    func concludiDettaturaDiretta() {
        guard statoDettaturaDiretta == .ascolto else { return }
        if let controller = controllerVisibilePerDettatura() {
            controller.dismissTextInputController()
            statoDettaturaDiretta = .inattiva
            messaggioStato = "Dettatura annullata."
            return
        }

        voiceRecorder.stop()
    }

    private func ripristinaPersistenza() {
        if let data = defaults.data(forKey: Self.chiaveContestoPersistito),
           let value = try? decoder.decode(ContestoTelefonoRapportoGara.self, from: data) {
            contestoTelefono = value
        }

        if let data = defaults.data(forKey: Self.chiaveSessioniLocali),
           let value = try? decoder.decode([SessioneLocaleRapportoGaraWatch].self, from: data) {
            sessioniLocali = value.sorted { $0.sessione.aggiornataIl > $1.sessione.aggiornataIl }
        }
    }

    private func salvaPersistenza() {
        if let data = try? encoder.encode(contestoTelefono) {
            defaults.set(data, forKey: Self.chiaveContestoPersistito)
        }
        if let data = try? encoder.encode(sessioniLocali) {
            defaults.set(data, forKey: Self.chiaveSessioniLocali)
        }
    }

    private func attivaWatchConnectivitySePossibile() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        wcSession = session
        aggiornaStatoConnettivita(session)
    }

    private func aggiornaStatoConnettivita(_ session: WCSession) {
        telefonoRaggiungibile = session.isReachable
        companionAppInstallata = session.isCompanionAppInstalled
    }

    private func attivaTicker() {
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                guard let self else { return }
                oraCorrente = now
                verificaPromemoriaRecupero(alla: now)
                sincronizzaSessioneAttivaSeNecessario(alla: now)
            }
    }

    private func aggiornaSessione(id: UUID, mutation: (inout SessioneLocaleRapportoGaraWatch, Date) -> Void) {
        guard let index = sessioniLocali.firstIndex(where: { $0.id == id }) else { return }
        var locale = sessioniLocali[index]
        let now = Date()
        objectWillChange.send()
        mutation(&locale, now)
        sessioniLocali[index] = locale
        ordinaSessioni()
        pianificaPersistenzaESync()
    }

    private func pianificaPersistenzaESync() {
        persistenzaESyncWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            salvaPersistenza()
            sincronizzaSessioniSePossibile()
            persistenzaESyncWorkItem = nil
        }

        persistenzaESyncWorkItem = item
        DispatchQueue.main.async(execute: item)
    }

    private func cristallizza(_ locale: inout SessioneLocaleRapportoGaraWatch, at date: Date) {
        let faseAvviataIl = locale.faseAvviataIl
        locale.sessione = locale.sessioneRenderizzata(alla: date)

        guard locale.sessione.statoCronometro.isInCorso, let faseAvviataIl else {
            locale.faseAvviataIl = nil
            return
        }

        let elapsed = max(0, date.timeIntervalSince(faseAvviataIl))
        let residuo = elapsed - floor(elapsed)
        locale.faseAvviataIl = date.addingTimeInterval(-residuo)
    }

    private func ordinaSessioni() {
        sessioniLocali.sort { $0.sessione.aggiornataIl > $1.sessione.aggiornataIl }
    }

    private func controllerVisibilePerDettatura() -> WKInterfaceController? {
        WKApplication.shared().visibleInterfaceController
            ?? WKExtension.shared().visibleInterfaceController
    }

    private func testoDettatoDaWatch(_ results: [Any]?) -> String? {
        guard let raw = results?
            .compactMap({ result -> String? in
                if let string = result as? String {
                    return string
                }
                return (result as? NSString) as String?
            })
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        return raw
    }

    private func verificaPromemoriaRecupero(alla data: Date) {
        guard let index = sessioniLocali.firstIndex(where: { $0.sessione.statoCronometro != .finale }) else {
            promptRecuperoAttivo = nil
            return
        }

        let renderizzata = sessioniLocali[index].sessioneRenderizzata(alla: data)

        switch renderizzata.statoCronometro {
        case .primoTempo where renderizzata.secondiPrimoTempo >= 45 * 60
            && sessioniLocali[index].sessione.minutiRecuperoPrimoTempo == nil
            && !sessioniLocali[index].haRichiestoRecuperoPrimoTempo:
            sessioniLocali[index].haRichiestoRecuperoPrimoTempo = true
            promptRecuperoAttivo = .primoTempo
            messaggioStato = "Quanto recupero nel 1T?"
            salvaPersistenza()
            WKInterfaceDevice.current().play(.notification)
        case .secondoTempo where renderizzata.secondiSecondoTempo >= 45 * 60
            && sessioniLocali[index].sessione.minutiRecuperoSecondoTempo == nil
            && !sessioniLocali[index].haRichiestoRecuperoSecondoTempo:
            sessioniLocali[index].haRichiestoRecuperoSecondoTempo = true
            promptRecuperoAttivo = .secondoTempo
            messaggioStato = "Quanto recupero nel 2T?"
            salvaPersistenza()
            WKInterfaceDevice.current().play(.notification)
        case .primoTempo, .secondoTempo:
            break
        case .prepartita, .recuperoPrimoTempo, .intervallo, .recuperoSecondoTempo, .finale:
            break
        }
    }

    private func sincronizzaSessioneAttivaSeNecessario(alla data: Date) {
        guard telefonoRaggiungibile, isAbbinato, let sessioneAttiva else { return }

        switch sessioneAttiva.sessione.statoCronometro {
        case .primoTempo, .recuperoPrimoTempo, .intervallo, .secondoTempo, .recuperoSecondoTempo:
            break
        case .prepartita, .finale:
            return
        }

        let ultimoInvio = sessioneAttiva.ultimoInvioIl ?? .distantPast
        guard data.timeIntervalSince(ultimoInvio) >= Self.intervalloSyncCronometro else { return }
        sincronizzaSessioniSePossibile(referenceDate: data)
    }

    private func sincronizzaSessioniSePossibile(referenceDate: Date = Date()) {
        guard isAbbinato, let session = wcSession, !sessioniLocali.isEmpty else { return }

        let sessioniDaSincronizzare = sessioniLocali.map { $0.sessioneRenderizzata(alla: referenceDate) }

        let pacchetto = PacchettoSyncRapportoGara(
            watchIdentifier: watchIdentifier,
            watchName: nomeOrologio,
            sessions: sessioniDaSincronizzare,
            sentAt: referenceDate
        )

        guard let data = try? encoder.encode(pacchetto) else {
            segnalaErrore("Sync non riuscita.")
            return
        }

        if session.isReachable {
            session.sendMessageData(data, replyHandler: nil) { _ in }
        }

        do {
            try session.updateApplicationContext([Self.chiavePacchettoSync: data])
        } catch {
            session.transferUserInfo([Self.chiavePacchettoSync: data])
        }

        for index in sessioniLocali.indices {
            sessioniLocali[index].ultimoInvioIl = referenceDate
        }
        salvaPersistenza()
    }

    private func gestisciRispostaAbbinamento(_ data: Data) {
        if let contesto = try? decoder.decode(ContestoTelefonoRapportoGara.self, from: data) {
            ingestaContesto(contesto)
            codiceAbbinamento = ""

            if isAbbinato {
                messaggioStato = "Apple Watch collegato."
            } else {
                messaggioStato = "Codice errato o scaduto. Rigeneralo su iPhone."
                WKInterfaceDevice.current().play(.failure)
            }
            return
        }

        messaggioStato = "Richiesta inviata all'iPhone."
    }

    private func configurazioneColori(
        sessionKey: String?,
        designazioneId: String
    ) -> ConfigurazioneColoriSessioneRapportoGara? {
        let chiavePulita = sessionKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let designazionePulita = designazioneId.trimmingCharacters(in: .whitespacesAndNewlines)

        return contestoTelefono.sessionConfigurations.first { configurazione in
            if !chiavePulita.isEmpty && configurazione.sessionKey == chiavePulita {
                return true
            }
            return !designazionePulita.isEmpty && configurazione.designazioneId == designazionePulita
        }
    }

    private func applicaConfigurazioniColoriDalTelefono() -> Bool {
        var haAggiornato = false

        for index in sessioniLocali.indices {
            let sessione = sessioniLocali[index].sessione
            guard let configurazione = configurazioneColori(
                sessionKey: sessione.chiaveSessione,
                designazioneId: sessione.designazioneId
            ) else { continue }

            let nuovoCasa = configurazione.coloreMagliaCasa.trimmingCharacters(in: .whitespacesAndNewlines)
            let nuovoOspiti = configurazione.coloreMagliaOspiti.trimmingCharacters(in: .whitespacesAndNewlines)

            guard sessioniLocali[index].sessione.coloreMagliaCasa != nuovoCasa
                || sessioniLocali[index].sessione.coloreMagliaOspiti != nuovoOspiti else {
                continue
            }

            sessioniLocali[index].sessione.coloreMagliaCasa = nuovoCasa
            sessioniLocali[index].sessione.coloreMagliaOspiti = nuovoOspiti
            sessioniLocali[index].sessione.aggiornataIl = Date()
            haAggiornato = true
        }

        return haAggiornato
    }

    private func inviaRichiestaEliminazioneSessioni(_ sessionKeys: [String]) {
        let chiaviPulite = Array(
            Set(
                sessionKeys
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )

        guard isAbbinato, let session = wcSession, !chiaviPulite.isEmpty else { return }

        let richiesta = RichiestaEliminazioneSessioniRapportoGara(
            watchIdentifier: watchIdentifier,
            sessionKeys: chiaviPulite,
            requestedAt: Date()
        )

        guard let data = try? encoder.encode(richiesta) else { return }
        session.transferUserInfo([Self.chiaveRichiestaEliminazioneSessioni: data])
    }

    private func ingestaContesto(_ contesto: ContestoTelefonoRapportoGara) {
        DispatchQueue.main.async {
            self.contestoTelefono = contesto
            let sessioniDaRimuovere = self.sessioniLocali
                .filter { locale in
                    contesto.deletedSessionKeys.contains(locale.sessione.chiaveSessione)
                }
                .map(\.id)
            let sessioniPrima = self.sessioniLocali.count
            if !contesto.deletedSessionKeys.isEmpty {
                self.ripulisciDettature(sessionIDs: sessioniDaRimuovere)
                self.sessioniLocali.removeAll { locale in
                    contesto.deletedSessionKeys.contains(locale.sessione.chiaveSessione)
                }
                self.promptRecuperoAttivo = nil
            }
            let haAggiornatoColori = self.applicaConfigurazioniColoriDalTelefono()
            self.salvaPersistenza()
            let sessioniRimosse = max(0, sessioniPrima - self.sessioniLocali.count)

            if self.isAbbinato {
                self.messaggioStato = sessioniRimosse > 0
                    ? "Sessione rimossa da iPhone."
                    : (haAggiornatoColori ? "Colori maglia aggiornati." : "Apple Watch collegato.")
                self.sincronizzaSessioniSePossibile()
            }
            self.processaDettaturePendentiSePossibile()
        }
    }

    private func labelBrevePerEvento(_ evento: EventoRapportoGara) -> String {
        if evento.tipoEvento == .notaLibera {
            return "\(evento.minuto.labelMinuto) Nota salvata"
        }
        var parti: [String] = [evento.minuto.labelMinuto]
        if let squadra = evento.latoSquadra?.titoloBreve {
            parti.append(squadra)
        }
        if evento.tipoEvento == .sostituzione {
            if let numero = evento.numeroMaglia {
                parti.append("#\(numero)")
            }
            if let numeroEntrata = evento.numeroMagliaEntrata {
                parti.append("->")
                parti.append("#\(numeroEntrata)")
            }
        } else if let numero = evento.numeroMaglia {
            parti.append("#\(numero)")
        }
        parti.append(evento.tipoEvento.titoloBreve)
        return parti.joined(separator: " ")
    }

    private func gestisciAudioRegistrato(_ audioData: Data, sessionID: UUID) {
        guard let index = sessioniLocali.firstIndex(where: { $0.id == sessionID }) else {
            statoDettaturaDiretta = .inattiva
            segnalaErrore("Sessione gara non trovata.")
            return
        }

        statoDettaturaDiretta = .inattiva
        var locale = sessioniLocali[index]
        let now = Date()
        cristallizza(&locale, at: now)
        let snapshot = CalcolatoreCronometroRapportoGara.snapshot(per: locale.sessione)
        locale.sessione.aggiornataIl = now
        sessioniLocali[index] = locale
        ordinaSessioni()
        salvaPersistenza()

        guard let session = wcSession, session.isReachable else {
            accodaDettaturaPendente(
                audioData,
                sessionID: sessionID,
                snapshot: snapshot,
                registrataIl: now
            )
            return
        }

        inviaAudioPerTrascrizione(
            audioData,
            sessionID: sessionID,
            snapshot: snapshot,
            registrataIl: now,
            pendingID: nil,
            aggiornaStatoUI: true
        )
    }

    private func accodaDettaturaPendente(
        _ audioData: Data,
        sessionID: UUID,
        snapshot: MinutoRapportoGaraSnapshot,
        registrataIl: Date,
        pendingID: UUID? = nil
    ) {
        guard let index = sessioniLocali.firstIndex(where: { $0.id == sessionID }) else {
            statoDettaturaDiretta = .inattiva
            return
        }

        var locale = sessioniLocali[index]
        let dettaturaID = pendingID ?? UUID()

        if !locale.dettaturePendenti.contains(where: { $0.id == dettaturaID }) {
            locale.dettaturePendenti.append(
                DettaturaPendenteRapportoGaraWatch(
                    id: dettaturaID,
                    snapshot: snapshot,
                    registrataIl: registrataIl,
                    audioData: audioData
                )
            )
        }

        locale.sessione.aggiornataIl = Date()
        sessioniLocali[index] = locale
        ordinaSessioni()
        salvaPersistenza()
        statoDettaturaDiretta = .inattiva
        messaggioStato = telefonoRaggiungibile
            ? "Audio salvato. Lo ritento tra poco."
            : "Audio salvato sul Watch."
        WKInterfaceDevice.current().play(.success)
    }

    private func inviaAudioPerTrascrizione(
        _ audioData: Data,
        sessionID: UUID,
        snapshot: MinutoRapportoGaraSnapshot,
        registrataIl: Date,
        pendingID: UUID?,
        aggiornaStatoUI: Bool
    ) {
        guard let session = wcSession, session.isReachable else {
            if pendingID == nil {
                accodaDettaturaPendente(
                    audioData,
                    sessionID: sessionID,
                    snapshot: snapshot,
                    registrataIl: registrataIl
                )
            } else {
                statoDettaturaDiretta = .inattiva
            }
            return
        }

        let requestID = UUID()
        let richiesta = RichiestaTrascrizioneRapportoGara(
            requestID: requestID,
            sessionID: sessionID,
            watchIdentifier: watchIdentifier,
            snapshot: snapshot,
            audioData: audioData,
            requestedAt: Date()
        )

        guard let data = try? encoder.encode(richiesta) else {
            if let pendingID {
                dettaturePendentiInInvio.remove(pendingID)
                messaggioStato = "Audio ancora in attesa."
                statoDettaturaDiretta = .inattiva
            } else {
                accodaDettaturaPendente(
                    audioData,
                    sessionID: sessionID,
                    snapshot: snapshot,
                    registrataIl: registrataIl
                )
            }
            return
        }

        richiesteTrascrizioneAttive[requestID] = ContestoTrascrizioneDiretta(
            sessionID: sessionID,
            snapshot: snapshot,
            registrataIl: registrataIl,
            audioData: audioData,
            pendingID: pendingID,
            aggiornaStatoUI: aggiornaStatoUI
        )

        if let pendingID {
            dettaturePendentiInInvio.insert(pendingID)
        }

        if aggiornaStatoUI {
            messaggioStato = "Pronto per un altro evento."
        }

        session.sendMessageData(
            data,
            replyHandler: { [weak self] replyData in
                DispatchQueue.main.async {
                    self?.gestisciRispostaTrascrizione(replyData, requestID: requestID)
                }
            },
            errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    self?.gestisciErroreInvioTrascrizione(requestID: requestID, errore: error.localizedDescription)
                }
            }
        )
    }

    private func gestisciErroreInvioTrascrizione(requestID: UUID, errore: String) {
        guard let contesto = richiesteTrascrizioneAttive.removeValue(forKey: requestID) else {
            segnalaErrore(errore)
            return
        }

        if let pendingID = contesto.pendingID {
            dettaturePendentiInInvio.remove(pendingID)
            if contesto.aggiornaStatoUI {
                statoDettaturaDiretta = .inattiva
            }
            messaggioStato = "Audio ancora in attesa."
            return
        }

        accodaDettaturaPendente(
            contesto.audioData,
            sessionID: contesto.sessionID,
            snapshot: contesto.snapshot,
            registrataIl: contesto.registrataIl
        )
    }

    private func gestisciRispostaTrascrizione(_ data: Data, requestID: UUID) {
        if let risposta = try? decoder.decode(RispostaTrascrizioneRapportoGara.self, from: data) {
            gestisciRispostaTrascrizioneDecodificata(risposta, requestID: requestID)
            return
        }

        let contesto = richiesteTrascrizioneAttive.removeValue(forKey: requestID)
        if let pendingID = contesto?.pendingID {
            dettaturePendentiInInvio.remove(pendingID)
            messaggioStato = "Audio ancora in attesa."
            return
        }

        segnalaErrore("Risposta voce non valida.")
    }

    private func gestisciRispostaTrascrizioneDecodificata(
        _ risposta: RispostaTrascrizioneRapportoGara,
        requestID: UUID
    ) {
        let contesto = richiesteTrascrizioneAttive.removeValue(forKey: requestID)
        if let pendingID = contesto?.pendingID {
            dettaturePendentiInInvio.remove(pendingID)
        }

        if contesto?.aggiornaStatoUI == true {
            statoDettaturaDiretta = .inattiva
        }

        if let errore = risposta.errore, !errore.isEmpty {
            gestisciErroreRispostaTrascrizione(errore, contesto: contesto, sessionID: risposta.sessionID)
            return
        }

        guard let testo = risposta.testo?.trimmingCharacters(in: .whitespacesAndNewlines),
              !testo.isEmpty else {
            gestisciErroreRispostaTrascrizione("Non ho capito la frase.", contesto: contesto, sessionID: risposta.sessionID)
            return
        }

        registraDettatura(
            testo,
            sessionID: contesto?.sessionID ?? risposta.sessionID,
            snapshot: contesto?.snapshot,
            registrataIl: contesto?.registrataIl,
            eventID: risposta.requestID
        )

        if let pendingID = contesto?.pendingID {
            rimuoviDettaturaPendente(id: pendingID, sessionID: contesto?.sessionID ?? risposta.sessionID)
            processaDettaturePendentiSePossibile()
        }
    }

    private func gestisciErroreRispostaTrascrizione(
        _ errore: String,
        contesto: ContestoTrascrizioneDiretta?,
        sessionID: UUID
    ) {
        guard let contesto else {
            segnalaErrore(errore)
            return
        }

        if let pendingID = contesto.pendingID {
            dettaturePendentiInInvio.remove(pendingID)
            messaggioStato = "Audio ancora in attesa."
            return
        }

        accodaDettaturaPendente(
            contesto.audioData,
            sessionID: sessionID,
            snapshot: contesto.snapshot,
            registrataIl: contesto.registrataIl
        )
    }

    private func rimuoviDettaturaPendente(id: UUID, sessionID: UUID) {
        guard let index = sessioniLocali.firstIndex(where: { $0.id == sessionID }) else { return }
        var locale = sessioniLocali[index]
        locale.dettaturePendenti.removeAll { $0.id == id }
        sessioniLocali[index] = locale
        salvaPersistenza()
    }

    private func ripulisciDettature(sessionIDs: [UUID]) {
        let sessioniDaPulire = Set(sessionIDs)
        guard !sessioniDaPulire.isEmpty else { return }

        let dettatureDaRimuovere = richiesteTrascrizioneAttive.values.compactMap { contesto in
            sessioniDaPulire.contains(contesto.sessionID) ? contesto.pendingID : nil
        }

        for pendingID in dettatureDaRimuovere {
            dettaturePendentiInInvio.remove(pendingID)
        }

        richiesteTrascrizioneAttive = richiesteTrascrizioneAttive.filter { _, contesto in
            !sessioniDaPulire.contains(contesto.sessionID)
        }
    }

    private func processaDettaturePendentiSePossibile() {
        guard statoDettaturaDiretta != .ascolto,
              let session = wcSession,
              session.isReachable else { return }

        for locale in sessioniLocali {
            guard let pending = locale.dettaturePendenti.first(where: { !dettaturePendentiInInvio.contains($0.id) }) else {
                continue
            }

            inviaAudioPerTrascrizione(
                pending.audioData,
                sessionID: locale.id,
                snapshot: pending.snapshot,
                registrataIl: pending.registrataIl,
                pendingID: pending.id,
                aggiornaStatoUI: false
            )
            return
        }
    }

    private func eventoPrecede(
        _ evento: EventoRapportoGara,
        snapshot: MinutoRapportoGaraSnapshot,
        registrataIl: Date
    ) -> Bool {
        if evento.minuto.secondiCronometro != snapshot.secondiCronometro {
            return evento.minuto.secondiCronometro < snapshot.secondiCronometro
        }
        return evento.creatoIl <= registrataIl
    }

    private func normalizzaEventiCronologici(_ eventi: inout [EventoRapportoGara]) {
        let ordinati = eventi.enumerated().sorted { sinistra, destra in
            if sinistra.element.minuto.secondiCronometro == destra.element.minuto.secondiCronometro {
                return sinistra.element.creatoIl < destra.element.creatoIl
            }
            return sinistra.element.minuto.secondiCronometro < destra.element.minuto.secondiCronometro
        }

        var ammoniti: Set<ChiaveGiocatore> = []
        var espulsi: Set<ChiaveGiocatore> = []

        for voce in ordinati {
            guard let latoSquadra = voce.element.latoSquadra,
                  let numeroMaglia = voce.element.numeroMaglia else {
                continue
            }

            let chiave = ChiaveGiocatore(latoSquadra: latoSquadra, numeroMaglia: numeroMaglia)

            switch voce.element.tipoEvento {
            case .ammonizione:
                if ammoniti.contains(chiave), !espulsi.contains(chiave) {
                    eventi[voce.offset].tipoEvento = .doppioGialloRosso
                    espulsi.insert(chiave)
                } else {
                    eventi[voce.offset].tipoEvento = .ammonizione
                    ammoniti.insert(chiave)
                }
            case .doppioGialloRosso:
                ammoniti.insert(chiave)
                espulsi.insert(chiave)
            case .espulsione:
                espulsi.insert(chiave)
            case .gol, .sostituzione:
                break
            case .notaLibera:
                break
            }
        }
    }

    private func segnalaErrore(_ messaggio: String) {
        statoDettaturaDiretta = .inattiva
        messaggioStato = messaggio
        WKInterfaceDevice.current().play(.failure)
    }
}

extension RapportoGaraWatchStore: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.aggiornaStatoConnettivita(session)

            if let data = session.receivedApplicationContext[Self.chiaveContestoTelefono] as? Data,
               let contesto = try? self.decoder.decode(ContestoTelefonoRapportoGara.self, from: data) {
                self.ingestaContesto(contesto)
            }

            if let error {
                self.messaggioStato = error.localizedDescription
            } else {
                self.processaDettaturePendentiSePossibile()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.aggiornaStatoConnettivita(session)
            if session.isReachable {
                self.sincronizzaSessioniSePossibile()
                self.processaDettaturePendentiSePossibile()
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext[Self.chiaveContestoTelefono] as? Data,
           let contesto = try? decoder.decode(ContestoTelefonoRapportoGara.self, from: data) {
            ingestaContesto(contesto)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let data = userInfo[Self.chiaveContestoTelefono] as? Data,
           let contesto = try? decoder.decode(ContestoTelefonoRapportoGara.self, from: data) {
            ingestaContesto(contesto)
        }
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        if let contesto = try? decoder.decode(ContestoTelefonoRapportoGara.self, from: messageData) {
            ingestaContesto(contesto)
        }
    }
}
