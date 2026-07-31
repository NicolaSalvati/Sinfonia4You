import Foundation

// Opzione della tendina "Stagione" esposta dal portale nella scheda tecnica.
// Mantengo sia id sia label per riutilizzare esattamente i valori richiesti dal backend.
struct TechnicalSheetSeasonOptionDTO: Codable, Identifiable, Hashable {
    let id: String
    let label: String
}

struct TechnicalSheetContextDTO: Codable {
    let associato: String
    let section: String
    let seasonId: String
    let seasonLabel: String
    let seasonOptions: [TechnicalSheetSeasonOptionDTO]
    let structureLabel: String
    let departureAddress: String

    enum CodingKeys: String, CodingKey {
        case associato
        case section
        case seasonId = "season_id"
        case seasonLabel = "season_label"
        case seasonOptions = "season_options"
        case structureLabel = "structure_label"
        case departureAddress = "departure_address"
    }
}

struct TechnicalSheetVotesDTO: Codable {
    let average: String
    let oaAverage: String
    let otAverage: String
    let oaCount: Int
    let otCount: Int
    let ratedMatchesCount: Int
    let oaFilesCount: Int
    let otFilesCount: Int
    let attachmentsCount: Int
    let pdfAvailable: Bool
    let isAvailable: Bool
    let statusLabel: String
    let sectionLabel: String

    enum CodingKeys: String, CodingKey {
        case average
        case oaAverage = "oa_average"
        case otAverage = "ot_average"
        case oaCount = "oa_count"
        case otCount = "ot_count"
        case ratedMatchesCount = "rated_matches_count"
        case oaFilesCount = "oa_files_count"
        case otFilesCount = "ot_files_count"
        case attachmentsCount = "attachments_count"
        case pdfAvailable = "pdf_available"
        case isAvailable = "is_available"
        case statusLabel = "status_label"
        case sectionLabel = "section_label"
    }
}

struct TechnicalSheetVoteItemDTO: Codable, Identifiable, Hashable {
    let matchId: String
    let role: String
    let roleLabel: String
    let date: String
    let time: String
    let category: String
    let group: String
    let giornata: String
    let giornataLabel: String
    let homeTeam: String
    let awayTeam: String
    let matchLabel: String
    let oaVote: String
    let oaVoteValue: Double
    let otVote: String
    let otVoteValue: Double
    let nominatives: [String]
    let oaRelationId: String
    let otRelationId: String
    let oaHasAttachment: Bool
    let otHasAttachment: Bool

    var id: String { matchId.isEmpty ? matchLabel : matchId }

    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case role
        case roleLabel = "role_label"
        case date
        case time
        case category
        case group
        case giornata
        case giornataLabel = "giornata_label"
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case matchLabel = "match_label"
        case oaVote = "oa_vote"
        case oaVoteValue = "oa_vote_value"
        case otVote = "ot_vote"
        case otVoteValue = "ot_vote_value"
        case nominatives
        case oaRelationId = "oa_relation_id"
        case otRelationId = "ot_relation_id"
        case oaHasAttachment = "oa_has_attachment"
        case otHasAttachment = "ot_has_attachment"
    }
}

struct TechnicalSheetVotesScreenDTO: Codable {
    let context: TechnicalSheetContextDTO
    let summary: TechnicalSheetVotesDTO
    let items: [TechnicalSheetVoteItemDTO]
}

struct TechnicalSheetOverviewSummaryDTO: Codable {
    let matchesCount: Int
    let completedMatches: Int
    let reimbursementsCount: Int
    let totalRefunds: String
    let totalDistance: String
    let averageRefund: String
    let averageDistance: String

    enum CodingKeys: String, CodingKey {
        case matchesCount = "matches_count"
        case completedMatches = "completed_matches"
        case reimbursementsCount = "reimbursements_count"
        case totalRefunds = "total_refunds"
        case totalDistance = "total_distance"
        case averageRefund = "average_refund"
        case averageDistance = "average_distance"
    }
}

struct TechnicalSheetOverviewDTO: Codable {
    let context: TechnicalSheetContextDTO
    let votes: TechnicalSheetVotesDTO
    let summary: TechnicalSheetOverviewSummaryDTO
}

struct TechnicalSheetMatchSummaryDTO: Codable {
    let matchesCount: Int
    let completedMatches: Int
    let pdfAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case matchesCount = "matches_count"
        case completedMatches = "completed_matches"
        case pdfAvailable = "pdf_available"
    }
}

struct TechnicalSheetMatchDTO: Codable, Identifiable, Hashable {
    let matchId: String
    let role: String
    let roleLabel: String
    let date: String
    let time: String
    let category: String
    let group: String
    let giornata: String
    let giornataLabel: String
    let homeTeam: String
    let awayTeam: String
    let matchLabel: String
    let result: String
    let committee: String
    let status: String

    var id: String { matchId.isEmpty ? matchLabel : matchId }

    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case role
        case roleLabel = "role_label"
        case date
        case time
        case category
        case group
        case giornata
        case giornataLabel = "giornata_label"
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case matchLabel = "match_label"
        case result
        case committee
        case status
    }
}

struct TechnicalSheetMatchesDTO: Codable {
    let context: TechnicalSheetContextDTO
    let summary: TechnicalSheetMatchSummaryDTO
    let items: [TechnicalSheetMatchDTO]
}

struct TechnicalSheetReimbursementSummaryDTO: Codable {
    let reimbursementsCount: Int
    let approvedCount: Int
    let totalRefunds: String
    let totalDistance: String
    let averageRefund: String
    let averageDistance: String
    let statisticsPdfAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case reimbursementsCount = "reimbursements_count"
        case approvedCount = "approved_count"
        case totalRefunds = "total_refunds"
        case totalDistance = "total_distance"
        case averageRefund = "average_refund"
        case averageDistance = "average_distance"
        case statisticsPdfAvailable = "statistics_pdf_available"
    }
}

struct TechnicalSheetReimbursementDTO: Codable, Identifiable, Hashable {
    let matchId: String
    let role: String
    let roleLabel: String
    let date: String
    let time: String
    let category: String
    let group: String
    let giornata: String
    let giornataLabel: String
    let homeTeam: String
    let awayTeam: String
    let matchLabel: String
    let approval: String
    let distance: String
    let distanceValue: Double
    let refund: String
    let refundValue: Double
    let status: String

    var id: String { matchId.isEmpty ? matchLabel : matchId }

    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case role
        case roleLabel = "role_label"
        case date
        case time
        case category
        case group
        case giornata
        case giornataLabel = "giornata_label"
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case matchLabel = "match_label"
        case approval
        case distance
        case distanceValue = "distance_value"
        case refund
        case refundValue = "refund_value"
        case status
    }
}

struct TechnicalSheetReimbursementsDTO: Codable {
    let context: TechnicalSheetContextDTO
    let summary: TechnicalSheetReimbursementSummaryDTO
    let note: String
    let items: [TechnicalSheetReimbursementDTO]
}

struct TechnicalSheetAnagraphicsDTO: Codable {
    let context: TechnicalSheetContextDTO
    let text: String
    let pdfAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case context
        case text
        case pdfAvailable = "pdf_available"
    }
}

struct TechnicalSheetDetailFieldDTO: Codable, Identifiable, Hashable {
    let label: String
    let value: String

    var id: String { "\(label)|\(value)" }
}

struct TechnicalSheetRelatedAssignmentDTO: Codable, Identifiable, Hashable {
    let role: String
    let name: String
    let section: String
    let phone: String

    var id: String { "\(role)|\(name)|\(section)|\(phone)" }
}

struct TechnicalSheetMatchDetailDTO: Codable {
    let context: TechnicalSheetContextDTO
    let match: TechnicalSheetMatchDTO
    let reimbursement: TechnicalSheetReimbursementDTO?
    let detailFields: [TechnicalSheetDetailFieldDTO]
    let relatedAssignments: [TechnicalSheetRelatedAssignmentDTO]

    enum CodingKeys: String, CodingKey {
        case context
        case match
        case reimbursement
        case detailFields = "detail_fields"
        case relatedAssignments = "related_assignments"
    }
}
