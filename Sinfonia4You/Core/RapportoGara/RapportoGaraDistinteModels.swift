import Foundation

enum DistintaProcessingStateRapportoGara: String, Codable, CaseIterable, Identifiable {
    case processing
    case ready
    case needsReview
    case error

    nonisolated var id: String { rawValue }

    nonisolated var titolo: String {
        switch self {
        case .processing:
            return "In elaborazione"
        case .ready:
            return "Pronta"
        case .needsReview:
            return "Da rivedere"
        case .error:
            return "Errore OCR"
        }
    }
}

enum DistintaIssueSeverityRapportoGara: String, Codable, CaseIterable, Identifiable {
    case warning
    case error

    nonisolated var id: String { rawValue }

    nonisolated var titolo: String {
        switch self {
        case .warning:
            return "Avviso"
        case .error:
            return "Errore"
        }
    }
}

struct DistintaIssueRapportoGara: Codable, Identifiable, Hashable {
    let id: UUID
    var severity: DistintaIssueSeverityRapportoGara
    var message: String
    var section: String
    var rawValue: String?

    nonisolated init(
        id: UUID = UUID(),
        severity: DistintaIssueSeverityRapportoGara,
        message: String,
        section: String = "",
        rawValue: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.message = message
        self.section = section
        self.rawValue = rawValue
    }
}

enum DistintaDocumentKindRapportoGara: String, Codable, CaseIterable, Identifiable {
    case cartaIdentita
    case patente
    case tesseraFigc
    case altro

    nonisolated var id: String { rawValue }

    nonisolated var titolo: String {
        switch self {
        case .cartaIdentita:
            return "Carta d'identita"
        case .patente:
            return "Patente"
        case .tesseraFigc:
            return "Tessera FIGC"
        case .altro:
            return "Altro"
        }
    }
}

enum DistintaRoleKindRapportoGara: String, Codable, CaseIterable, Identifiable {
    case dirigenteAccompagnatoreUfficiale
    case dirigenteAddettoUfficialeGara
    case medicoSociale
    case allenatore
    case allenatoreInSeconda
    case massaggiatore
    case preparatoreAtletico
    case preparatorePortieri
    case altro

    nonisolated var id: String { rawValue }

    nonisolated var titolo: String {
        switch self {
        case .dirigenteAccompagnatoreUfficiale:
            return "Dirigente accompagnatore ufficiale"
        case .dirigenteAddettoUfficialeGara:
            return "Dirigente addetto ufficiale gara"
        case .medicoSociale:
            return "Medico sociale"
        case .allenatore:
            return "Allenatore"
        case .allenatoreInSeconda:
            return "Allenatore in seconda"
        case .massaggiatore:
            return "Massaggiatore"
        case .preparatoreAtletico:
            return "Preparatore atletico"
        case .preparatorePortieri:
            return "Preparatore portieri"
        case .altro:
            return "Altro staff"
        }
    }
}

struct DistintaSourceImageRapportoGara: Codable, Hashable {
    var fileName: String
    var importedAt: Date
    var pixelWidth: Int
    var pixelHeight: Int
}

struct DistintaGiocatoreRapportoGara: Codable, Identifiable, Hashable {
    let id: UUID
    var order: Int
    var shirtNumber: String
    var firstName: String
    var lastName: String
    var birthDate: String
    var isStarter: Bool
    var captainCode: String
    var matricola: String
    var documentKind: DistintaDocumentKindRapportoGara
    var documentTypeRaw: String
    var documentNumber: String
    var documentReleasedBy: String
    var rawLine: String

    nonisolated init(
        id: UUID = UUID(),
        order: Int,
        shirtNumber: String = "",
        firstName: String = "",
        lastName: String = "",
        birthDate: String = "",
        isStarter: Bool = false,
        captainCode: String = "",
        matricola: String = "",
        documentKind: DistintaDocumentKindRapportoGara = .altro,
        documentTypeRaw: String = "",
        documentNumber: String = "",
        documentReleasedBy: String = "",
        rawLine: String = ""
    ) {
        self.id = id
        self.order = order
        self.shirtNumber = shirtNumber
        self.firstName = firstName
        self.lastName = lastName
        self.birthDate = birthDate
        self.isStarter = isStarter
        self.captainCode = captainCode
        self.matricola = matricola
        self.documentKind = documentKind
        self.documentTypeRaw = documentTypeRaw
        self.documentNumber = documentNumber
        self.documentReleasedBy = documentReleasedBy
        self.rawLine = rawLine
    }

    nonisolated var fullName: String {
        [lastName, firstName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    nonisolated var captainLabel: String {
        switch captainCode.uppercased() {
        case "C", "K":
            return "Capitano"
        case "V", "VK":
            return "Vice-capitano"
        default:
            return ""
        }
    }
}

struct DistintaStaffRapportoGara: Codable, Identifiable, Hashable {
    let id: UUID
    var order: Int
    var roleKind: DistintaRoleKindRapportoGara
    var roleRaw: String
    var firstName: String
    var lastName: String
    var documentKind: DistintaDocumentKindRapportoGara
    var documentTypeRaw: String
    var documentNumber: String
    var documentReleasedBy: String
    var rawLine: String

    nonisolated init(
        id: UUID = UUID(),
        order: Int,
        roleKind: DistintaRoleKindRapportoGara = .altro,
        roleRaw: String = "",
        firstName: String = "",
        lastName: String = "",
        documentKind: DistintaDocumentKindRapportoGara = .altro,
        documentTypeRaw: String = "",
        documentNumber: String = "",
        documentReleasedBy: String = "",
        rawLine: String = ""
    ) {
        self.id = id
        self.order = order
        self.roleKind = roleKind
        self.roleRaw = roleRaw
        self.firstName = firstName
        self.lastName = lastName
        self.documentKind = documentKind
        self.documentTypeRaw = documentTypeRaw
        self.documentNumber = documentNumber
        self.documentReleasedBy = documentReleasedBy
        self.rawLine = rawLine
    }

    nonisolated var fullName: String {
        [lastName, firstName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    nonisolated var displayRole: String {
        let roleRaw = roleRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        return roleRaw.isEmpty ? roleKind.titolo : roleRaw
    }
}

struct DistintaSquadraRapportoGara: Codable, Hashable {
    var processingState: DistintaProcessingStateRapportoGara
    var sourceImage: DistintaSourceImageRapportoGara?
    var teamLabelOCR: String
    var lastProcessedAt: Date?
    var players: [DistintaGiocatoreRapportoGara]
    var staff: [DistintaStaffRapportoGara]
    var issues: [DistintaIssueRapportoGara]
    var lastErrorMessage: String

    init(
        processingState: DistintaProcessingStateRapportoGara = .processing,
        sourceImage: DistintaSourceImageRapportoGara? = nil,
        teamLabelOCR: String = "",
        lastProcessedAt: Date? = nil,
        players: [DistintaGiocatoreRapportoGara] = [],
        staff: [DistintaStaffRapportoGara] = [],
        issues: [DistintaIssueRapportoGara] = [],
        lastErrorMessage: String = ""
    ) {
        self.processingState = processingState
        self.sourceImage = sourceImage
        self.teamLabelOCR = teamLabelOCR
        self.lastProcessedAt = lastProcessedAt
        self.players = players
        self.staff = staff
        self.issues = issues
        self.lastErrorMessage = lastErrorMessage
    }

    var starters: [DistintaGiocatoreRapportoGara] {
        players.filter(\.isStarter).sorted { $0.order < $1.order }
    }

    var substitutes: [DistintaGiocatoreRapportoGara] {
        players.filter { !$0.isStarter }.sorted { $0.order < $1.order }
    }

    var orderedPlayers: [DistintaGiocatoreRapportoGara] {
        players.sorted { $0.order < $1.order }
    }

    var staffGrouped: [(DistintaRoleKindRapportoGara, [DistintaStaffRapportoGara])] {
        let grouped = Dictionary(grouping: staff) { $0.roleKind }
        return grouped
            .map { role, items in
                (role, items.sorted { $0.order < $1.order })
            }
            .sorted { left, right in
                let leftOrder = left.1.first?.order ?? .max
                let rightOrder = right.1.first?.order ?? .max
                if leftOrder == rightOrder {
                    return left.0.titolo < right.0.titolo
                }
                return leftOrder < rightOrder
            }
    }

    var alertCount: Int {
        issues.count + (lastErrorMessage.isEmpty ? 0 : 1)
    }
}

struct DistinteSessioneRapportoGara: Codable, Hashable {
    var casa: DistintaSquadraRapportoGara?
    var ospiti: DistintaSquadraRapportoGara?

    static let empty = DistinteSessioneRapportoGara(casa: nil, ospiti: nil)

    func slot(for lato: LatoSquadraRapportoGara) -> DistintaSquadraRapportoGara? {
        switch lato {
        case .casa:
            return casa
        case .ospiti:
            return ospiti
        }
    }

    mutating func set(_ slot: DistintaSquadraRapportoGara?, for lato: LatoSquadraRapportoGara) {
        switch lato {
        case .casa:
            casa = slot
        case .ospiti:
            ospiti = slot
        }
    }

    var hasContent: Bool {
        casa != nil || ospiti != nil
    }
}

struct RapportoGaraDistintaOCRFragment: Hashable {
    var text: String
    var minX: Double
    var maxX: Double
    var midY: Double
}

struct RapportoGaraDistintaOCRRow: Hashable {
    var text: String
    var fragments: [RapportoGaraDistintaOCRFragment]
    var order: Int
}

struct RapportoGaraDistintaParsingResult: Hashable {
    var teamLabelOCR: String
    var players: [DistintaGiocatoreRapportoGara]
    var staff: [DistintaStaffRapportoGara]
    var issues: [DistintaIssueRapportoGara]
    var processingState: DistintaProcessingStateRapportoGara
    var errorMessage: String
}
