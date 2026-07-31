import Combine
import Foundation
import WatchConnectivity

final class RapportoGaraStore: NSObject, ObservableObject {
    static let shared = RapportoGaraStore()

    @Published private(set) var abbinamenti: [AppleWatchAbbinatoRapportoGara] = []
    @Published private(set) var sessioni: [SessioneRapportoGara] = []
    @Published private(set) var registrazioniAudio: [RegistrazioneAudioRapportoGara] = []
    @Published private(set) var refertiDisponibili: [RefertoDisponibileRapportoGara] = []
    @Published private(set) var codiceVerificaAttivo: CodiceVerificaRapportoGara?
    @Published private(set) var watchRaggiungibile = false
    @Published private(set) var watchAppInstallata = false
    @Published var ultimoMessaggio = ""
    @Published private(set) var sessioniEliminate: [String] = []

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager = FileManager.default
    private var wcSession: WCSession?

    private static let chiaveAbbinamenti = "sinfonia4you.rapportogara.watchpairings.v1"
    private static let chiaveSessioni = "sinfonia4you.rapportogara.sessions.v1"
    private static let chiaveRegistrazioniAudio = "sinfonia4you.rapportogara.audioarchive.v1"
    private static let chiaveSessioniEliminate = "sinfonia4you.rapportogara.deletedsessions.v1"
    private static let chiaveCodice = "sinfonia4you.rapportogara.verificationcode.v1"
    private static let chiaveRefertiDisponibili = "sinfonia4you.rapportogara.availablematches.v1"
    private static let chiaveContestoTelefono = "sinfonia4you.rapportogara.phone.context"
    private static let chiaveRichiestaAbbinamento = "sinfonia4you.rapportogara.pairing.request"
    private static let chiaveRichiestaEliminazioneSessioni = "sinfonia4you.rapportogara.delete.request"
    private static let chiavePacchettoSync = "sinfonia4you.rapportogara.sync.payload"
    private static let directoryArchivioAudio = "RapportoGaraAudio"
    private static let directoryArchivioDistinte = "RapportoGaraDistinte"

    private override init() {
        super.init()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        ripristinaPersistenza()
        RapportoGaraSpeechTranscriber.ripulisciFileTemporaneiResidui()
        ripulisciRegistrazioniAudioInesistenti()
        attivaWatchConnectivitySePossibile()
    }

    func generaCodiceVerifica() {
        let codice = String(format: "%06d", Int.random(in: 0...999_999))
        codiceVerificaAttivo = CodiceVerificaRapportoGara(
            codice: codice,
            generatoIl: Date(),
            scadeIl: Date().addingTimeInterval(5 * 60)
        )
        salvaPersistenza()
        aggiornaContestoWatch()
    }

    func ripulisciCodiceSeScaduto(referenceDate: Date = Date()) {
        guard let codiceVerificaAttivo, !codiceVerificaAttivo.isValido(at: referenceDate) else { return }
        self.codiceVerificaAttivo = nil
        salvaPersistenza()
        aggiornaContestoWatch()
    }

    func sessione(per id: UUID) -> SessioneRapportoGara? {
        sessioni.first(where: { $0.id == id })
    }

    func registrazioniAudio(per sessionID: UUID) -> [RegistrazioneAudioRapportoGara] {
        registrazioniAudio
            .filter { $0.sessionID == sessionID }
            .sorted { $0.creatoIl > $1.creatoIl }
    }

    func distinta(per sessionID: UUID, lato: LatoSquadraRapportoGara) -> DistintaSquadraRapportoGara? {
        sessione(per: sessionID)?.distinte.slot(for: lato)
    }

    func urlRegistrazioneAudio(per registrazione: RegistrazioneAudioRapportoGara) -> URL? {
        guard let directoryURL = directoryArchivioAudioURL() else { return nil }
        let fileURL = directoryURL.appendingPathComponent(registrazione.fileName)
        return fileManager.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    func urlImmagineDistinta(per sessionID: UUID, lato: LatoSquadraRapportoGara) -> URL? {
        guard let sourceImage = distinta(per: sessionID, lato: lato)?.sourceImage else { return nil }
        return urlImmagineDistinta(sessionID: sessionID, fileName: sourceImage.fileName)
    }

    func eliminaSessione(id: UUID) {
        guard let sessione = sessione(per: id) else { return }
        eliminaSessioni(conChiavi: [sessione.chiaveSessione], messaggio: "Sessione eliminata da iPhone.")
    }

    func eliminaRegistrazioneAudio(id: UUID) {
        guard let registrazione = registrazioniAudio.first(where: { $0.id == id }) else { return }
        if let fileURL = urlRegistrazioneAudio(per: registrazione) {
            try? fileManager.removeItem(at: fileURL)
        }
        registrazioniAudio.removeAll { $0.id == id }
        salvaPersistenza()
    }

    func aggiornaColoriMaglia(sessionID: UUID, coloreCasa: String, coloreOspiti: String) {
        guard let index = sessioni.firstIndex(where: { $0.id == sessionID }) else { return }

        let valoreCasa = coloreCasa.trimmingCharacters(in: .whitespacesAndNewlines)
        let valoreOspiti = coloreOspiti.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sessioni[index].coloreMagliaCasa != valoreCasa || sessioni[index].coloreMagliaOspiti != valoreOspiti else {
            return
        }

        sessioni[index].coloreMagliaCasa = valoreCasa
        sessioni[index].coloreMagliaOspiti = valoreOspiti
        sessioni[index].aggiornataIl = Date()
        salvaPersistenza()
        aggiornaContestoWatch()
    }

    @discardableResult
    func preparaElaborazioneDistinta(
        sessionID: UUID,
        lato: LatoSquadraRapportoGara,
        imageData: Data,
        pixelWidth: Int,
        pixelHeight: Int,
        capturedAt: Date = Date()
    ) -> DistintaSourceImageRapportoGara? {
        guard let index = sessioni.firstIndex(where: { $0.id == sessionID }),
              let directoryURL = directoryArchivioDistinteURL() else {
            return nil
        }

        let slotPrecedente = sessioni[index].distinte.slot(for: lato)
        if let fileName = slotPrecedente?.sourceImage?.fileName {
            let fileURL = directoryURL.appendingPathComponent(fileName)
            try? fileManager.removeItem(at: fileURL)
        }

        let fileName = "\(sessionID.uuidString.lowercased())-\(lato.rawValue)-\(UUID().uuidString.lowercased()).jpg"
        let fileURL = directoryURL.appendingPathComponent(fileName)

        do {
            try imageData.write(to: fileURL, options: .atomic)
        } catch {
            ultimoMessaggio = "Non riesco ad archiviare l'immagine della distinta sul telefono."
            return nil
        }

        let sourceImage = DistintaSourceImageRapportoGara(
            fileName: fileName,
            importedAt: capturedAt,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        )

        var distinta = slotPrecedente ?? DistintaSquadraRapportoGara()
        distinta.processingState = .processing
        distinta.sourceImage = sourceImage
        distinta.lastProcessedAt = capturedAt
        distinta.lastErrorMessage = ""
        distinta.issues = []

        sessioni[index].distinte.set(distinta, for: lato)
        sessioni[index].aggiornataIl = capturedAt
        ordinaSessioni()
        salvaPersistenza()
        return sourceImage
    }

    func salvaRisultatoDistinta(
        sessionID: UUID,
        lato: LatoSquadraRapportoGara,
        result: RapportoGaraDistintaParsingResult,
        sourceImage: DistintaSourceImageRapportoGara
    ) {
        guard let index = sessioni.firstIndex(where: { $0.id == sessionID }) else { return }

        let distinta = DistintaSquadraRapportoGara(
            processingState: result.processingState,
            sourceImage: sourceImage,
            teamLabelOCR: result.teamLabelOCR,
            lastProcessedAt: Date(),
            players: result.players,
            staff: result.staff,
            issues: result.issues,
            lastErrorMessage: result.errorMessage
        )

        sessioni[index].distinte.set(distinta, for: lato)
        sessioni[index].aggiornataIl = Date()
        ordinaSessioni()
        salvaPersistenza()
    }

    func aggiornaDistinta(
        sessionID: UUID,
        lato: LatoSquadraRapportoGara,
        distinta: DistintaSquadraRapportoGara
    ) {
        guard let index = sessioni.firstIndex(where: { $0.id == sessionID }) else { return }
        sessioni[index].distinte.set(distinta, for: lato)
        sessioni[index].aggiornataIl = Date()
        ordinaSessioni()
        salvaPersistenza()
    }

    func reimpostaDistintaInElaborazione(sessionID: UUID, lato: LatoSquadraRapportoGara) {
        guard let index = sessioni.firstIndex(where: { $0.id == sessionID }),
              var distinta = sessioni[index].distinte.slot(for: lato) else {
            return
        }

        distinta.processingState = .processing
        distinta.lastProcessedAt = Date()
        distinta.lastErrorMessage = ""
        sessioni[index].distinte.set(distinta, for: lato)
        sessioni[index].aggiornataIl = Date()
        ordinaSessioni()
        salvaPersistenza()
    }

    func eliminaDistinta(sessionID: UUID, lato: LatoSquadraRapportoGara) {
        guard let index = sessioni.firstIndex(where: { $0.id == sessionID }) else { return }

        if let sourceImage = sessioni[index].distinte.slot(for: lato)?.sourceImage,
           let fileURL = urlImmagineDistinta(sessionID: sessionID, fileName: sourceImage.fileName) {
            try? fileManager.removeItem(at: fileURL)
        }

        sessioni[index].distinte.set(nil, for: lato)
        sessioni[index].aggiornataIl = Date()
        ordinaSessioni()
        salvaPersistenza()
    }

    func aggiornaEvento(sessionID: UUID, eventoAggiornato: EventoRapportoGara) {
        guard let sessionIndex = sessioni.firstIndex(where: { $0.id == sessionID }) else { return }
        guard let eventIndex = sessioni[sessionIndex].eventi.firstIndex(where: { $0.id == eventoAggiornato.id }) else { return }

        sessioni[sessionIndex].eventi[eventIndex] = eventoAggiornato
        sessioni[sessionIndex].aggiornataIl = Date()
        ordinaSessioni()
        salvaPersistenza()
    }

    func eliminaEvento(sessionID: UUID, eventID: UUID) {
        guard let sessionIndex = sessioni.firstIndex(where: { $0.id == sessionID }) else { return }

        let originalCount = sessioni[sessionIndex].eventi.count
        sessioni[sessionIndex].eventi.removeAll { $0.id == eventID }
        guard sessioni[sessionIndex].eventi.count != originalCount else { return }

        sessioni[sessionIndex].aggiornataIl = Date()
        ordinaSessioni()
        salvaPersistenza()
    }

    func aggiornaRefertiDisponibili(_ rows: [RigaModuloDTO]) {
        let aggiornati = rows.map {
            RefertoDisponibileRapportoGara(
                designazioneId: $0.id,
                titolo: $0.title,
                sottotitolo: $0.subtitle,
                ruoloLabel: $0.roleLabel ?? ""
            )
        }

        guard aggiornati != refertiDisponibili else { return }
        refertiDisponibili = aggiornati
        salvaPersistenza()
        aggiornaContestoWatch()
    }

    private func ripristinaPersistenza() {
        if let data = defaults.data(forKey: Self.chiaveAbbinamenti),
           let value = try? decoder.decode([AppleWatchAbbinatoRapportoGara].self, from: data) {
            abbinamenti = value
        }

        if let data = defaults.data(forKey: Self.chiaveSessioni),
           let value = try? decoder.decode([SessioneRapportoGara].self, from: data) {
            sessioni = value.sorted(by: { $0.aggiornataIl > $1.aggiornataIl })
        }

        if let data = defaults.data(forKey: Self.chiaveRegistrazioniAudio),
           let value = try? decoder.decode([RegistrazioneAudioRapportoGara].self, from: data) {
            registrazioniAudio = value.sorted(by: { $0.creatoIl > $1.creatoIl })
        }

        if let data = defaults.data(forKey: Self.chiaveRefertiDisponibili),
           let value = try? decoder.decode([RefertoDisponibileRapportoGara].self, from: data) {
            refertiDisponibili = value
        }

        if let values = defaults.array(forKey: Self.chiaveSessioniEliminate) as? [String] {
            sessioniEliminate = values
        }

        if let data = defaults.data(forKey: Self.chiaveCodice),
           let value = try? decoder.decode(CodiceVerificaRapportoGara.self, from: data),
           value.isValido {
            codiceVerificaAttivo = value
        }
    }

    private func salvaPersistenza() {
        if let data = try? encoder.encode(abbinamenti) {
            defaults.set(data, forKey: Self.chiaveAbbinamenti)
        }
        if let data = try? encoder.encode(sessioni) {
            defaults.set(data, forKey: Self.chiaveSessioni)
        }
        if let data = try? encoder.encode(registrazioniAudio) {
            defaults.set(data, forKey: Self.chiaveRegistrazioniAudio)
        }
        if let data = try? encoder.encode(refertiDisponibili) {
            defaults.set(data, forKey: Self.chiaveRefertiDisponibili)
        }
        defaults.set(sessioniEliminate, forKey: Self.chiaveSessioniEliminate)
        if let codiceVerificaAttivo,
           let data = try? encoder.encode(codiceVerificaAttivo) {
            defaults.set(data, forKey: Self.chiaveCodice)
        } else {
            defaults.removeObject(forKey: Self.chiaveCodice)
        }
    }

    private func attivaWatchConnectivitySePossibile() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        wcSession = session
        aggiornaStatoWatch(session)
    }

    private func aggiornaStatoWatch(_ session: WCSession) {
        watchRaggiungibile = session.isReachable
        watchAppInstallata = session.isWatchAppInstalled
    }

    private func aggiornaContestoWatch() {
        guard let session = wcSession else { return }

        guard let data = codificaContestoTelefono() else { return }

        if session.isReachable {
            session.sendMessageData(data, replyHandler: nil) { _ in }
        }

        do {
            try session.updateApplicationContext([Self.chiaveContestoTelefono: data])
        } catch {
            session.transferUserInfo([Self.chiaveContestoTelefono: data])
        }
    }

    private func contestoTelefonoCorrente() -> ContestoTelefonoRapportoGara {
        ContestoTelefonoRapportoGara(
            verificationCode: codiceVerificaAttivo?.codice,
            verificationExpiresAt: codiceVerificaAttivo?.scadeIl,
            pairedWatchIDs: abbinamenti.map(\.watchIdentifier),
            availableMatches: refertiDisponibiliPerWatch(),
            deletedSessionKeys: sessioniEliminate,
            sessionConfigurations: configurazioniSessioni()
        )
    }

    private func codificaContestoTelefono() -> Data? {
        try? encoder.encode(contestoTelefonoCorrente())
    }

    private func gestisciRichiestaAbbinamento(_ richiesta: RichiestaAbbinamentoRapportoGara) {
        ripulisciCodiceSeScaduto()

        guard let codiceVerificaAttivo, codiceVerificaAttivo.isValido else {
            ultimoMessaggio = "Genera un nuovo codice di verifica prima di collegare Apple Watch."
            return
        }

        guard richiesta.verificationCode == codiceVerificaAttivo.codice else {
            ultimoMessaggio = "Il codice inserito su Apple Watch non coincide con quello attivo."
            return
        }

        if let index = abbinamenti.firstIndex(where: { $0.watchIdentifier == richiesta.watchIdentifier }) {
            abbinamenti[index].watchName = richiesta.watchName
            abbinamenti[index].ultimoSyncIl = Date()
        } else {
            abbinamenti.append(
                AppleWatchAbbinatoRapportoGara(
                    watchIdentifier: richiesta.watchIdentifier,
                    watchName: richiesta.watchName,
                    ultimoSyncIl: Date()
                )
            )
        }

        ultimoMessaggio = "Apple Watch \(richiesta.watchName) collegato con successo."
        self.codiceVerificaAttivo = nil
        salvaPersistenza()
        aggiornaContestoWatch()
    }

    private func gestisciPacchettoSync(_ pacchetto: PacchettoSyncRapportoGara) {
        var modificataAlmenoUnaSessione = false

        for sessione in pacchetto.sessions {
            guard !sessioniEliminate.contains(sessione.chiaveSessione) else { continue }
            let marcataComeSincronizzata = SessioneRapportoGara(
                id: sessione.id,
                sessionId: sessione.sessionId,
                designazioneId: sessione.designazioneId,
                titoloGara: sessione.titoloGara,
                dataGara: sessione.dataGara,
                ruoloLabel: sessione.ruoloLabel,
                nomeOrologio: pacchetto.watchName.isEmpty ? sessione.nomeOrologio : pacchetto.watchName,
                coloreMagliaCasa: sessione.coloreMagliaCasa,
                coloreMagliaOspiti: sessione.coloreMagliaOspiti,
                statoCronometro: sessione.statoCronometro,
                secondiPrimoTempo: sessione.secondiPrimoTempo,
                secondiSecondoTempo: sessione.secondiSecondoTempo,
                minutiRecuperoPrimoTempo: sessione.minutiRecuperoPrimoTempo,
                minutiRecuperoSecondoTempo: sessione.minutiRecuperoSecondoTempo,
                eventi: sessione.eventi,
                distinte: sessione.distinte,
                avviataIl: sessione.avviataIl,
                aggiornataIl: max(sessione.aggiornataIl, pacchetto.sentAt),
                sincronizzataIl: pacchetto.sentAt
            )

            unisciSessioneRicevuta(marcataComeSincronizzata)
            modificataAlmenoUnaSessione = true
        }

        if let index = abbinamenti.firstIndex(where: { $0.watchIdentifier == pacchetto.watchIdentifier }) {
            abbinamenti[index].watchName = pacchetto.watchName
            abbinamenti[index].ultimoSyncIl = pacchetto.sentAt
        } else {
            abbinamenti.append(
                AppleWatchAbbinatoRapportoGara(
                    watchIdentifier: pacchetto.watchIdentifier,
                    watchName: pacchetto.watchName,
                    ultimoSyncIl: pacchetto.sentAt
                )
            )
        }

        if modificataAlmenoUnaSessione {
            ultimoMessaggio = "Sincronizzate \(pacchetto.sessions.count) sessioni da \(pacchetto.watchName)."
            salvaPersistenza()
            aggiornaContestoWatch()
        }
    }

    private func refertiDisponibiliPerWatch() -> [RefertoDisponibileRapportoGara] {
        let designazioniGiaGestite = Set(
            sessioni
                .map(\.designazioneId)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        return Array(
            refertiDisponibili
                .filter { !designazioniGiaGestite.contains($0.designazioneId.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .prefix(1)
        )
    }

    private func configurazioniSessioni() -> [ConfigurazioneColoriSessioneRapportoGara] {
        sessioni.compactMap { sessione in
            let coloreCasa = sessione.coloreMagliaCasa.trimmingCharacters(in: .whitespacesAndNewlines)
            let coloreOspiti = sessione.coloreMagliaOspiti.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !coloreCasa.isEmpty || !coloreOspiti.isEmpty else { return nil }

            return ConfigurazioneColoriSessioneRapportoGara(
                sessionKey: sessione.chiaveSessione,
                designazioneId: sessione.designazioneId,
                coloreMagliaCasa: coloreCasa,
                coloreMagliaOspiti: coloreOspiti
            )
        }
    }

    private func gestisciRichiestaEliminazioneSessioni(_ richiesta: RichiestaEliminazioneSessioniRapportoGara) {
        eliminaSessioni(
            conChiavi: richiesta.sessionKeys,
            messaggio: "Sessioni eliminate da \(richiesta.watchIdentifier)."
        )
    }

    private func eliminaSessioni(conChiavi chiavi: [String], messaggio: String) {
        let chiaviPulite = Array(
            Set(
                chiavi
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )

        guard !chiaviPulite.isEmpty else { return }

        let sessioniDaEliminare = sessioni.filter { chiaviPulite.contains($0.chiaveSessione) }
        ripulisciArchivioAudio(sessionIDs: Set(sessioniDaEliminare.map(\.id)))
        ripulisciArchivioDistinte(sessionIDs: Set(sessioniDaEliminare.map(\.id)))
        sessioni.removeAll { chiaviPulite.contains($0.chiaveSessione) }
        sessioniEliminate = Array(Set(sessioniEliminate + chiaviPulite)).sorted()
        ultimoMessaggio = messaggio
        salvaPersistenza()
        aggiornaContestoWatch()
    }

    private func unisciSessioneRicevuta(_ incoming: SessioneRapportoGara) {
        if let index = sessioni.firstIndex(where: { $0.chiaveSessione == incoming.chiaveSessione }) {
            sessioni[index] = sessioni[index].merging(with: incoming)
        } else {
            sessioni.append(incoming)
        }

        ordinaSessioni()
    }

    private func ordinaSessioni() {
        sessioni.sort { left, right in
            if left.aggiornataIl == right.aggiornataIl {
                return left.avviataIl > right.avviataIl
            }
            return left.aggiornataIl > right.aggiornataIl
        }
    }

    private func decodifica<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? decoder.decode(type, from: data)
    }

    private func codificaRispostaTrascrizione(
        requestID: UUID,
        sessionID: UUID,
        testo: String? = nil,
        errore: String? = nil
    ) -> Data? {
        let risposta = RispostaTrascrizioneRapportoGara(
            requestID: requestID,
            sessionID: sessionID,
            testo: testo,
            errore: errore,
            repliedAt: Date()
        )

        return try? encoder.encode(risposta)
    }

    private func directoryArchivioAudioURL() -> URL? {
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directoryURL = baseURL.appendingPathComponent(Self.directoryArchivioAudio, isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        return directoryURL
    }

    private func directoryArchivioDistinteURL() -> URL? {
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directoryURL = baseURL.appendingPathComponent(Self.directoryArchivioDistinte, isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        return directoryURL
    }

    private func urlImmagineDistinta(sessionID: UUID, fileName: String) -> URL? {
        guard !fileName.isEmpty,
              let directoryURL = directoryArchivioDistinteURL() else {
            return nil
        }

        let fileURL = directoryURL.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    private func archiviaAudioRicevuto(_ richiesta: RichiestaTrascrizioneRapportoGara) {
        if registrazioniAudio.contains(where: { $0.requestID == richiesta.requestID }) {
            return
        }

        guard let directoryURL = directoryArchivioAudioURL() else { return }

        let fileName = "\(richiesta.sessionID.uuidString)-\(richiesta.requestID.uuidString).m4a"
        let fileURL = directoryURL.appendingPathComponent(fileName)

        do {
            try richiesta.audioData.write(to: fileURL, options: .atomic)
            registrazioniAudio.insert(
                RegistrazioneAudioRapportoGara(
                    sessionID: richiesta.sessionID,
                    requestID: richiesta.requestID,
                    snapshot: richiesta.snapshot,
                    fileName: fileName,
                    creatoIl: richiesta.requestedAt,
                    byteCount: richiesta.audioData.count
                ),
                at: 0
            )
            salvaPersistenza()
        } catch {
            ultimoMessaggio = "Audio ricevuto ma non archiviato su iPhone."
        }
    }

    private func aggiornaRegistrazioneAudio(
        requestID: UUID,
        testo: String? = nil,
        errore: String? = nil
    ) {
        guard let index = registrazioniAudio.firstIndex(where: { $0.requestID == requestID }) else { return }

        registrazioniAudio[index].testoTrascritto = testo?.trimmingCharacters(in: .whitespacesAndNewlines)
        registrazioniAudio[index].ultimoErrore = errore?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let errore, !errore.isEmpty {
            registrazioniAudio[index].stato = .errore
        } else if let testo, !testo.isEmpty {
            registrazioniAudio[index].stato = .trascritta
        } else {
            registrazioniAudio[index].stato = .inAttesa
        }
        salvaPersistenza()
    }

    private func ripulisciArchivioAudio(sessionIDs: Set<UUID>) {
        guard !sessionIDs.isEmpty else { return }

        let registrazioniDaEliminare = registrazioniAudio.filter { sessionIDs.contains($0.sessionID) }
        for registrazione in registrazioniDaEliminare {
            if let fileURL = urlRegistrazioneAudio(per: registrazione) {
                try? fileManager.removeItem(at: fileURL)
            }
        }

        registrazioniAudio.removeAll { sessionIDs.contains($0.sessionID) }
    }

    private func ripulisciArchivioDistinte(sessionIDs: Set<UUID>) {
        guard !sessionIDs.isEmpty else { return }

        for sessionID in sessionIDs {
            for lato in LatoSquadraRapportoGara.allCases {
                guard let sourceImage = sessioni.first(where: { $0.id == sessionID })?.distinte.slot(for: lato)?.sourceImage,
                      let fileURL = urlImmagineDistinta(sessionID: sessionID, fileName: sourceImage.fileName) else {
                    continue
                }
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    private func ripulisciRegistrazioniAudioInesistenti() {
        let registrazioniValide = registrazioniAudio.filter { urlRegistrazioneAudio(per: $0) != nil }
        guard registrazioniValide.count != registrazioniAudio.count else { return }
        registrazioniAudio = registrazioniValide.sorted(by: { $0.creatoIl > $1.creatoIl })
        salvaPersistenza()
    }
}

extension RapportoGaraStore: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.aggiornaStatoWatch(session)
            if let data = session.receivedApplicationContext[Self.chiavePacchettoSync] as? Data,
               let pacchetto = self.decodifica(PacchettoSyncRapportoGara.self, from: data) {
                self.gestisciPacchettoSync(pacchetto)
            }
            if let error {
                self.ultimoMessaggio = error.localizedDescription
            } else {
                self.aggiornaContestoWatch()
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.aggiornaStatoWatch(session)
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.aggiornaStatoWatch(session)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async {
            if let data = userInfo[Self.chiaveRichiestaAbbinamento] as? Data,
               let richiesta = self.decodifica(RichiestaAbbinamentoRapportoGara.self, from: data) {
                self.gestisciRichiestaAbbinamento(richiesta)
            }

            if let data = userInfo[Self.chiaveRichiestaEliminazioneSessioni] as? Data,
               let richiesta = self.decodifica(RichiestaEliminazioneSessioniRapportoGara.self, from: data) {
                self.gestisciRichiestaEliminazioneSessioni(richiesta)
            }

            if let data = userInfo[Self.chiavePacchettoSync] as? Data,
               let pacchetto = self.decodifica(PacchettoSyncRapportoGara.self, from: data) {
                self.gestisciPacchettoSync(pacchetto)
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            if let data = applicationContext[Self.chiavePacchettoSync] as? Data,
               let pacchetto = self.decodifica(PacchettoSyncRapportoGara.self, from: data) {
                self.gestisciPacchettoSync(pacchetto)
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        DispatchQueue.main.async {
            if let richiesta = self.decodifica(RichiestaAbbinamentoRapportoGara.self, from: messageData) {
                self.gestisciRichiestaAbbinamento(richiesta)
                return
            }

            if let pacchetto = self.decodifica(PacchettoSyncRapportoGara.self, from: messageData) {
                self.gestisciPacchettoSync(pacchetto)
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        if let richiesta = decodifica(RichiestaAbbinamentoRapportoGara.self, from: messageData) {
            DispatchQueue.main.async {
                self.gestisciRichiestaAbbinamento(richiesta)
                replyHandler(self.codificaContestoTelefono() ?? Data())
            }
            return
        }

        if let richiesta = decodifica(RichiestaTrascrizioneRapportoGara.self, from: messageData) {
            Task {
                await MainActor.run {
                    self.archiviaAudioRicevuto(richiesta)
                }

                do {
                    let testo = try await RapportoGaraSpeechTranscriber.trascrivi(audioData: richiesta.audioData)
                    await MainActor.run {
                        self.aggiornaRegistrazioneAudio(requestID: richiesta.requestID, testo: testo)
                    }
                    let payload = self.codificaRispostaTrascrizione(
                        requestID: richiesta.requestID,
                        sessionID: richiesta.sessionID,
                        testo: testo
                    )
                    replyHandler(payload ?? Data())
                } catch {
                    await MainActor.run {
                        self.aggiornaRegistrazioneAudio(
                            requestID: richiesta.requestID,
                            errore: error.localizedDescription
                        )
                    }
                    let payload = self.codificaRispostaTrascrizione(
                        requestID: richiesta.requestID,
                        sessionID: richiesta.sessionID,
                        errore: error.localizedDescription
                    )
                    replyHandler(payload ?? Data())
                }
            }
            return
        }

        replyHandler(Data())
    }
}
