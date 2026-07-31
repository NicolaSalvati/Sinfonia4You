import SwiftUI

// MARK: - Tabs principali della dashboard

enum TabDashboard: String, CaseIterable, Identifiable, Hashable {
    case home
    case gare
    case profilo
    case notizie
    case impostazioni

    var id: Self { self }

    var titolo: String {
        switch self {
        case .home:
            return "Home"
        case .gare:
            return "Gare"
        case .profilo:
            return "Profilo"
        case .notizie:
            return "Notizie"
        case .impostazioni:
            return "Impostazioni"
        }
    }

    // Simboli scelti per una resa pulita sulla tab bar nativa iOS.
    var iconaSistema: String {
        switch self {
        case .home:
            return "house.fill"
        case .gare:
            return "soccerball"
        case .profilo:
            return "person.crop.circle"
        case .notizie:
            return "bell.badge"
        case .impostazioni:
            return "gearshape"
        }
    }
}
