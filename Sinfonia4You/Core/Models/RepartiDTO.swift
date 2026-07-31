//
//  RepartiDTO.swift
//  Sinfonia4You
//
//  Modelli generici per i reparti esposti dal backend dell'app.
//

import Foundation

struct CatalogoRepartiDTO: Codable {
    let groups: [GruppoRepartiDTO]
}

struct GruppoRepartiDTO: Codable, Identifiable {
    let title: String
    let modules: [RepartoSintesiDTO]

    var id: String { title }
}

struct RepartoSintesiDTO: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemIcon: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case systemIcon = "system_icon"
    }
}

struct SnapshotModuloDTO: Codable {
    let moduleId: String
    let title: String
    let highlights: [HighlightModuloDTO]
    let rows: [RigaModuloDTO]
    let optionGroups: [GruppoOpzioniModuloDTO]
    let introText: String
    let legalText: String

    enum CodingKeys: String, CodingKey {
        case moduleId = "module_id"
        case title
        case highlights
        case rows
        case optionGroups = "option_groups"
        case introText = "intro_text"
        case legalText = "legal_text"
    }
}

struct HighlightModuloDTO: Codable, Identifiable {
    let label: String
    let value: String

    var id: String { "\(label)|\(value)" }
}

struct CampoModuloDTO: Codable, Identifiable {
    let label: String
    let value: String

    var id: String { "\(label)|\(value)" }
}

struct AllegatoModuloDTO: Codable, Identifiable {
    let label: String
    let url: String

    var id: String { "\(label)|\(url)" }
}

struct RigaModuloDTO: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let status: String
    let fields: [CampoModuloDTO]
    let attachments: [AllegatoModuloDTO]
    let roleKind: String?
    let roleLabel: String?
    let actionKind: String?
    let actionLabel: String?
    let canPrint: Bool?
    let canSubmit: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case status
        case fields
        case attachments
        case roleKind = "role_kind"
        case roleLabel = "role_label"
        case actionKind = "action_kind"
        case actionLabel = "action_label"
        case canPrint = "can_print"
        case canSubmit = "can_submit"
    }
}

struct GruppoOpzioniModuloDTO: Codable, Identifiable {
    let title: String
    let options: [OpzioneModuloDTO]

    var id: String { title }
}

struct OpzioneModuloDTO: Codable, Identifiable {
    let value: String
    let label: String

    var id: String { "\(value)|\(label)" }
}

struct DettaglioGaraDTO: Codable {
    let match: MatchAssignmentDTO
    let detailText: String
    let mapsQuery: String
    let detailFields: DettagliGaraCampiDTO
    let collaborators: [CollaboratoreGaraDTO]

    enum CodingKeys: String, CodingKey {
        case match
        case detailText = "detail_text"
        case mapsQuery = "maps_query"
        case detailFields = "detail_fields"
        case collaborators
    }
}

struct ClassificaGaraDTO: Codable {
    let competitionLabel: String
    let areaLabel: String
    let classificaUrl: String
    let homeRow: RigaClassificaDTO?
    let awayRow: RigaClassificaDTO?
    let homeScore: Double
    let awayScore: Double
    let rows: [RigaClassificaDTO]

    enum CodingKeys: String, CodingKey {
        case competitionLabel = "competition_label"
        case areaLabel = "area_label"
        case classificaUrl = "classifica_url"
        case homeRow = "home_row"
        case awayRow = "away_row"
        case homeScore = "home_score"
        case awayScore = "away_score"
        case rows
    }
}

struct RigaClassificaDTO: Codable, Identifiable, Hashable {
    let position: Int
    let teamId: String
    let team: String
    let teamLink: String
    let points: Int
    let played: Int
    let won: Int
    let draw: Int
    let lost: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let goalDiff: Int

    var id: String { !teamId.isEmpty ? teamId : "\(position)|\(team)" }

    enum CodingKeys: String, CodingKey {
        case position
        case teamId = "team_id"
        case team
        case teamLink = "team_link"
        case points
        case played
        case won
        case draw
        case lost
        case goalsFor = "goals_for"
        case goalsAgainst = "goals_against"
        case goalDiff = "goal_diff"
    }
}

struct DettagliGaraCampiDTO: Codable {
    let userName: String
    let roleLabel: String
    let competition: String
    let teams: String
    let whenLine: String
    let whereLine: String
    let rimborsoLine: String
    let rimborso: String
    let distance: String

    enum CodingKeys: String, CodingKey {
        case userName = "user_name"
        case roleLabel = "role_label"
        case competition
        case teams
        case whenLine = "when_line"
        case whereLine = "where_line"
        case rimborsoLine = "rimborso_line"
        case rimborso
        case distance
    }
}

struct CollaboratoreGaraDTO: Codable, Identifiable {
    let role: String
    let name: String
    let section: String?
    let cell: String
    let email: String

    var id: String { "\(role)|\(name)|\(section ?? "")|\(cell)|\(email)" }
}

struct MatchAssignmentDTO: Codable, Identifiable {
    let idGara: String
    let idDesignazione: String
    let category: String
    let group: String
    let giornata: String
    let date: String
    let time: String
    let homeTeam: String
    let awayTeam: String
    let activity: String
    let status: String
    let statusLabel: String
    let canAccept: Bool
    let canReject: Bool

    var id: String { idDesignazione }

    enum CodingKeys: String, CodingKey {
        case idGara = "id_gara"
        case idDesignazione = "id_designazione"
        case category
        case group
        case giornata
        case date
        case time
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case activity
        case status
        case statusLabel = "status_label"
        case canAccept = "can_accept"
        case canReject = "can_reject"
    }
}

struct DettaglioRefertoDTO: Codable {
    let item: RefertoSintesiDTO
    let refertoId: String?
    let designazioneId: String?
    let reportTitle: String
    let gameFields: [CampoModuloDTO]
    let officials: [[String: String]]
    let segnalazioneTitle: String
    let segnalazioneNotice: String
    let segnalazioneOptions: [String]
    let segnalazioneValue: String
    let noteTitle: String
    let noteLimit: Int
    let noteRemaining: String
    let noteText: String
    let canPrint: Bool
    let canSave: Bool
    let templateFields: [CampoTemplateRefertoDTO]
    let roleKind: String?
    let roleLabel: String?
    let actionKind: String?
    let actionLabel: String?
    let statusLabel: String?
    let saveLabel: String?
    let saveHint: String?
    let readOnlyHint: String?
    let flowTabs: [String]
    let currentTab: String
    let svolgimentoTitle: String
    let svolgimentoNotice: String
    let svolgimentoOptions: [RefertoSvolgimentoOptionDTO]
    let svolgimentoValue: String
    let svolgimentoRequired: Bool
    let ordineTitle: String
    let ordineNotice: String
    let ordineOptions: [RefertoSvolgimentoOptionDTO]
    let ordineValue: String
    let ordineRequired: Bool
    let ambulanzaTitle: String
    let ambulanzaNotice: String
    let ambulanzaOptions: [RefertoSvolgimentoOptionDTO]
    let ambulanzaValue: String
    let ambulanzaRequired: Bool
    let ordineNoteTitle: String
    let ordineNoteLimit: Int
    let ordineNoteRemaining: String
    let ordineNoteText: String
    let ordineNotePlaceholder: String
    let notePlaceholder: String
    let durataTitle: String
    let durataNotice: String
    let durataStartTitle: String
    let durataStartTime: String
    let durataEndTitle: String
    let durataEndTime: String
    let durataGameOptions: [RefertoSelectOptionDTO]
    let durataIntervalOptions: [RefertoSelectOptionDTO]
    let durataRigoriOptions: [RefertoSelectOptionDTO]
    let durataRows: [RefertoDurataRowDTO]
    let documentOptions: [RefertoSelectOptionDTO]?
    let staffRoleOptions: [RefertoSelectOptionDTO]?
    let listaGaraHome: RefertoListeGaraSquadraDTO?
    let listaGaraAway: RefertoListeGaraSquadraDTO?

    enum CodingKeys: String, CodingKey {
        case item
        case refertoId = "referto_id"
        case designazioneId = "designazione_id"
        case reportTitle = "report_title"
        case gameFields = "game_fields"
        case officials
        case segnalazioneTitle = "segnalazione_title"
        case segnalazioneNotice = "segnalazione_notice"
        case segnalazioneOptions = "segnalazione_options"
        case segnalazioneValue = "segnalazione_value"
        case noteTitle = "note_title"
        case noteLimit = "note_limit"
        case noteRemaining = "note_remaining"
        case noteText = "note_text"
        case canPrint = "can_print"
        case canSave = "can_save"
        case templateFields = "template_fields"
        case roleKind = "role_kind"
        case roleLabel = "role_label"
        case actionKind = "action_kind"
        case actionLabel = "action_label"
        case statusLabel = "status_label"
        case saveLabel = "save_label"
        case saveHint = "save_hint"
        case readOnlyHint = "read_only_hint"
        case flowTabs = "flow_tabs"
        case currentTab = "current_tab"
        case svolgimentoTitle = "svolgimento_title"
        case svolgimentoNotice = "svolgimento_notice"
        case svolgimentoOptions = "svolgimento_options"
        case svolgimentoValue = "svolgimento_value"
        case svolgimentoRequired = "svolgimento_required"
        case ordineTitle = "ordine_title"
        case ordineNotice = "ordine_notice"
        case ordineOptions = "ordine_options"
        case ordineValue = "ordine_value"
        case ordineRequired = "ordine_required"
        case ambulanzaTitle = "ambulanza_title"
        case ambulanzaNotice = "ambulanza_notice"
        case ambulanzaOptions = "ambulanza_options"
        case ambulanzaValue = "ambulanza_value"
        case ambulanzaRequired = "ambulanza_required"
        case ordineNoteTitle = "ordine_note_title"
        case ordineNoteLimit = "ordine_note_limit"
        case ordineNoteRemaining = "ordine_note_remaining"
        case ordineNoteText = "ordine_note_text"
        case ordineNotePlaceholder = "ordine_note_placeholder"
        case notePlaceholder = "note_placeholder"
        case durataTitle = "durata_title"
        case durataNotice = "durata_notice"
        case durataStartTitle = "durata_start_title"
        case durataStartTime = "durata_start_time"
        case durataEndTitle = "durata_end_title"
        case durataEndTime = "durata_end_time"
        case durataGameOptions = "durata_game_options"
        case durataIntervalOptions = "durata_interval_options"
        case durataRigoriOptions = "durata_rigori_options"
        case durataRows = "durata_rows"
        case documentOptions = "document_options"
        case staffRoleOptions = "staff_role_options"
        case listaGaraHome = "lista_gara_home"
        case listaGaraAway = "lista_gara_away"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let designazioneRaw = Self.decodeString(container, forKey: .designazioneId)
        let refertoRaw = Self.decodeString(container, forKey: .refertoId)

        let roleKindRaw = Self.decodeOptionalString(container, forKey: .roleKind)
        let roleLabelRaw = Self.decodeOptionalString(container, forKey: .roleLabel)
        let actionKindRaw = Self.decodeOptionalString(container, forKey: .actionKind)
        let actionLabelRaw = Self.decodeOptionalString(container, forKey: .actionLabel)
        let statusLabelRaw = Self.decodeOptionalString(container, forKey: .statusLabel)

        let canPrintRaw = Self.decodeBool(container, forKey: .canPrint, default: false)
        let canSaveRaw = Self.decodeBool(container, forKey: .canSave, default: false)

        let fallbackItem = RefertoSintesiDTO(
            idGara: designazioneRaw,
            idDesignazione: designazioneRaw,
            date: "",
            time: "",
            activity: "",
            category: "",
            group: "",
            giornata: "",
            homeTeam: "",
            awayTeam: "",
            numero: "",
            canCompile: canSaveRaw,
            canInfo: !canSaveRaw,
            roleKind: roleKindRaw,
            roleLabel: roleLabelRaw,
            actionKind: actionKindRaw,
            actionLabel: actionLabelRaw,
            statusLabel: statusLabelRaw,
            canPrint: canPrintRaw,
            canSubmit: false,
            isResume: actionKindRaw == "resume"
        )

        let decodedItem = (try? container.decode(RefertoSintesiDTO.self, forKey: .item)) ?? fallbackItem
        item = decodedItem

        let decodedCanSave = Self.decodeBool(container, forKey: .canSave, default: decodedItem.canCompile)
        var decodedSegnalazioneOptions = Self.decodeStringArray(container, forKey: .segnalazioneOptions)
        if decodedSegnalazioneOptions.isEmpty, decodedCanSave {
            decodedSegnalazioneOptions = ["1", "2"]
        }

        refertoId = Self.nonEmpty(refertoRaw)
        designazioneId = Self.nonEmpty(designazioneRaw)
        reportTitle = Self.decodeString(container, forKey: .reportTitle)
        gameFields = (try? container.decode([CampoModuloDTO].self, forKey: .gameFields)) ?? []
        officials = (try? container.decode([[String: String]].self, forKey: .officials)) ?? []
        segnalazioneTitle = Self.decodeString(container, forKey: .segnalazioneTitle)
        segnalazioneNotice = Self.decodeString(container, forKey: .segnalazioneNotice)
        segnalazioneOptions = decodedSegnalazioneOptions
        segnalazioneValue = Self.decodeString(container, forKey: .segnalazioneValue)
        noteTitle = Self.decodeString(container, forKey: .noteTitle)
        noteLimit = Self.decodeInt(container, forKey: .noteLimit, default: 4000)
        noteRemaining = Self.decodeString(container, forKey: .noteRemaining)
        noteText = Self.decodeString(container, forKey: .noteText)
        canPrint = Self.decodeBool(container, forKey: .canPrint, default: decodedItem.canPrint ?? false)
        canSave = decodedCanSave
        templateFields = (try? container.decode([CampoTemplateRefertoDTO].self, forKey: .templateFields)) ?? []
        roleKind = Self.decodeOptionalString(container, forKey: .roleKind) ?? decodedItem.roleKind
        roleLabel = Self.decodeOptionalString(container, forKey: .roleLabel) ?? decodedItem.roleLabel
        actionKind = Self.decodeOptionalString(container, forKey: .actionKind) ?? decodedItem.actionKind
        actionLabel = Self.decodeOptionalString(container, forKey: .actionLabel) ?? decodedItem.actionLabel
        statusLabel = Self.decodeOptionalString(container, forKey: .statusLabel) ?? decodedItem.statusLabel
        saveLabel = Self.decodeOptionalString(container, forKey: .saveLabel)
        saveHint = Self.decodeOptionalString(container, forKey: .saveHint)
        readOnlyHint = Self.decodeOptionalString(container, forKey: .readOnlyHint)
        flowTabs = Self.decodeStringArray(container, forKey: .flowTabs)
        currentTab = Self.decodeString(container, forKey: .currentTab)
        svolgimentoTitle = Self.decodeString(container, forKey: .svolgimentoTitle)
        svolgimentoNotice = Self.decodeString(container, forKey: .svolgimentoNotice)
        svolgimentoOptions = (try? container.decode([RefertoSvolgimentoOptionDTO].self, forKey: .svolgimentoOptions)) ?? []
        svolgimentoValue = Self.decodeString(container, forKey: .svolgimentoValue)
        svolgimentoRequired = Self.decodeBool(container, forKey: .svolgimentoRequired, default: false)
        ordineTitle = Self.decodeString(container, forKey: .ordineTitle)
        ordineNotice = Self.decodeString(container, forKey: .ordineNotice)
        ordineOptions = (try? container.decode([RefertoSvolgimentoOptionDTO].self, forKey: .ordineOptions)) ?? []
        ordineValue = Self.decodeString(container, forKey: .ordineValue)
        ordineRequired = Self.decodeBool(container, forKey: .ordineRequired, default: false)
        ambulanzaTitle = Self.decodeString(container, forKey: .ambulanzaTitle)
        ambulanzaNotice = Self.decodeString(container, forKey: .ambulanzaNotice)
        ambulanzaOptions = (try? container.decode([RefertoSvolgimentoOptionDTO].self, forKey: .ambulanzaOptions)) ?? []
        ambulanzaValue = Self.decodeString(container, forKey: .ambulanzaValue)
        ambulanzaRequired = Self.decodeBool(container, forKey: .ambulanzaRequired, default: false)
        ordineNoteTitle = Self.decodeString(container, forKey: .ordineNoteTitle)
        ordineNoteLimit = Self.decodeInt(container, forKey: .ordineNoteLimit, default: 2000)
        ordineNoteRemaining = Self.decodeString(container, forKey: .ordineNoteRemaining)
        ordineNoteText = Self.decodeString(container, forKey: .ordineNoteText)
        ordineNotePlaceholder = Self.decodeString(container, forKey: .ordineNotePlaceholder)
        notePlaceholder = Self.decodeString(container, forKey: .notePlaceholder)
        durataTitle = Self.decodeString(container, forKey: .durataTitle)
        durataNotice = Self.decodeString(container, forKey: .durataNotice)
        durataStartTitle = Self.decodeString(container, forKey: .durataStartTitle)
        durataStartTime = Self.decodeString(container, forKey: .durataStartTime)
        durataEndTitle = Self.decodeString(container, forKey: .durataEndTitle)
        durataEndTime = Self.decodeString(container, forKey: .durataEndTime)
        durataGameOptions = (try? container.decode([RefertoSelectOptionDTO].self, forKey: .durataGameOptions)) ?? []
        durataIntervalOptions = (try? container.decode([RefertoSelectOptionDTO].self, forKey: .durataIntervalOptions)) ?? []
        durataRigoriOptions = (try? container.decode([RefertoSelectOptionDTO].self, forKey: .durataRigoriOptions)) ?? []
        durataRows = (try? container.decode([RefertoDurataRowDTO].self, forKey: .durataRows)) ?? []
        documentOptions = try? container.decode([RefertoSelectOptionDTO].self, forKey: .documentOptions)
        staffRoleOptions = try? container.decode([RefertoSelectOptionDTO].self, forKey: .staffRoleOptions)
        listaGaraHome = try? container.decode(RefertoListeGaraSquadraDTO.self, forKey: .listaGaraHome)
        listaGaraAway = try? container.decode(RefertoListeGaraSquadraDTO.self, forKey: .listaGaraAway)
    }

    private static func decodeString(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> String {
        if let value = try? container.decode(String.self, forKey: key) {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            let normalized = value.rounded()
            if abs(value - normalized) < 0.000_001 {
                return String(Int(normalized))
            }
            return String(value)
        }
        if let value = try? container.decode(Bool.self, forKey: key) {
            return value ? "1" : "0"
        }
        return ""
    }

    private static func decodeOptionalString(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> String? {
        nonEmpty(decodeString(container, forKey: key))
    }

    private static func decodeInt(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys, default defaultValue: Int) -> Int {
        if let value = try? container.decode(Int.self, forKey: key) {
            return value
        }
        let text = decodeString(container, forKey: key)
        if let parsed = Int(text) {
            return parsed
        }
        return defaultValue
    }

    private static func decodeBool(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys, default defaultValue: Bool) -> Bool {
        if let value = try? container.decode(Bool.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return value != 0
        }
        let text = decodeString(container, forKey: key).lowercased()
        switch text {
        case "1", "true", "yes", "y", "si", "s":
            return true
        case "0", "false", "no", "n":
            return false
        default:
            return defaultValue
        }
    }

    private static func decodeStringArray(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> [String] {
        if let values = try? container.decode([String].self, forKey: key) {
            return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        if let values = try? container.decode([Int].self, forKey: key) {
            return values.map(String.init)
        }
        if let values = try? container.decode([Double].self, forKey: key) {
            return values.map {
                let rounded = $0.rounded()
                if abs($0 - rounded) < 0.000_001 {
                    return String(Int(rounded))
                }
                return String($0)
            }
        }
        return []
    }

    private static func nonEmpty(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }
}

struct RefertoSvolgimentoOptionDTO: Codable, Identifiable {
    let value: String
    let title: String
    let description: String

    var id: String { value }
}

struct RefertoSelectOptionDTO: Codable, Identifiable {
    let value: String
    let title: String

    var id: String { value }
}

struct RefertoDurataRowDTO: Codable, Identifiable {
    let phaseId: String
    let periodNumber: Int
    let markerType: String
    let minutes: String
    let durationType: String
    let note: String
    let startTime: String
    let endTime: String
    let order: Int

    var id: String { "\(phaseId)-\(periodNumber)-\(markerType)-\(order)" }

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

struct RefertoPersonaDisponibileDTO: Codable, Identifiable {
    let personId: String
    let teamId: String
    let firstName: String
    let lastName: String
    let birthDate: String
    let sex: String
    let sexExtended: String
    let personType: String
    let matricola: String
    let birthplaceCode: String
    let birthplaceLabel: String
    let taxCode: String
    let label: String

    var id: String { personId }

    enum CodingKeys: String, CodingKey {
        case personId = "person_id"
        case teamId = "team_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case birthDate = "birth_date"
        case sex
        case sexExtended = "sex_extended"
        case personType = "person_type"
        case matricola
        case birthplaceCode = "birthplace_code"
        case birthplaceLabel = "birthplace_label"
        case taxCode = "tax_code"
        case label
    }
}

struct RefertoListaGiocatoreDTO: Codable, Identifiable {
    let order: Int
    let shirtNumber: String
    let personId: String
    let captainCode: String
    let documentType: String
    let documentNumber: String

    var id: String { "player-\(order)" }

    enum CodingKeys: String, CodingKey {
        case order
        case shirtNumber = "shirt_number"
        case personId = "person_id"
        case captainCode = "captain_code"
        case documentType = "document_type"
        case documentNumber = "document_number"
    }
}

struct RefertoListaDirigenteDTO: Codable, Identifiable {
    let order: Int
    let roleId: String
    let personId: String
    let documentType: String
    let documentNumber: String

    var id: String { "staff-\(order)" }

    enum CodingKeys: String, CodingKey {
        case order
        case roleId = "role_id"
        case personId = "person_id"
        case documentType = "document_type"
        case documentNumber = "document_number"
    }
}

struct RefertoListeGaraSquadraDTO: Codable {
    let teamId: String
    let teamName: String
    let availablePeople: [RefertoPersonaDisponibileDTO]
    let starters: [RefertoListaGiocatoreDTO]
    let substitutes: [RefertoListaGiocatoreDTO]
    let staff: [RefertoListaDirigenteDTO]

    enum CodingKeys: String, CodingKey {
        case teamId = "team_id"
        case teamName = "team_name"
        case availablePeople = "available_people"
        case starters
        case substitutes
        case staff
    }
}

struct EsitoOperazioneRefertoDTO: Codable {
    let ok: Bool
    let warning: Bool?
    let message: String
    let detail: DettaglioRefertoDTO
}

struct RefertoSintesiDTO: Codable, Identifiable {
    let idGara: String
    let idDesignazione: String
    let date: String
    let time: String
    let activity: String
    let category: String
    let group: String
    let giornata: String
    let homeTeam: String
    let awayTeam: String
    let numero: String
    let canCompile: Bool
    let canInfo: Bool
    let roleKind: String?
    let roleLabel: String?
    let actionKind: String?
    let actionLabel: String?
    let statusLabel: String?
    let canPrint: Bool?
    let canSubmit: Bool?
    let isResume: Bool?

    var id: String { idDesignazione }

    enum CodingKeys: String, CodingKey {
        case idGara = "id_gara"
        case idDesignazione = "id_designazione"
        case date
        case time
        case activity
        case category
        case group
        case giornata
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case numero
        case canCompile = "can_compile"
        case canInfo = "can_info"
        case roleKind = "role_kind"
        case roleLabel = "role_label"
        case actionKind = "action_kind"
        case actionLabel = "action_label"
        case statusLabel = "status_label"
        case canPrint = "can_print"
        case canSubmit = "can_submit"
        case isResume = "is_resume"
    }
}

struct CampoTemplateRefertoDTO: Codable, Identifiable {
    let label: String
    let value: String
    let editable: String

    var id: String { "\(label)|\(value)|\(editable)" }
}

struct EsitoOperazioneDTO: Codable {
    let ok: Bool
    let message: String
    let requiresRelogin: Bool?

    enum CodingKeys: String, CodingKey {
        case ok
        case message
        case requiresRelogin = "requires_relogin"
    }
}

struct IbanConfigDTO: Codable {
    let title: String
    let currentIban: String
    let currentStatus: String
    let declarationText: String
    let introText: String
    let maxSizeBytes: Int
    let allowedExtensions: [String]
    let submitLabel: String

    enum CodingKeys: String, CodingKey {
        case title
        case currentIban = "current_iban"
        case currentStatus = "current_status"
        case declarationText = "declaration_text"
        case introText = "intro_text"
        case maxSizeBytes = "max_size_bytes"
        case allowedExtensions = "allowed_extensions"
        case submitLabel = "submit_label"
    }
}

struct CertificateRenewalConfigDTO: Codable {
    let title: String
    let currentType: String
    let currentExpiry: String
    let currentIssuer: String
    let allowedExtensions: [String]
    let maxSizeBytes: Int
    let noteMaxLen: Int
    let validatorLabel: String
    let introText: String
    let legalText: String
    let types: [OpzioneModuloDTO]

    enum CodingKeys: String, CodingKey {
        case title
        case currentType = "current_type"
        case currentExpiry = "current_expiry"
        case currentIssuer = "current_issuer"
        case allowedExtensions = "allowed_extensions"
        case maxSizeBytes = "max_size_bytes"
        case noteMaxLen = "note_max_len"
        case validatorLabel = "validator_label"
        case introText = "intro_text"
        case legalText = "legal_text"
        case types
    }
}

struct IndisponibilitaConfigDTO: Codable {
    let title: String
    let sectionTitle: String
    let validatorLabel: String
    let introText: String
    let legalText: String
    let allowedExtensions: [String]
    let maxSizeBytes: Int
    let noteMaxLen: Int
    let maxDays: Int
    let types: [OpzioneModuloDTO]
    let reasons: [OpzioneModuloDTO]

    enum CodingKeys: String, CodingKey {
        case title
        case sectionTitle = "section_title"
        case validatorLabel = "validator_label"
        case introText = "intro_text"
        case legalText = "legal_text"
        case allowedExtensions = "allowed_extensions"
        case maxSizeBytes = "max_size_bytes"
        case noteMaxLen = "note_max_len"
        case maxDays = "max_days"
        case types
        case reasons
    }
}

struct CongedoConfigDTO: Codable {
    let title: String
    let sectionTitle: String
    let validatorLabel: String
    let introText: String
    let legalText: String
    let allowedExtensions: [String]
    let maxSizeBytes: Int
    let noteMaxLen: Int
    let maxDays: Int
    let reasons: [OpzioneModuloDTO]

    enum CodingKeys: String, CodingKey {
        case title
        case sectionTitle = "section_title"
        case validatorLabel = "validator_label"
        case introText = "intro_text"
        case legalText = "legal_text"
        case allowedExtensions = "allowed_extensions"
        case maxSizeBytes = "max_size_bytes"
        case noteMaxLen = "note_max_len"
        case maxDays = "max_days"
        case reasons
    }
}

struct PreclusioneSearchConfigDTO: Codable {
    let fieldOptions: [OpzioneModuloDTO]
    let scopeOptions: [OpzioneModuloDTO]
    let resultOptions: [OpzioneModuloDTO]

    enum CodingKeys: String, CodingKey {
        case fieldOptions = "field_options"
        case scopeOptions = "scope_options"
        case resultOptions = "result_options"
    }
}

struct PreclusioneConfigDTO: Codable {
    let title: String
    let sectionTitle: String
    let noteMaxLen: Int
    let introText: String
    let legalText: String
    let specialCases: [OpzioneModuloDTO]
    let types: [OpzioneModuloDTO]
    let societaSearch: PreclusioneSearchConfigDTO
    let squadraSearch: PreclusioneSearchConfigDTO
    let impiantoSearch: PreclusioneSearchConfigDTO

    enum CodingKeys: String, CodingKey {
        case title
        case sectionTitle = "section_title"
        case noteMaxLen = "note_max_len"
        case introText = "intro_text"
        case legalText = "legal_text"
        case specialCases = "special_cases"
        case types
        case societaSearch = "societa_search"
        case squadraSearch = "squadra_search"
        case impiantoSearch = "impianto_search"
    }
}

struct RisultatoPreclusioneDTO: Codable, Identifiable {
    let itemId: String
    let label: String

    var id: String { itemId }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case label
    }
}

struct RicercaPreclusioneDTO: Codable {
    let results: [RisultatoPreclusioneDTO]
}

struct DomandeConfigDTO: Codable {
    let title: String
    let sectionTitle: String
    let introText: String
    let allowedExtensions: [String]
    let maxSizeBytes: Int
    let noteMaxLen: Int
    let options: [OpzioneModuloDTO]

    enum CodingKeys: String, CodingKey {
        case title
        case sectionTitle = "section_title"
        case introText = "intro_text"
        case allowedExtensions = "allowed_extensions"
        case maxSizeBytes = "max_size_bytes"
        case noteMaxLen = "note_max_len"
        case options
    }
}

struct DocumentoConfigItemDTO: Codable, Identifiable {
    let typeId: String
    let title: String
    let statusLabel: String
    let statusCode: String
    let uploadedAt: String
    let attachmentUrl: String
    let actionLabel: String

    var id: String { typeId }

    enum CodingKeys: String, CodingKey {
        case typeId = "type_id"
        case title
        case statusLabel = "status_label"
        case statusCode = "status_code"
        case uploadedAt = "uploaded_at"
        case attachmentUrl = "attachment_url"
        case actionLabel = "action_label"
    }
}

struct DocumentsConfigDTO: Codable {
    let title: String
    let maxSizeBytes: Int
    let allowedExtensions: [String]
    let items: [DocumentoConfigItemDTO]

    enum CodingKeys: String, CodingKey {
        case title
        case maxSizeBytes = "max_size_bytes"
        case allowedExtensions = "allowed_extensions"
        case items
    }
}

struct AccountPasswordConfigDTO: Codable {
    let title: String
    let sectionTitle: String
    let submitLabel: String
    let rules: [String]

    enum CodingKeys: String, CodingKey {
        case title
        case sectionTitle = "section_title"
        case submitLabel = "submit_label"
        case rules
    }
}

struct FileSelezionatoApp: Identifiable, Equatable {
    let id = UUID()
    let fileName: String
    let mimeType: String
    let data: Data
}

struct EventoItemDTO: Codable, Identifiable {
    let eventId: String
    let eventType: String
    let startDate: String
    let startTime: String
    let endDate: String
    let endTime: String
    let place: String
    let note: String
    let attachmentUrl: String
    let attachmentLabel: String
    let statusLabel: String
    let actionLabel: String
    let canAccept: Bool

    var id: String { eventId }

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case eventType = "event_type"
        case startDate = "start_date"
        case startTime = "start_time"
        case endDate = "end_date"
        case endTime = "end_time"
        case place
        case note
        case attachmentUrl = "attachment_url"
        case attachmentLabel = "attachment_label"
        case statusLabel = "status_label"
        case actionLabel = "action_label"
        case canAccept = "can_accept"
    }
}

struct EventiActionResponseDTO: Codable {
    let ok: Bool
    let items: [EventoItemDTO]
}
