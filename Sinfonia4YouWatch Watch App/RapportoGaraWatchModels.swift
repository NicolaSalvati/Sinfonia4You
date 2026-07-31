import Foundation

enum LatoSquadraRapportoGara: String, Codable, CaseIterable, Identifiable {
    case casa
    case ospiti

    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .casa:
            return "Casa"
        case .ospiti:
            return "Ospiti"
        }
    }

    var titoloBreve: String {
        switch self {
        case .casa:
            return "CAS"
        case .ospiti:
            return "OSP"
        }
    }
}

enum TipoEventoRapportoGara: String, Codable, CaseIterable, Identifiable {
    case ammonizione
    case espulsione
    case doppioGialloRosso
    case gol
    case sostituzione
    case notaLibera

    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .ammonizione:
            return "Ammonizione"
        case .espulsione:
            return "Espulsione"
        case .doppioGialloRosso:
            return "Doppio giallo rosso"
        case .gol:
            return "Gol"
        case .sostituzione:
            return "Sostituzione"
        case .notaLibera:
            return "Nota libera"
        }
    }

    var titoloBreve: String {
        switch self {
        case .ammonizione:
            return "Giallo"
        case .espulsione:
            return "Rosso"
        case .doppioGialloRosso:
            return "2G->R"
        case .gol:
            return "Gol"
        case .sostituzione:
            return "Cambio"
        case .notaLibera:
            return "Nota"
        }
    }
}

enum StatoCronometroRapportoGara: String, Codable, CaseIterable {
    case prepartita
    case primoTempo
    case recuperoPrimoTempo
    case intervallo
    case secondoTempo
    case recuperoSecondoTempo
    case finale

    var titolo: String {
        switch self {
        case .prepartita:
            return "Prepartita"
        case .primoTempo:
            return "1T"
        case .recuperoPrimoTempo:
            return "Recupero 1T"
        case .intervallo:
            return "Intervallo"
        case .secondoTempo:
            return "2T"
        case .recuperoSecondoTempo:
            return "Recupero 2T"
        case .finale:
            return "Finale"
        }
    }

    var isInCorso: Bool {
        switch self {
        case .primoTempo, .recuperoPrimoTempo, .secondoTempo, .recuperoSecondoTempo:
            return true
        case .prepartita, .intervallo, .finale:
            return false
        }
    }
}

enum OrigineEventoRapportoGara: String, Codable {
    case voceAppleWatch
    case sincronizzazioneAppleWatch
    case inserimentoManuale
}

struct MinutoRapportoGaraSnapshot: Codable, Hashable {
    let minuto: Int
    let recupero: Int?
    let labelMinuto: String
    let labelPeriodo: String
    let secondiCronometro: Int
}

struct CronometroDisplayRapportoGara: Hashable {
    let principale: String
    let decimi: Int?
}

struct EventoRapportoGara: Codable, Identifiable, Hashable {
    let id: UUID
    var minuto: MinutoRapportoGaraSnapshot
    var latoSquadra: LatoSquadraRapportoGara?
    var numeroMaglia: Int?
    var numeroMagliaEntrata: Int?
    var tipoEvento: TipoEventoRapportoGara
    var motivazione: String?
    var testoDettato: String
    var origine: OrigineEventoRapportoGara
    var creatoIl: Date

    init(
        id: UUID = UUID(),
        minuto: MinutoRapportoGaraSnapshot,
        latoSquadra: LatoSquadraRapportoGara?,
        numeroMaglia: Int?,
        numeroMagliaEntrata: Int? = nil,
        tipoEvento: TipoEventoRapportoGara,
        motivazione: String? = nil,
        testoDettato: String,
        origine: OrigineEventoRapportoGara,
        creatoIl: Date = Date()
    ) {
        self.id = id
        self.minuto = minuto
        self.latoSquadra = latoSquadra
        self.numeroMaglia = numeroMaglia
        self.numeroMagliaEntrata = numeroMagliaEntrata
        self.tipoEvento = tipoEvento
        self.motivazione = motivazione
        self.testoDettato = testoDettato
        self.origine = origine
        self.creatoIl = creatoIl
    }
}

struct SessioneRapportoGara: Codable, Identifiable, Hashable {
    let id: UUID
    var sessionId: String
    var designazioneId: String
    var titoloGara: String
    var dataGara: String
    var ruoloLabel: String
    var nomeOrologio: String
    var coloreMagliaCasa: String
    var coloreMagliaOspiti: String
    var statoCronometro: StatoCronometroRapportoGara
    var secondiPrimoTempo: Int
    var secondiSecondoTempo: Int
    var minutiRecuperoPrimoTempo: Int?
    var minutiRecuperoSecondoTempo: Int?
    var eventi: [EventoRapportoGara]
    var avviataIl: Date
    var aggiornataIl: Date
    var sincronizzataIl: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case sessionId
        case designazioneId
        case titoloGara
        case dataGara
        case ruoloLabel
        case nomeOrologio
        case coloreMagliaCasa
        case coloreMagliaOspiti
        case statoCronometro
        case secondiPrimoTempo
        case secondiSecondoTempo
        case minutiRecuperoPrimoTempo
        case minutiRecuperoSecondoTempo
        case eventi
        case avviataIl
        case aggiornataIl
        case sincronizzataIl
    }

    init(
        id: UUID = UUID(),
        sessionId: String,
        designazioneId: String,
        titoloGara: String,
        dataGara: String,
        ruoloLabel: String,
        nomeOrologio: String,
        coloreMagliaCasa: String = "",
        coloreMagliaOspiti: String = "",
        statoCronometro: StatoCronometroRapportoGara,
        secondiPrimoTempo: Int,
        secondiSecondoTempo: Int,
        minutiRecuperoPrimoTempo: Int? = nil,
        minutiRecuperoSecondoTempo: Int? = nil,
        eventi: [EventoRapportoGara],
        avviataIl: Date,
        aggiornataIl: Date = Date(),
        sincronizzataIl: Date? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.designazioneId = designazioneId
        self.titoloGara = titoloGara
        self.dataGara = dataGara
        self.ruoloLabel = ruoloLabel
        self.nomeOrologio = nomeOrologio
        self.coloreMagliaCasa = coloreMagliaCasa
        self.coloreMagliaOspiti = coloreMagliaOspiti
        self.statoCronometro = statoCronometro
        self.secondiPrimoTempo = secondiPrimoTempo
        self.secondiSecondoTempo = secondiSecondoTempo
        self.minutiRecuperoPrimoTempo = minutiRecuperoPrimoTempo
        self.minutiRecuperoSecondoTempo = minutiRecuperoSecondoTempo
        self.eventi = eventi
        self.avviataIl = avviataIl
        self.aggiornataIl = aggiornataIl
        self.sincronizzataIl = sincronizzataIl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        designazioneId = try container.decodeIfPresent(String.self, forKey: .designazioneId) ?? ""
        titoloGara = try container.decodeIfPresent(String.self, forKey: .titoloGara) ?? ""
        dataGara = try container.decodeIfPresent(String.self, forKey: .dataGara) ?? ""
        ruoloLabel = try container.decodeIfPresent(String.self, forKey: .ruoloLabel) ?? ""
        nomeOrologio = try container.decodeIfPresent(String.self, forKey: .nomeOrologio) ?? ""
        coloreMagliaCasa = try container.decodeIfPresent(String.self, forKey: .coloreMagliaCasa) ?? ""
        coloreMagliaOspiti = try container.decodeIfPresent(String.self, forKey: .coloreMagliaOspiti) ?? ""
        statoCronometro = try container.decodeIfPresent(StatoCronometroRapportoGara.self, forKey: .statoCronometro) ?? .prepartita
        secondiPrimoTempo = try container.decodeIfPresent(Int.self, forKey: .secondiPrimoTempo) ?? 0
        secondiSecondoTempo = try container.decodeIfPresent(Int.self, forKey: .secondiSecondoTempo) ?? 0
        minutiRecuperoPrimoTempo = try container.decodeIfPresent(Int.self, forKey: .minutiRecuperoPrimoTempo)
        minutiRecuperoSecondoTempo = try container.decodeIfPresent(Int.self, forKey: .minutiRecuperoSecondoTempo)
        eventi = try container.decodeIfPresent([EventoRapportoGara].self, forKey: .eventi) ?? []
        avviataIl = try container.decodeIfPresent(Date.self, forKey: .avviataIl) ?? Date()
        aggiornataIl = try container.decodeIfPresent(Date.self, forKey: .aggiornataIl) ?? avviataIl
        sincronizzataIl = try container.decodeIfPresent(Date.self, forKey: .sincronizzataIl)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(designazioneId, forKey: .designazioneId)
        try container.encode(titoloGara, forKey: .titoloGara)
        try container.encode(dataGara, forKey: .dataGara)
        try container.encode(ruoloLabel, forKey: .ruoloLabel)
        try container.encode(nomeOrologio, forKey: .nomeOrologio)
        try container.encode(coloreMagliaCasa, forKey: .coloreMagliaCasa)
        try container.encode(coloreMagliaOspiti, forKey: .coloreMagliaOspiti)
        try container.encode(statoCronometro, forKey: .statoCronometro)
        try container.encode(secondiPrimoTempo, forKey: .secondiPrimoTempo)
        try container.encode(secondiSecondoTempo, forKey: .secondiSecondoTempo)
        try container.encodeIfPresent(minutiRecuperoPrimoTempo, forKey: .minutiRecuperoPrimoTempo)
        try container.encodeIfPresent(minutiRecuperoSecondoTempo, forKey: .minutiRecuperoSecondoTempo)
        try container.encode(eventi, forKey: .eventi)
        try container.encode(avviataIl, forKey: .avviataIl)
        try container.encode(aggiornataIl, forKey: .aggiornataIl)
        try container.encodeIfPresent(sincronizzataIl, forKey: .sincronizzataIl)
    }

    var eventiOrdinati: [EventoRapportoGara] {
        eventi.sorted {
            if $0.minuto.secondiCronometro == $1.minuto.secondiCronometro {
                return $0.creatoIl < $1.creatoIl
            }
            return $0.minuto.secondiCronometro < $1.minuto.secondiCronometro
        }
    }

    var chiaveSessione: String {
        sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? id.uuidString : sessionId
    }

    var mappaColoriMaglia: [String: LatoSquadraRapportoGara] {
        var mapping: [String: LatoSquadraRapportoGara] = [:]

        for token in Self.tokenColori(from: coloreMagliaCasa) {
            mapping[token] = .casa
        }
        for token in Self.tokenColori(from: coloreMagliaOspiti) {
            mapping[token] = .ospiti
        }

        return mapping
    }

    private static func tokenColori(from value: String) -> Set<String> {
        let normalizzato = value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizzato.isEmpty else { return [] }

        var risultati: Set<String> = [normalizzato]
        let tokens = normalizzato.split(separator: " ").map(String.init)
        tokens.forEach { token in
            risultati.formUnion(variantiColoreToken(token))
        }
        if tokens.count == 1, let token = tokens.first {
            risultati.formUnion(variantiColoreToken(token))
        }
        return risultati
    }

    private static func variantiColoreToken(_ token: String) -> Set<String> {
        guard !token.isEmpty else { return [] }

        var risultati: Set<String> = [token]
        let ultimo = token.last
        let radice = String(token.dropLast())

        switch ultimo {
        case "o":
            risultati.formUnion([radice + "a", radice + "i", radice + "e"])
        case "a":
            risultati.formUnion([radice + "o", radice + "e", radice + "i"])
        case "i":
            risultati.formUnion([radice + "o", radice + "a", radice + "e"])
        case "e":
            risultati.formUnion([radice + "a", radice + "o", radice + "i"])
        default:
            break
        }

        return risultati
    }
}

struct RefertoDisponibileRapportoGara: Codable, Identifiable, Hashable {
    var designazioneId: String
    var titolo: String
    var sottotitolo: String
    var ruoloLabel: String

    var id: String { designazioneId }
}

struct ConfigurazioneColoriSessioneRapportoGara: Codable, Hashable {
    var sessionKey: String
    var designazioneId: String
    var coloreMagliaCasa: String
    var coloreMagliaOspiti: String
}

struct ContestoTelefonoRapportoGara: Codable {
    var verificationCode: String?
    var verificationExpiresAt: Date?
    var pairedWatchIDs: [String]
    var availableMatches: [RefertoDisponibileRapportoGara]
    var deletedSessionKeys: [String]
    var sessionConfigurations: [ConfigurazioneColoriSessioneRapportoGara]

    private enum CodingKeys: String, CodingKey {
        case verificationCode
        case verificationExpiresAt
        case pairedWatchIDs
        case availableMatches
        case deletedSessionKeys
        case sessionConfigurations
    }

    init(
        verificationCode: String? = nil,
        verificationExpiresAt: Date? = nil,
        pairedWatchIDs: [String] = [],
        availableMatches: [RefertoDisponibileRapportoGara] = [],
        deletedSessionKeys: [String] = [],
        sessionConfigurations: [ConfigurazioneColoriSessioneRapportoGara] = []
    ) {
        self.verificationCode = verificationCode
        self.verificationExpiresAt = verificationExpiresAt
        self.pairedWatchIDs = pairedWatchIDs
        self.availableMatches = availableMatches
        self.deletedSessionKeys = deletedSessionKeys
        self.sessionConfigurations = sessionConfigurations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        verificationCode = try container.decodeIfPresent(String.self, forKey: .verificationCode)
        verificationExpiresAt = try container.decodeIfPresent(Date.self, forKey: .verificationExpiresAt)
        pairedWatchIDs = try container.decodeIfPresent([String].self, forKey: .pairedWatchIDs) ?? []
        availableMatches = try container.decodeIfPresent([RefertoDisponibileRapportoGara].self, forKey: .availableMatches) ?? []
        deletedSessionKeys = try container.decodeIfPresent([String].self, forKey: .deletedSessionKeys) ?? []
        sessionConfigurations = try container.decodeIfPresent([ConfigurazioneColoriSessioneRapportoGara].self, forKey: .sessionConfigurations) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(verificationCode, forKey: .verificationCode)
        try container.encodeIfPresent(verificationExpiresAt, forKey: .verificationExpiresAt)
        try container.encode(pairedWatchIDs, forKey: .pairedWatchIDs)
        try container.encode(availableMatches, forKey: .availableMatches)
        try container.encode(deletedSessionKeys, forKey: .deletedSessionKeys)
        try container.encode(sessionConfigurations, forKey: .sessionConfigurations)
    }
}

struct PacchettoSyncRapportoGara: Codable {
    var version: Int
    var watchIdentifier: String
    var watchName: String
    var sessions: [SessioneRapportoGara]
    var sentAt: Date

    init(
        version: Int = 1,
        watchIdentifier: String,
        watchName: String,
        sessions: [SessioneRapportoGara],
        sentAt: Date = Date()
    ) {
        self.version = version
        self.watchIdentifier = watchIdentifier
        self.watchName = watchName
        self.sessions = sessions
        self.sentAt = sentAt
    }
}

struct RichiestaAbbinamentoRapportoGara: Codable {
    var watchIdentifier: String
    var watchName: String
    var verificationCode: String
    var requestedAt: Date
}

struct RichiestaEliminazioneSessioniRapportoGara: Codable {
    var watchIdentifier: String
    var sessionKeys: [String]
    var requestedAt: Date
}

struct RichiestaTrascrizioneRapportoGara: Codable {
    var requestID: UUID
    var sessionID: UUID
    var watchIdentifier: String
    var snapshot: MinutoRapportoGaraSnapshot
    var audioData: Data
    var requestedAt: Date
}

struct RispostaTrascrizioneRapportoGara: Codable {
    var requestID: UUID
    var sessionID: UUID
    var testo: String?
    var errore: String?
    var repliedAt: Date
}

enum StatoDettaturaDirettaRapportoGara: Equatable {
    case inattiva
    case ascolto
    case elaborazione
}

struct EventoVocaleInterpretatoRapportoGara {
    var numeroMaglia: Int?
    var numeroMagliaEntrata: Int?
    var latoSquadra: LatoSquadraRapportoGara?
    var tipoEvento: TipoEventoRapportoGara
    var motivazione: String?
}

struct DettaturaPendenteRapportoGaraWatch: Codable, Identifiable, Hashable {
    let id: UUID
    var snapshot: MinutoRapportoGaraSnapshot
    var registrataIl: Date
    var audioData: Data

    init(
        id: UUID = UUID(),
        snapshot: MinutoRapportoGaraSnapshot,
        registrataIl: Date,
        audioData: Data
    ) {
        self.id = id
        self.snapshot = snapshot
        self.registrataIl = registrataIl
        self.audioData = audioData
    }
}

struct SessioneLocaleRapportoGaraWatch: Codable, Identifiable, Hashable {
    let id: UUID
    var sessione: SessioneRapportoGara
    var faseAvviataIl: Date?
    var haRichiestoRecuperoPrimoTempo: Bool
    var haRichiestoRecuperoSecondoTempo: Bool
    var ultimoInvioIl: Date?
    var dettaturePendenti: [DettaturaPendenteRapportoGaraWatch]

    init(
        sessione: SessioneRapportoGara,
        faseAvviataIl: Date? = nil,
        haRichiestoRecuperoPrimoTempo: Bool = false,
        haRichiestoRecuperoSecondoTempo: Bool = false,
        ultimoInvioIl: Date? = nil,
        dettaturePendenti: [DettaturaPendenteRapportoGaraWatch] = []
    ) {
        self.id = sessione.id
        self.sessione = sessione
        self.faseAvviataIl = faseAvviataIl
        self.haRichiestoRecuperoPrimoTempo = haRichiestoRecuperoPrimoTempo
        self.haRichiestoRecuperoSecondoTempo = haRichiestoRecuperoSecondoTempo
        self.ultimoInvioIl = ultimoInvioIl
        self.dettaturePendenti = dettaturePendenti
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sessione
        case faseAvviataIl
        case haRichiestoRecuperoPrimoTempo
        case haRichiestoRecuperoSecondoTempo
        case ultimoInvioIl
        case dettaturePendenti
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessione = try container.decode(SessioneRapportoGara.self, forKey: .sessione)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? sessione.id
        faseAvviataIl = try container.decodeIfPresent(Date.self, forKey: .faseAvviataIl)
        haRichiestoRecuperoPrimoTempo = try container.decodeIfPresent(Bool.self, forKey: .haRichiestoRecuperoPrimoTempo) ?? false
        haRichiestoRecuperoSecondoTempo = try container.decodeIfPresent(Bool.self, forKey: .haRichiestoRecuperoSecondoTempo) ?? false
        ultimoInvioIl = try container.decodeIfPresent(Date.self, forKey: .ultimoInvioIl)
        dettaturePendenti = try container.decodeIfPresent([DettaturaPendenteRapportoGaraWatch].self, forKey: .dettaturePendenti) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessione, forKey: .sessione)
        try container.encodeIfPresent(faseAvviataIl, forKey: .faseAvviataIl)
        try container.encode(haRichiestoRecuperoPrimoTempo, forKey: .haRichiestoRecuperoPrimoTempo)
        try container.encode(haRichiestoRecuperoSecondoTempo, forKey: .haRichiestoRecuperoSecondoTempo)
        try container.encodeIfPresent(ultimoInvioIl, forKey: .ultimoInvioIl)
        try container.encode(dettaturePendenti, forKey: .dettaturePendenti)
    }

    func sessioneRenderizzata(alla data: Date) -> SessioneRapportoGara {
        guard let faseAvviataIl, sessione.statoCronometro.isInCorso else { return sessione }
        let delta = max(0, Int(data.timeIntervalSince(faseAvviataIl)))
        var renderizzata = sessione

        switch renderizzata.statoCronometro {
        case .primoTempo, .recuperoPrimoTempo:
            renderizzata.secondiPrimoTempo += delta
        case .secondoTempo, .recuperoSecondoTempo:
            renderizzata.secondiSecondoTempo += delta
        case .prepartita, .intervallo, .finale:
            break
        }

        return renderizzata
    }

    func cronometroDisplay(alla data: Date) -> CronometroDisplayRapportoGara {
        let secondiPrecisi = secondiCronometroPrecisi(alla: data)
        return CalcolatoreCronometroRapportoGara.cronometroDisplay(
            secondiPrecisi: secondiPrecisi,
            mostraDecimi: sessione.statoCronometro.isInCorso
        )
    }

    private func secondiCronometroPrecisi(alla data: Date) -> TimeInterval {
        let deltaAttivo: TimeInterval
        if sessione.statoCronometro.isInCorso, let faseAvviataIl {
            // Garantisce un primo feedback visivo immediato appena parte il cronometro,
            // anche se il primo render arriva nello stesso istante dell'avvio.
            deltaAttivo = max(0.1, data.timeIntervalSince(faseAvviataIl))
        } else {
            deltaAttivo = 0
        }

        switch sessione.statoCronometro {
        case .prepartita:
            return 0
        case .primoTempo, .recuperoPrimoTempo, .intervallo:
            return TimeInterval(sessione.secondiPrimoTempo) + deltaAttivo
        case .secondoTempo, .recuperoSecondoTempo, .finale:
            return TimeInterval(sessione.secondiSecondoTempo) + deltaAttivo
        }
    }
}

enum PromptRecuperoRapportoGara: String {
    case primoTempo
    case secondoTempo

    var titolo: String {
        switch self {
        case .primoTempo:
            return "Recupero 1T"
        case .secondoTempo:
            return "Recupero 2T"
        }
    }
}

enum ParserEventoVocaleRapportoGara {
    static func interpreta(testo: String, sessione: SessioneRapportoGara) -> EventoRapportoGara? {
        interpreta(
            testo: testo,
            snapshot: CalcolatoreCronometroRapportoGara.snapshot(per: sessione),
            eventiPrecedenti: sessione.eventi,
            coloriMaglia: sessione.mappaColoriMaglia
        )
    }

    static func interpreta(
        testo: String,
        snapshot: MinutoRapportoGaraSnapshot,
        eventiPrecedenti: [EventoRapportoGara],
        coloriMaglia: [String: LatoSquadraRapportoGara] = [:],
        eventID: UUID = UUID()
    ) -> EventoRapportoGara? {
        let normalizzato = testoNormalizzato(testo)
        guard let interpretato = interpretaComponenti(in: normalizzato, coloriMaglia: coloriMaglia) else { return nil }
        let tipoCorretto = tipoEventoCorretto(
            interpretato.tipoEvento,
            latoSquadra: interpretato.latoSquadra,
            numeroMaglia: interpretato.numeroMaglia,
            eventiPrecedenti: eventiPrecedenti
        )

        return EventoRapportoGara(
            id: eventID,
            minuto: snapshot,
            latoSquadra: interpretato.latoSquadra,
            numeroMaglia: interpretato.numeroMaglia,
            numeroMagliaEntrata: interpretato.numeroMagliaEntrata,
            tipoEvento: tipoCorretto,
            motivazione: interpretato.motivazione,
            testoDettato: testo.trimmingCharacters(in: .whitespacesAndNewlines),
            origine: .voceAppleWatch
        )
    }

    private static func interpretaComponenti(
        in testo: String,
        coloriMaglia: [String: LatoSquadraRapportoGara]
    ) -> EventoVocaleInterpretatoRapportoGara? {
        let tokens = tokens(in: testo)

        guard let tipo = tipoEvento(in: testo) else {
            return nil
        }

        let lato = latoSquadra(in: tokens, tipoEvento: tipo, coloriMaglia: coloriMaglia)
        let numeri = numeri(in: tokens, tipoEvento: tipo)
        let motivazione = motivazione(in: testo, tokens: tokens, tipoEvento: tipo, coloriMaglia: coloriMaglia)

        let haContesto: Bool
        switch tipo {
        case .sostituzione:
            haContesto = lato != nil || numeri.principale != nil || numeri.entrata != nil
        case .gol:
            haContesto = lato != nil || numeri.principale != nil || motivazione != nil
        default:
            haContesto = lato != nil || numeri.principale != nil || motivazione != nil
        }

        guard haContesto else {
            return nil
        }

        return EventoVocaleInterpretatoRapportoGara(
            numeroMaglia: numeri.principale,
            numeroMagliaEntrata: numeri.entrata,
            latoSquadra: lato,
            tipoEvento: tipo,
            motivazione: motivazione
        )
    }

    private static func latoSquadra(
        in tokens: [String],
        tipoEvento: TipoEventoRapportoGara,
        coloriMaglia: [String: LatoSquadraRapportoGara]
    ) -> LatoSquadraRapportoGara? {
        if tokens.contains(where: { isTokenOspiti($0) }) {
            return .ospiti
        }
        if tokens.contains(where: { isTokenCasa($0) }) {
            return .casa
        }

        return latoSquadraDaColori(
            in: tokens,
            tipoEvento: tipoEvento,
            coloriMaglia: coloriMaglia
        )
    }

    private static func tipoEvento(in testo: String) -> TipoEventoRapportoGara? {
        let tokens = tokens(in: testo)

        if patternDoppioGialloRosso.contains(where: { matches($0, tokens: tokens) }) {
            return .doppioGialloRosso
        }

        if patternSostituzione.contains(where: { matches($0, tokens: tokens) }) {
            return .sostituzione
        }

        if patternGol.contains(where: { matches($0, tokens: tokens) }) {
            return .gol
        }

        if patternAmmonizione.contains(where: { matches($0, tokens: tokens) }) {
            return .ammonizione
        }

        if patternEspulsione.contains(where: { matches($0, tokens: tokens) }) {
            return .espulsione
        }

        return nil
    }

    private static func tipoEventoCorretto(
        _ tipo: TipoEventoRapportoGara,
        latoSquadra: LatoSquadraRapportoGara?,
        numeroMaglia: Int?,
        eventiPrecedenti: [EventoRapportoGara]
    ) -> TipoEventoRapportoGara {
        guard tipo == .ammonizione,
              let latoSquadra,
              let numeroMaglia else { return tipo }

        let eventiGiocatore = eventiPrecedenti.filter {
            $0.latoSquadra == latoSquadra && $0.numeroMaglia == numeroMaglia
        }

        let haGiaEspulsione = eventiGiocatore.contains {
            $0.tipoEvento == .espulsione || $0.tipoEvento == .doppioGialloRosso
        }
        guard !haGiaEspulsione else { return tipo }

        let ammonizioniPrecedenti = eventiGiocatore.filter { $0.tipoEvento == .ammonizione }.count
        return ammonizioniPrecedenti >= 1 ? .doppioGialloRosso : .ammonizione
    }

    private static func numeri(in tokens: [String], tipoEvento: TipoEventoRapportoGara) -> (principale: Int?, entrata: Int?) {
        if tipoEvento == .sostituzione {
            return numeriSostituzione(in: tokens)
        }
        return (numeroMaglia(in: tokens), nil)
    }

    private static func numeroMaglia(in tokens: [String]) -> Int? {
        if let numeroEsplicito = numeroEsplicito(in: tokens) {
            return numeroEsplicito
        }

        let indiciEvento = indiciTipoEvento(in: tokens)
        let indiciSquadra = indiciSquadra(in: tokens)
        let candidati = tokens.enumerated().compactMap { index, word -> CandidatoNumeroMaglia? in
            guard let value = numeroDaToken(word) else { return nil }

            var score = 0
            let precedente = tokenAt(index - 1, in: tokens)
            let precedente2 = tokenAt(index - 2, in: tokens)
            let successivo = tokenAt(index + 1, in: tokens)

            if isMarkerNumero(precedente) || isMarkerNumero(precedente2) {
                score += 120
            }
            if isTokenSquadra(precedente) || isTokenSquadra(successivo) {
                score += 70
            }
            if distanzaMinima(from: index, to: indiciSquadra) <= 2 {
                score += 40
            }
            if distanzaMinima(from: index, to: indiciEvento) <= 2 {
                score += 25
            }
            if isMarkerMinuto(precedente) || isMarkerMinuto(precedente2) {
                score -= 90
            }
            if isMarkerMinuto(successivo) {
                score -= 60
            }

            return CandidatoNumeroMaglia(value: value, score: score, index: index)
        }

        return candidati
            .sorted {
                if $0.score == $1.score {
                    return $0.index < $1.index
                }
                return $0.score > $1.score
            }
            .first(where: { $0.score > 0 })?
            .value
            ?? candidati.first?.value
    }

    private static func motivazione(
        in testo: String,
        tokens: [String],
        tipoEvento: TipoEventoRapportoGara,
        coloriMaglia: [String: LatoSquadraRapportoGara]
    ) -> String? {
        if tipoEvento == .sostituzione {
            return nil
        }

        for marker in markerMotivazione {
            guard let range = testo.range(of: marker) else { continue }
            let motivo = testo[range.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !motivo.isEmpty {
                return motivo
            }
        }

        let scarti = Set(tokens.enumerated().compactMap { index, token -> Int? in
            if isTokenSquadra(token)
                || isMarkerNumero(token)
                || isMarkerMinuto(token)
                || isTokenTipoEvento(token)
                || token == "cartellino"
                || token == "entra"
                || token == "esce"
                || token == "uscita"
                || token == "ingresso"
                || token == "subentra"
                || token == "giocatore"
                || token == "calciatore" {
                return index
            }
            if numeroDaToken(token) != nil {
                return index
            }
            if coloriMaglia[token] != nil {
                return index
            }
            return nil
        })

        let resto = tokens.enumerated()
            .compactMap { scarti.contains($0.offset) ? nil : $0.element }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return resto.count >= 4 ? resto : nil
    }

    private static func latoSquadraDaColori(
        in tokens: [String],
        tipoEvento: TipoEventoRapportoGara,
        coloriMaglia: [String: LatoSquadraRapportoGara]
    ) -> LatoSquadraRapportoGara? {
        guard !coloriMaglia.isEmpty else { return nil }

        let indiceInizioContenuto = leadingEventTokenCount(in: tokens, tipoEvento: tipoEvento)

        let tokensFiltrati = Array(tokens.dropFirst(indiceInizioContenuto)).filter { token in
            if numeroDaToken(token) != nil {
                return false
            }
            if isMarkerNumero(token) || isMarkerMinuto(token) {
                return false
            }
            switch tipoEvento {
            case .sostituzione:
                return token != "entra" && token != "esce" && token != "uscita" && token != "ingresso" && token != "subentra"
            case .ammonizione, .espulsione, .doppioGialloRosso, .gol, .notaLibera:
                return true
            }
        }

        guard !tokensFiltrati.isEmpty else { return nil }

        for lunghezza in stride(from: min(3, tokensFiltrati.count), through: 1, by: -1) {
            guard tokensFiltrati.count >= lunghezza else { continue }
            for start in 0...(tokensFiltrati.count - lunghezza) {
                let frase = tokensFiltrati[start..<(start + lunghezza)].joined(separator: " ")
                if let lato = coloriMaglia[frase] {
                    return lato
                }
            }
        }

        return nil
    }

    private static func leadingEventTokenCount(
        in tokens: [String],
        tipoEvento: TipoEventoRapportoGara
    ) -> Int {
        guard !tokens.isEmpty else { return 0 }

        switch tipoEvento {
        case .gol, .sostituzione, .ammonizione, .espulsione:
            if tokens.first == "cartellino" && tokens.count > 1 {
                return 2
            }
            return 1
        case .doppioGialloRosso:
            var count = 0
            while count < tokens.count && count < 3 {
                let token = tokens[count]
                guard isTokenTipoEvento(token) || token == "cartellino" else { break }
                count += 1
            }
            return max(1, count)
        case .notaLibera:
            return 0
        }
    }

    private static func numeriSostituzione(in tokens: [String]) -> (principale: Int?, entrata: Int?) {
        let uscitaEsplicita = numeroDopo(marker: ["esce", "uscita"], in: tokens)
        let entrataEsplicita = numeroDopo(marker: ["entra", "ingresso", "subentra"], in: tokens)

        var uscita = uscitaEsplicita
        var entrata = entrataEsplicita

        let numeriLiberi = tokens.enumerated().compactMap { index, token -> Int? in
            guard let value = numeroDaToken(token) else { return nil }
            let precedente = tokenAt(index - 1, in: tokens)
            let precedente2 = tokenAt(index - 2, in: tokens)
            let successivo = tokenAt(index + 1, in: tokens)
            if isMarkerMinuto(precedente) || isMarkerMinuto(precedente2) || isMarkerMinuto(successivo) {
                return nil
            }
            return value
        }
        .filter { value in
            value != uscitaEsplicita && value != entrataEsplicita
        }

        if uscita == nil {
            uscita = numeriLiberi.first
        }
        if entrata == nil {
            if let uscita, let candidato = numeriLiberi.first(where: { $0 != uscita }) {
                entrata = candidato
            } else if numeriLiberi.count >= 2 {
                entrata = numeriLiberi[1]
            }
        }

        return (uscita, entrata)
    }

    private static func numeroDaToken(_ token: String) -> Int? {
        let digits = token.filter(\.isNumber)
        if let value = Int(digits), (1...99).contains(value) {
            return value
        }

        let token = token.lowercased()
        if let direct = numeriDiretti[token], (1...99).contains(direct) {
            return direct
        }

        for (stem, base) in stemsDecine {
            guard token.hasPrefix(stem) else { continue }
            let suffix = String(token.dropFirst(stem.count))
            if suffix.isEmpty {
                return base
            }
            if let unit = unita[suffix], (1...9).contains(unit) {
                return base + unit
            }
        }

        return nil
    }

    private static func testoNormalizzato(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokens(in testo: String) -> [String] {
        testo.split(separator: " ").map(String.init)
    }

    private static func numeroEsplicito(in tokens: [String]) -> Int? {
        for index in tokens.indices {
            guard isMarkerNumero(tokens[index]), index + 1 < tokens.count else { continue }
            if let value = numeroDaToken(tokens[index + 1]) {
                return value
            }
        }
        return nil
    }

    private static func numeroDopo(marker markers: Set<String>, in tokens: [String]) -> Int? {
        for index in tokens.indices {
            guard markers.contains(tokens[index]) else { continue }
            let upperBound = min(tokens.count - 1, index + 2)
            guard upperBound >= index + 1 else { continue }
            for candidateIndex in (index + 1)...upperBound {
                if let value = numeroDaToken(tokens[candidateIndex]) {
                    return value
                }
            }
        }
        return nil
    }

    private static func indiciTipoEvento(in tokens: [String]) -> [Int] {
        tokens.enumerated().compactMap { isTokenTipoEvento($0.element) ? $0.offset : nil }
    }

    private static func indiciSquadra(in tokens: [String]) -> [Int] {
        tokens.enumerated().compactMap { isTokenSquadra($0.element) ? $0.offset : nil }
    }

    private static func distanzaMinima(from index: Int, to indices: [Int]) -> Int {
        indices.map { abs($0 - index) }.min() ?? .max
    }

    private static func tokenAt(_ index: Int, in tokens: [String]) -> String {
        guard tokens.indices.contains(index) else { return "" }
        return tokens[index]
    }

    private static func isMarkerNumero(_ token: String) -> Bool {
        markerNumero.contains(token) || token.hasPrefix("n.")
    }

    private static func isMarkerMinuto(_ token: String) -> Bool {
        markerMinuto.contains(token)
    }

    private static func isTokenCasa(_ token: String) -> Bool {
        token == "casa" || token == "locale" || token == "locali" || token == "interni"
    }

    private static func isTokenOspiti(_ token: String) -> Bool {
        token == "ospiti" || token == "ospite" || token == "trasferta" || token == "esterni" || token == "avversari"
    }

    private static func isTokenSquadra(_ token: String) -> Bool {
        isTokenCasa(token) || isTokenOspiti(token)
    }

    private static func isTokenTipoEvento(_ token: String) -> Bool {
        if token.contains("ammonit") || token == "giallo" || token == "gialla" {
            return true
        }
        if token.contains("espuls") || token == "rosso" || token == "rossa" {
            return true
        }
        if token == "gol" || token == "goal" || token == "rete" {
            return true
        }
        if token == "cambio" || token == "sostituzione" || token == "entra" || token == "esce" || token == "subentra" {
            return true
        }
        return token == "doppio" || token == "doppia" || token == "seconda" || token == "secondo"
    }

    private static func matches(_ pattern: [String], tokens: [String]) -> Bool {
        guard tokens.count >= pattern.count else { return false }

        return zip(pattern, tokens).allSatisfy { expected, actual in
            if expected.hasSuffix("*") {
                return actual.hasPrefix(String(expected.dropLast()))
            }
            return expected == actual
        }
    }

    private struct CandidatoNumeroMaglia {
        let value: Int
        let score: Int
        let index: Int
    }

    private static let unita: [String: Int] = [
        "uno": 1,
        "una": 1,
        "due": 2,
        "tre": 3,
        "quattro": 4,
        "cinque": 5,
        "sei": 6,
        "sette": 7,
        "otto": 8,
        "nove": 9
    ]

    private static let numeriDiretti: [String: Int] = [
        "uno": 1,
        "una": 1,
        "due": 2,
        "tre": 3,
        "quattro": 4,
        "cinque": 5,
        "sei": 6,
        "sette": 7,
        "otto": 8,
        "nove": 9,
        "dieci": 10,
        "undici": 11,
        "dodici": 12,
        "tredici": 13,
        "quattordici": 14,
        "quindici": 15,
        "sedici": 16,
        "diciassette": 17,
        "diciotto": 18,
        "diciannove": 19,
        "venti": 20,
        "trenta": 30,
        "quaranta": 40,
        "cinquanta": 50,
        "sessanta": 60,
        "settanta": 70,
        "ottanta": 80,
        "novanta": 90
    ]

    private static let stemsDecine: [(String, Int)] = [
        ("vent", 20),
        ("trent", 30),
        ("quarant", 40),
        ("cinquant", 50),
        ("sessant", 60),
        ("settant", 70),
        ("ottant", 80),
        ("novant", 90)
    ]

    private static let markerNumero: Set<String> = [
        "numero",
        "num",
        "n",
        "nro",
        "maglia",
        "giocatore",
        "calciatore"
    ]

    private static let markerMinuto: Set<String> = [
        "al",
        "alla",
        "allo",
        "ai",
        "a",
        "min",
        "minuto",
        "minuti",
        "tempo",
        "esimo",
        "esima"
    ]

    private static let markerMotivazione: [String] = [
        " per ",
        " motivo ",
        " motivazione ",
        " causa ",
        " perche "
    ]

    private static let patternAmmonizione: [[String]] = [
        ["ammonit*"],
        ["ammonizione"],
        ["ammonito"],
        ["ammonita"],
        ["giallo"],
        ["cartellino", "giallo"]
    ]

    private static let patternEspulsione: [[String]] = [
        ["espuls*"],
        ["espulso"],
        ["espulsa"],
        ["espulsione"],
        ["rosso", "diretto"],
        ["cartellino", "rosso"],
        ["rosso"]
    ]

    private static let patternDoppioGialloRosso: [[String]] = [
        ["doppio", "giallo", "rosso"],
        ["doppio", "giallorosso"],
        ["seconda", "ammonizione"],
        ["doppia", "ammonizione"],
        ["secondo", "giallo"],
        ["secondo", "cartellino", "giallo"]
    ]

    private static let patternGol: [[String]] = [
        ["gol"],
        ["goal"],
        ["rete"],
        ["ha", "segnato"],
        ["segnato"],
        ["segna"],
        ["segnano"]
    ]

    private static let patternSostituzione: [[String]] = [
        ["sostituzione"],
        ["cambio"],
        ["entra"],
        ["esce"],
        ["subentra"]
    ]
}

enum CalcolatoreCronometroRapportoGara {
    static func snapshot(per sessione: SessioneRapportoGara) -> MinutoRapportoGaraSnapshot {
        switch sessione.statoCronometro {
        case .prepartita:
            return MinutoRapportoGaraSnapshot(
                minuto: 0,
                recupero: nil,
                labelMinuto: "0'",
                labelPeriodo: "Pre",
                secondiCronometro: 0
            )
        case .primoTempo:
            return snapshotTempoRegolare(secondi: sessione.secondiPrimoTempo, offset: 0, periodo: "1T")
        case .recuperoPrimoTempo:
            return snapshotRecupero(
                secondi: sessione.secondiPrimoTempo,
                baseMinuto: 45,
                periodo: "1T"
            )
        case .intervallo:
            return MinutoRapportoGaraSnapshot(
                minuto: 45,
                recupero: sessione.minutiRecuperoPrimoTempo,
                labelMinuto: "Intervallo",
                labelPeriodo: "HT",
                secondiCronometro: sessione.secondiPrimoTempo
            )
        case .secondoTempo:
            return snapshotTempoRegolare(secondi: sessione.secondiSecondoTempo, offset: 45, periodo: "2T")
        case .recuperoSecondoTempo:
            return snapshotRecupero(
                secondi: sessione.secondiSecondoTempo,
                baseMinuto: 90,
                periodo: "2T"
            )
        case .finale:
            return MinutoRapportoGaraSnapshot(
                minuto: 90,
                recupero: sessione.minutiRecuperoSecondoTempo,
                labelMinuto: "FT",
                labelPeriodo: "FT",
                secondiCronometro: sessione.secondiPrimoTempo + sessione.secondiSecondoTempo
            )
        }
    }

    static func cronometroDisplay(per sessione: SessioneRapportoGara) -> String {
        let secondi: Int
        switch sessione.statoCronometro {
        case .prepartita:
            secondi = 0
        case .primoTempo, .recuperoPrimoTempo, .intervallo:
            secondi = sessione.secondiPrimoTempo
        case .secondoTempo, .recuperoSecondoTempo, .finale:
            secondi = sessione.secondiSecondoTempo
        }

        let minuti = secondi / 60
        let residuo = secondi % 60
        return String(format: "%02d:%02d", minuti, residuo)
    }

    static func cronometroDisplay(secondiPrecisi: TimeInterval, mostraDecimi: Bool) -> CronometroDisplayRapportoGara {
        let secondiClamped = max(0, secondiPrecisi)
        let secondiInteri = Int(floor(secondiClamped))
        let minuti = secondiInteri / 60
        let residuo = secondiInteri % 60
        let decimi = mostraDecimi ? min(9, Int((secondiClamped - floor(secondiClamped)) * 10)) : nil

        return CronometroDisplayRapportoGara(
            principale: String(format: "%02d:%02d", minuti, residuo),
            decimi: decimi
        )
    }

    private static func snapshotTempoRegolare(secondi: Int, offset: Int, periodo: String) -> MinutoRapportoGaraSnapshot {
        let minuto = max(1, min(45, (secondi / 60) + 1)) + offset
        return MinutoRapportoGaraSnapshot(
            minuto: minuto,
            recupero: nil,
            labelMinuto: "\(minuto)'",
            labelPeriodo: periodo,
            secondiCronometro: secondi + (offset == 45 ? 45 * 60 : 0)
        )
    }

    private static func snapshotRecupero(secondi: Int, baseMinuto: Int, periodo: String) -> MinutoRapportoGaraSnapshot {
        let secondiOltreTempo = max(0, secondi - (45 * 60))
        let recupero = max(1, (secondiOltreTempo / 60) + 1)
        let totaleSecondi = secondi + (baseMinuto == 90 ? 45 * 60 : 0)
        return MinutoRapportoGaraSnapshot(
            minuto: baseMinuto,
            recupero: recupero,
            labelMinuto: "\(baseMinuto)+\(recupero)'",
            labelPeriodo: periodo,
            secondiCronometro: totaleSecondi
        )
    }
}
