//
//  AppSession.swift
//  Sinfonia4You
//
//  Modelli condivisi tra autenticazione, home e sessione applicativa.
//

import Foundation

struct ProfiloArbitro: Codable {
    let fullName: String
    let firstName: String
    let lastName: String
    let code: String
    let section: String
    let role: String
    let initials: String
    let lastAccessLabel: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case code
        case section
        case role
        case initials
        case lastAccessLabel = "last_access_label"
    }
}

struct AzioneRapidaHomeDTO: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemIcon: String
    let gradient: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case systemIcon = "system_icon"
        case gradient
    }
}

struct NotiziaHomeDTO: Codable, Identifiable {
    let id: String
    let accentColor: String
    let title: String
    let excerpt: String
    let date: String

    enum CodingKeys: String, CodingKey {
        case id
        case accentColor = "accent_color"
        case title
        case excerpt
        case date
    }
}

struct GaraHomeDTO: Codable, Identifiable {
    let idDesignazione: String
    let heading: String
    let title: String
    let scheduleLabel: String
    let dateValue: String?
    let timeValue: String?
    let isToday: Bool?
    let competitionLabel: String
    let activityLabel: String
    let statusLabel: String
    let refundLabel: String?
    let distanceLabel: String?

    var id: String { idDesignazione }

    enum CodingKeys: String, CodingKey {
        case idDesignazione = "id_designazione"
        case heading
        case title
        case scheduleLabel = "schedule_label"
        case dateValue = "date_value"
        case timeValue = "time_value"
        case isToday = "is_today"
        case competitionLabel = "competition_label"
        case activityLabel = "activity_label"
        case statusLabel = "status_label"
        case refundLabel = "refund_label"
        case distanceLabel = "distance_label"
    }
}

struct HomeOperationalStatsDTO: Codable {
    let completedMatches: Int
    let upcomingMatches: Int
    let estimatedRefundsTotal: String
    let distanceTotal: String

    enum CodingKeys: String, CodingKey {
        case completedMatches = "completed_matches"
        case upcomingMatches = "upcoming_matches"
        case estimatedRefundsTotal = "estimated_refunds_total"
        case distanceTotal = "distance_total"
    }
}

struct HomePayloadDTO: Codable {
    let profile: ProfiloArbitro
    let isPartial: Bool
    let todayMatches: [GaraHomeDTO]?
    let nextMatch: GaraHomeDTO?
    let recentMatch: GaraHomeDTO?
    let operationalStats: HomeOperationalStatsDTO?
    let quickActions: [AzioneRapidaHomeDTO]
    let news: [NotiziaHomeDTO]

    enum CodingKeys: String, CodingKey {
        case profile
        case isPartial = "is_partial"
        case todayMatches = "today_matches"
        case nextMatch = "next_match"
        case recentMatch = "recent_match"
        case operationalStats = "operational_stats"
        case quickActions = "quick_actions"
        case news
    }
}

struct LoginResponseDTO: Codable {
    let accessToken: String
    let tokenType: String
    let profile: ProfiloArbitro
    let home: HomePayloadDTO

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case profile
        case home
    }
}

struct SessioneApp: Codable {
    let token: String
    var profile: ProfiloArbitro
    var home: HomePayloadDTO
}

extension SessioneApp {
    // Dati usati solo nelle preview SwiftUI.
    // Non vengono mostrati agli utenti reali dopo il login.
    static let preview = SessioneApp(
        token: "preview-token",
        profile: ProfiloArbitro(
            fullName: "ARBITRO DEMO",
            firstName: "Arbitro",
            lastName: "Demo",
            code: "00000000",
            section: "SEZIONE DEMO",
            role: "Ruolo Demo",
            initials: "AD",
            lastAccessLabel: "oggi 00:00"
        ),
        home: HomePayloadDTO(
            profile: ProfiloArbitro(
                fullName: "ARBITRO DEMO",
                firstName: "Arbitro",
                lastName: "Demo",
                code: "00000000",
                section: "SEZIONE DEMO",
                role: "Ruolo Demo",
                initials: "AD",
                lastAccessLabel: "oggi 00:00"
            ),
            isPartial: false,
            todayMatches: [
                GaraHomeDTO(
                    idDesignazione: "1001",
                    heading: "Gara del giorno",
                    title: "ERCOLANESE 1924 - POMIGLIANO",
                    scheduleLabel: "22/03/2026 · 15:00",
                    dateValue: "22/03/2026",
                    timeValue: "15:00",
                    isToday: true,
                    competitionLabel: "ECCELLENZA | Girone A | 12ª giornata",
                    activityLabel: "Arbitro Effettivo",
                    statusLabel: "Accettata",
                    refundLabel: "37 €",
                    distanceLabel: "18 km"
                )
            ],
            nextMatch: GaraHomeDTO(
                idDesignazione: "1001",
                heading: "Prossima gara",
                title: "ERCOLANESE 1924 - POMIGLIANO",
                scheduleLabel: "22/03/2026 · 15:00",
                dateValue: "22/03/2026",
                timeValue: "15:00",
                isToday: true,
                competitionLabel: "ECCELLENZA | Girone A | 12ª giornata",
                activityLabel: "Arbitro Effettivo",
                statusLabel: "Accettata",
                refundLabel: "37 €",
                distanceLabel: "18 km"
            ),
            recentMatch: GaraHomeDTO(
                idDesignazione: "1000",
                heading: "Ultima gara",
                title: "REAL FORIO - GLADIATOR",
                scheduleLabel: "16/03/2026 · 11:30",
                dateValue: "16/03/2026",
                timeValue: "11:30",
                isToday: false,
                competitionLabel: "ECCELLENZA | Girone A | 11ª giornata",
                activityLabel: "Arbitro Effettivo",
                statusLabel: "Omologata",
                refundLabel: "42 €",
                distanceLabel: "54 km"
            ),
            operationalStats: HomeOperationalStatsDTO(
                completedMatches: 18,
                upcomingMatches: 2,
                estimatedRefundsTotal: "684 €",
                distanceTotal: "742 km"
            ),
            quickActions: [
                AzioneRapidaHomeDTO(
                    id: "gestione_gare",
                    title: "Gestione Gare",
                    subtitle: "6 gare disponibili",
                    systemIcon: "soccerball.inverse",
                    gradient: ["#7CC0FF", "#6A84B0"]
                ),
                AzioneRapidaHomeDTO(
                    id: "anagrafica",
                    title: "Anagrafica",
                    subtitle: "SEZIONE DEMO",
                    systemIcon: "person.text.rectangle.fill",
                    gradient: ["#D9A7FF", "#8B7BB3"]
                ),
                AzioneRapidaHomeDTO(
                    id: "certificato_medico",
                    title: "Certificato Medico",
                    subtitle: "Storico e rinnovo",
                    systemIcon: "cross.case.fill",
                    gradient: ["#95F0BF", "#7A9A91"]
                ),
                AzioneRapidaHomeDTO(
                    id: "comunicazioni",
                    title: "Comunicazioni",
                    subtitle: "10 elementi recenti",
                    systemIcon: "bell.badge.fill",
                    gradient: ["#FFB45E", "#937C70"]
                ),
            ],
            news: [
                NotiziaHomeDTO(
                    id: "1",
                    accentColor: "#1C8CFF",
                    title: "Nuove direttive sui falli di mano: cosa cambia",
                    excerpt: "L'IFAB ha apportato modifiche significative alle regole sul fallo di mano. Scopri i dettagli e le nuove interpretazioni per la prossima stagione...",
                    date: "24 MAG 2024"
                ),
                NotiziaHomeDTO(
                    id: "2",
                    accentColor: "#FF8A1D",
                    title: "Aggiornamento applicazione v2.5.1",
                    excerpt: "Nuove funzionalita' per la gestione delle designazioni e miglioramenti delle prestazioni. Scarica subito l'aggiornamento per godere delle nuove caratteristiche.",
                    date: "20 MAG 2024"
                )
            ]
        )
    )
}
