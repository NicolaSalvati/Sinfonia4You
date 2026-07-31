import Combine
import Foundation

@MainActor
final class SchedaTecnicaViewModel: ObservableObject {
    @Published var context: TechnicalSheetContextDTO?
    @Published var overview: TechnicalSheetOverviewDTO?
    @Published var gare: TechnicalSheetMatchesDTO?
    @Published var voti: TechnicalSheetVotesScreenDTO?
    @Published var rimborsi: TechnicalSheetReimbursementsDTO?
    @Published var anagrafe: TechnicalSheetAnagraphicsDTO?
    @Published var stagioneSelezionataID = ""
    @Published var inCaricamentoOverview = false
    @Published var inCaricamentoSezione = false
    @Published var erroreOverview = ""
    @Published var erroreSezione = ""

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var stagioniDisponibili: [TechnicalSheetSeasonOptionDTO] {
        context?.seasonOptions ?? overview?.context.seasonOptions ?? []
    }

    func caricaIniziale(token: String, tab: SchedaTecnicaTab, force: Bool = false) async {
        // Carico prima il contesto: la stagione selezionata guida tutte le
        // chiamate successive della scheda tecnica.
        await caricaOverview(token: token, force: force)
        await caricaSezione(token: token, tab: tab, force: force)
    }

    func caricaOverview(token: String, force: Bool = false) async {
        if overview != nil && !force { return }
        inCaricamentoOverview = true
        erroreOverview = ""
        defer { inCaricamentoOverview = false }

        do {
            let payload = try await apiClient.schedaTecnicaOverview(
                token: token,
                seasonId: stagioneRichiestaID
            )
            overview = payload
            aggiornaContesto(payload.context)
        } catch {
            erroreOverview = error.localizedDescription
        }
    }

    func caricaSezione(token: String, tab: SchedaTecnicaTab, force: Bool = false) async {
        erroreSezione = ""
        if !force {
            switch tab {
            case .gare where gare != nil:
                return
            case .voti where voti != nil:
                return
            case .rimborsi where rimborsi != nil:
                return
            case .anagrafe where anagrafe != nil:
                return
            default:
                break
            }
        }

        inCaricamentoSezione = true
        defer { inCaricamentoSezione = false }

        do {
            switch tab {
            case .gare:
                let payload = try await apiClient.schedaTecnicaGare(
                    token: token,
                    seasonId: stagioneRichiestaID
                )
                gare = payload
                aggiornaContesto(payload.context)
            case .voti:
                let payload = try await apiClient.schedaTecnicaVoti(
                    token: token,
                    seasonId: stagioneRichiestaID
                )
                voti = payload
                aggiornaContesto(payload.context)
            case .rimborsi:
                let payload = try await apiClient.schedaTecnicaRimborsi(
                    token: token,
                    seasonId: stagioneRichiestaID
                )
                rimborsi = payload
                aggiornaContesto(payload.context)
            case .anagrafe:
                let payload = try await apiClient.schedaTecnicaAnagrafe(
                    token: token,
                    seasonId: stagioneRichiestaID
                )
                anagrafe = payload
                aggiornaContesto(payload.context)
            }
        } catch {
            erroreSezione = error.localizedDescription
        }
    }

    func cambiaStagione(token: String, tab: SchedaTecnicaTab, seasonId: String) async {
        let cleanSeasonId = seasonId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSeasonId.isEmpty, cleanSeasonId != stagioneSelezionataID else { return }

        // La stagione influenza overview, gare, rimborsi, anagrafe e dettaglio gara.
        // Invalido quindi la cache locale della feature e ricarico la scheda da zero.
        stagioneSelezionataID = cleanSeasonId
        overview = nil
        gare = nil
        voti = nil
        rimborsi = nil
        anagrafe = nil
        erroreOverview = ""
        erroreSezione = ""
        await caricaIniziale(token: token, tab: tab, force: true)
    }

    private var stagioneRichiestaID: String {
        let cleanSeasonId = stagioneSelezionataID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanSeasonId.isEmpty {
            return cleanSeasonId
        }
        return context?.seasonId ?? overview?.context.seasonId ?? ""
    }

    private func aggiornaContesto(_ nuovoContesto: TechnicalSheetContextDTO) {
        context = nuovoContesto

        let stagioneCorrente = stagioneSelezionataID.trimmingCharacters(in: .whitespacesAndNewlines)
        if stagioneCorrente.isEmpty {
            stagioneSelezionataID = nuovoContesto.seasonId
            return
        }

        let stagioneEsiste = nuovoContesto.seasonOptions.contains { $0.id == stagioneCorrente }
        if !stagioneEsiste {
            stagioneSelezionataID = nuovoContesto.seasonId
        }
    }
}

@MainActor
final class SchedaTecnicaDettaglioGaraViewModel: ObservableObject {
    @Published var dettaglio: TechnicalSheetMatchDetailDTO?
    @Published var inCaricamento = false
    @Published var errore = ""

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func carica(token: String, matchId: String, seasonId: String = "") async {
        inCaricamento = true
        errore = ""
        defer { inCaricamento = false }

        do {
            dettaglio = try await apiClient.schedaTecnicaDettaglioGara(
                token: token,
                matchId: matchId,
                seasonId: seasonId
            )
        } catch {
            errore = error.localizedDescription
        }
    }
}
