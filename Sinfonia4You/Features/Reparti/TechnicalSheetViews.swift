import SwiftUI

enum SchedaTecnicaTab: String, CaseIterable, Identifiable {
    case gare = "Gare"
    case rimborsi = "Rimborsi"
    case voti = "Voti"
    case anagrafe = "Anagrafe"

    var id: String { rawValue }

    var descrizione: String {
        switch self {
        case .gare:
            return "Storico gare"
        case .rimborsi:
            return "Rimborsi e report"
        case .voti:
            return "Media voto"
        case .anagrafe:
            return "Dati anagrafici"
        }
    }
}

private enum SchedaTecnicaFiltroGare: String, CaseIterable, Identifiable {
    case daVerificare
    case tutte
    case completate

    var id: String { rawValue }

    var titolo: String {
        switch self {
        case .daVerificare:
            return "Da verificare"
        case .tutte:
            return "Tutte"
        case .completate:
            return "Completate"
        }
    }
}

private enum SchedaTecnicaPalette {
    // Tengo qui la palette della feature per allinearla al linguaggio visivo
    // gia usato nelle altre schermate reparto ed evitare altri colori "fuori tema".
    static let accent = Color(hex: 0x4EA0FF)
    static let accentSoft = Color(hex: 0x9EC8FF)
    static let accentStrong = Color(hex: 0x195BBC)
    static let textSoft = Color(hex: 0xD7E8FF).opacity(0.88)
    static let panelFill = Color(hex: 0x20457D).opacity(0.42)
    static let panelStroke = Color(hex: 0x9EC8FF).opacity(0.20)
    static let panelGradient = LinearGradient(
        colors: [Color(hex: 0x143C78).opacity(0.92), Color(hex: 0x0E284E).opacity(0.96)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let actionGradient = LinearGradient(
        colors: [Color(hex: 0x3F9BFF), Color(hex: 0x195BBC)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct VistaSchedaTecnica: View {
    let token: String

    @StateObject private var viewModel = SchedaTecnicaViewModel()
    @State private var tabSelezionata: SchedaTecnicaTab = .gare
    private let apiClient = APIClient.shared

    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if viewModel.inCaricamentoOverview && viewModel.overview == nil {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else if !viewModel.erroreOverview.isEmpty && viewModel.overview == nil {
                        StatoVuotoView(
                            titolo: "Scheda Tecnica non disponibile",
                            messaggio: viewModel.erroreOverview
                        )
                    } else {
                        contenutoPrincipale
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Scheda Tecnica")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.caricaIniziale(token: token, tab: tabSelezionata)
        }
        .onChange(of: tabSelezionata) { _, nuovoValore in
            Task {
                await viewModel.caricaSezione(token: token, tab: nuovoValore)
            }
        }
    }

    private var contenutoPrincipale: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardTitoloView(
                titolo: "Scheda Tecnica",
                sottotitolo: contestoCorrente?.seasonLabel.isEmpty == false
                    ? contestoCorrente?.seasonLabel ?? ""
                    : "Riepilogo tecnico ordinato di gare, rimborsi, voti e anagrafe."
            )

            if let context = contestoCorrente {
                SchedaTecnicaContestoPortaleCard(
                    context: context,
                    stagioneSelezionataID: stagioneSelectionBinding
                )
            }

            if let overview = viewModel.overview {
                SchedaTecnicaDashboardView(overview: overview)
            }

            SchedaTecnicaTabBar(selection: $tabSelezionata)

            if !viewModel.erroreSezione.isEmpty {
                BloccoTestoView(titolo: "Aggiornamento", testo: viewModel.erroreSezione)
            }

            switch tabSelezionata {
            case .gare:
                contenutoGare
            case .rimborsi:
                contenutoRimborsi
            case .voti:
                contenutoVoti
            case .anagrafe:
                contenutoAnagrafe
            }
        }
    }

    private var contenutoGare: some View {
        Group {
            if viewModel.inCaricamentoSezione && viewModel.gare == nil {
                ProgressView().tint(.white).frame(maxWidth: .infinity)
            } else if let payload = viewModel.gare {
                let pendingMatches = max(payload.summary.matchesCount - payload.summary.completedMatches, 0)
                SchedaTecnicaSectionCard(
                    titolo: "Agenda gare",
                    sottotitolo: "Una vista semplice per capire subito cosa controllare e aprire la partita giusta.",
                    actionTitle: payload.summary.pdfAvailable ? "Scarica PDF gare" : nil,
                    actionProvider: {
                        await apiClient.urlSchedaTecnicaPDF(
                            token: token,
                            section: "matches",
                            seasonId: viewModel.stagioneSelezionataID
                        )
                    }
                ) {
                    SchedaTecnicaGareHeader(
                        totalMatches: payload.summary.matchesCount,
                        completedMatches: payload.summary.completedMatches,
                        pendingMatches: pendingMatches
                    )

                    if payload.items.isEmpty {
                        StatoVuotoView(
                            titolo: "Nessuna gara disponibile",
                            messaggio: "La scheda tecnica non ha restituito gare per la stagione selezionata."
                        )
                    } else {
                        SchedaTecnicaGareList(
                            items: payload.items,
                            seasonId: viewModel.stagioneSelezionataID,
                            token: token
                        )
                    }
                }
            }
        }
    }

    private var contenutoRimborsi: some View {
        Group {
            if viewModel.inCaricamentoSezione && viewModel.rimborsi == nil {
                ProgressView().tint(.white).frame(maxWidth: .infinity)
            } else if let payload = viewModel.rimborsi {
                SchedaTecnicaSectionCard(
                    titolo: "Rimborsi",
                    sottotitolo: "Quadro economico e chilometrico della stagione tecnica.",
                    actionTitle: payload.summary.statisticsPdfAvailable ? "Scarica PDF statistiche" : nil,
                    actionProvider: {
                        await apiClient.urlSchedaTecnicaStatistichePDF(
                            token: token,
                            seasonId: viewModel.stagioneSelezionataID
                        )
                    }
                ) {
                    SchedaTecnicaMetricGrid(
                        items: [
                            .init(label: "Totale rimborsi", value: payload.summary.totalRefunds),
                            .init(label: "Totale km", value: payload.summary.totalDistance),
                            .init(label: "Media rimborso", value: payload.summary.averageRefund),
                            .init(label: "Omologati", value: "\(payload.summary.approvedCount)")
                        ]
                    )

                    if !payload.note.isEmpty {
                        BloccoTestoView(titolo: "Nota portale", testo: payload.note)
                    }

                    if payload.items.isEmpty {
                        StatoVuotoView(
                            titolo: "Nessun rimborso disponibile",
                            messaggio: "La scheda tecnica non ha restituito rimborsi per la stagione selezionata."
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(payload.items) { item in
                                SchedaTecnicaRimborsoCard(item: item)
                            }
                        }
                    }
                }
            }
        }
    }

    private var contenutoVoti: some View {
        Group {
            if viewModel.inCaricamentoSezione && viewModel.voti == nil {
                ProgressView().tint(.white).frame(maxWidth: .infinity)
            } else if let payload = viewModel.voti {
                SchedaTecnicaSectionCard(
                    titolo: "Valutazioni",
                    sottotitolo: "Medie, nominativi, info gara e allegati OA/OT della stagione selezionata.",
                    actionTitle: payload.summary.pdfAvailable ? "Scarica PDF voti" : nil,
                    actionProvider: {
                        await apiClient.urlSchedaTecnicaPDF(
                            token: token,
                            section: "votes",
                            seasonId: viewModel.stagioneSelezionataID
                        )
                    }
                ) {
                    SchedaTecnicaMetricGrid(
                        items: [
                            .init(label: "Media voti", value: payload.summary.average),
                            .init(label: "Media OA", value: payload.summary.oaAverage),
                            .init(label: "Media OT", value: payload.summary.otAverage),
                            .init(label: "Gare valutate", value: "\(payload.summary.ratedMatchesCount)"),
                        ]
                    )

                    SchedaTecnicaMetricGrid(
                        items: [
                            .init(label: "Sezione", value: payload.summary.sectionLabel.isEmpty ? payload.context.section : payload.summary.sectionLabel),
                            .init(label: "Voti OA", value: "\(payload.summary.oaCount)"),
                            .init(label: "Voti OT", value: "\(payload.summary.otCount)"),
                            .init(label: "Stato", value: payload.summary.statusLabel.isEmpty ? "Disponibile" : payload.summary.statusLabel)
                        ]
                    )

                    SchedaTecnicaMetricGrid(
                        items: [
                            .init(label: "File OA", value: "\(payload.summary.oaFilesCount)"),
                            .init(label: "File OT", value: "\(payload.summary.otFilesCount)"),
                            .init(label: "Allegati OA", value: payload.summary.oaFilesCount > 0 ? "Presenti" : "Assenti"),
                            .init(label: "Allegati OT", value: payload.summary.otFilesCount > 0 ? "Presenti" : "Assenti")
                        ]
                    )

                    BloccoTestoView(
                        titolo: "Lettura voti",
                        testo: payload.summary.isAvailable
                            ? "La media totale e calcolata sui voti OA e OT presenti in scheda tecnica. Le relazioni caricate da OA o OT sono apribili dalla singola valutazione."
                            : "Per la stagione selezionata il portale non espone voti OA o OT sufficienti per calcolare una media attendibile."
                    )

                    if payload.items.isEmpty {
                        StatoVuotoView(
                            titolo: "Nessuna valutazione disponibile",
                            messaggio: "La scheda tecnica non ha restituito voti per la stagione selezionata."
                        )
                    } else {
                        SchedaTecnicaVotiList(
                            token: token,
                            seasonId: viewModel.stagioneSelezionataID,
                            items: payload.items
                        )
                    }
                }
            }
        }
    }

    private var contenutoAnagrafe: some View {
        Group {
            if viewModel.inCaricamentoSezione && viewModel.anagrafe == nil {
                ProgressView().tint(.white).frame(maxWidth: .infinity)
            } else if let payload = viewModel.anagrafe {
                SchedaTecnicaSectionCard(
                    titolo: "Anagrafe",
                    sottotitolo: "Dati personali e recapiti riportati dal portale.",
                    actionTitle: payload.pdfAvailable ? "Scarica PDF anagrafe" : nil,
                    actionProvider: {
                        await apiClient.urlSchedaTecnicaPDF(
                            token: token,
                            section: "anagraphics",
                            seasonId: viewModel.stagioneSelezionataID
                        )
                    }
                ) {
                    if payload.text.isEmpty {
                        StatoVuotoView(
                            titolo: "Anagrafe non disponibile",
                            messaggio: "Il portale non ha restituito dati anagrafici per questa scheda tecnica."
                        )
                    } else {
                        SchedaTecnicaAnagrafeView(text: payload.text)
                    }
                }
            }
        }
    }

    private var contestoCorrente: TechnicalSheetContextDTO? {
        viewModel.context
            ?? viewModel.overview?.context
            ?? viewModel.gare?.context
            ?? viewModel.voti?.context
            ?? viewModel.rimborsi?.context
            ?? viewModel.anagrafe?.context
    }

    private var stagioneSelectionBinding: Binding<String> {
        Binding(
            get: { viewModel.stagioneSelezionataID },
            set: { newValue in
                Task {
                    // Il cambio stagione deve ricaricare la stessa tab corrente:
                    // in questo modo l'utente resta nel contesto in cui sta lavorando.
                    await viewModel.cambiaStagione(
                        token: token,
                        tab: tabSelezionata,
                        seasonId: newValue
                    )
                }
            }
        )
    }
}

struct VistaSchedaTecnicaDettaglioGara: View {
    let token: String
    let matchId: String
    let titolo: String
    let seasonId: String

    @StateObject private var viewModel = SchedaTecnicaDettaglioGaraViewModel()

    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.inCaricamento && viewModel.dettaglio == nil {
                        ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 40)
                    } else if !viewModel.errore.isEmpty && viewModel.dettaglio == nil {
                        StatoVuotoView(titolo: "Dettaglio non disponibile", messaggio: viewModel.errore)
                    } else if let dettaglio = viewModel.dettaglio {
                        CardTitoloView(titolo: dettaglio.match.matchLabel, sottotitolo: dettaglio.context.seasonLabel)

                        SchedaTecnicaSectionCard(
                            titolo: "Riepilogo gara",
                            sottotitolo: "Informazioni essenziali della gara selezionata.",
                            actionTitle: nil
                        ) {
                            SchedaTecnicaGaraCard(item: dettaglio.match, mostraCallToAction: false)
                        }

                        if let reimbursement = dettaglio.reimbursement {
                            SchedaTecnicaSectionCard(
                                titolo: "Rimborso associato",
                                sottotitolo: "Voce economica collegata a questa gara.",
                                actionTitle: nil
                            ) {
                                SchedaTecnicaRimborsoCard(item: reimbursement)
                            }
                        }

                        if !dettaglio.detailFields.isEmpty {
                            SchedaTecnicaSectionCard(
                                titolo: "Dettagli gara",
                                sottotitolo: "Campi tecnici letti dal portale.",
                                actionTitle: nil
                            ) {
                                VStack(spacing: 10) {
                                    ForEach(dettaglio.detailFields) { field in
                                        SchedaTecnicaCampoView(label: field.label, value: field.value)
                                    }
                                }
                            }
                        }

                        if !dettaglio.relatedAssignments.isEmpty {
                            SchedaTecnicaSectionCard(
                                titolo: "Designazioni correlate",
                                sottotitolo: "Collaboratori e riferimenti della gara.",
                                actionTitle: nil
                            ) {
                                VStack(spacing: 10) {
                                    ForEach(dettaglio.relatedAssignments) { assignment in
                                        SchedaTecnicaCollaboratoreCard(item: assignment)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle(titolo)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.carica(token: token, matchId: matchId, seasonId: seasonId)
        }
    }
}

struct VistaSchedaTecnicaRelazionePlaceholder: View {
    let matchLabel: String
    let evaluatorLabel: String
    let relationId: String

    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    CardTitoloView(
                        titolo: evaluatorLabel,
                        sottotitolo: matchLabel
                    )

                    SchedaTecnicaSectionCard(
                        titolo: "Anteprima relazione",
                        sottotitolo: "Questa schermata verra completata nel prossimo passaggio.",
                        actionTitle: nil
                    ) {
                        VStack(spacing: 10) {
                            SchedaTecnicaCampoView(label: "Tipo", value: evaluatorLabel)
                            SchedaTecnicaCampoView(label: "ID relazione", value: relationId)
                            BloccoTestoView(
                                titolo: "Stato implementazione",
                                testo: "Il menu Voti espone gia la presenza della relazione OA o OT e ti porta qui. Nel prossimo step collegheremo questa schermata al contenuto caricato sul portale."
                            )
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle(evaluatorLabel)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct SchedaTecnicaVotiList: View {
    let token: String
    let seasonId: String
    let items: [TechnicalSheetVoteItemDTO]

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(items) { item in
                SchedaTecnicaVotoCard(
                    token: token,
                    seasonId: seasonId,
                    item: item
                )
            }
        }
    }
}

private struct SchedaTecnicaVotoCard: View {
    let token: String
    let seasonId: String
    let item: TechnicalSheetVoteItemDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleLine)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(competitionLine)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                SchedaTecnicaInfoTile(label: "Data", value: item.date)
                SchedaTecnicaInfoTile(label: "Ora", value: item.time)
                SchedaTecnicaInfoTile(label: "Ruolo", value: item.roleLabel)
                SchedaTecnicaInfoTile(label: "Giornata", value: item.giornataLabel)
                SchedaTecnicaInfoTile(label: "Voto OA", value: item.oaVote)
                SchedaTecnicaInfoTile(label: "Voto OT", value: item.otVote)
                SchedaTecnicaInfoTile(label: "File OA", value: item.oaHasAttachment ? "Disponibile" : "Assente")
                SchedaTecnicaInfoTile(label: "File OT", value: item.otHasAttachment ? "Disponibile" : "Assente")
            }

            if !item.nominatives.isEmpty {
                SchedaTecnicaCampoView(label: nominativiTitle, value: item.nominatives.joined(separator: "\n"))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                NavigationLink {
                    VistaSchedaTecnicaDettaglioGara(
                        token: token,
                        matchId: item.matchId,
                        titolo: item.matchLabel,
                        seasonId: seasonId
                    )
                } label: {
                    SchedaTecnicaActionTile(
                        title: "Info gara",
                        systemImage: "info.circle.fill"
                    )
                }
                .buttonStyle(.plain)

                if item.oaHasAttachment {
                    NavigationLink {
                        VistaSchedaTecnicaRelazionePlaceholder(
                            matchLabel: item.matchLabel,
                            evaluatorLabel: "Relazione OA",
                            relationId: item.oaRelationId
                        )
                    } label: {
                        SchedaTecnicaActionTile(
                            title: "Relazione OA",
                            systemImage: "paperclip.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }

                if item.otHasAttachment {
                    NavigationLink {
                        VistaSchedaTecnicaRelazionePlaceholder(
                            matchLabel: item.matchLabel,
                            evaluatorLabel: "Relazione OT",
                            relationId: item.otRelationId
                        )
                    } label: {
                        SchedaTecnicaActionTile(
                            title: "Relazione OT",
                            systemImage: "paperclip.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SchedaTecnicaPalette.panelGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 5)
    }

    private var competitionLine: String {
        [item.category, item.group.isEmpty ? nil : "Girone \(item.group)"]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var titleLine: String {
        if !item.homeTeam.isEmpty && !item.awayTeam.isEmpty {
            return "\(item.homeTeam) - \(item.awayTeam)"
        }
        if !item.matchLabel.isEmpty {
            return item.matchLabel
        }
        return "Valutazione"
    }

    private var nominativiTitle: String {
        if item.oaVoteValue > 0 && item.otVoteValue <= 0 {
            return item.nominatives.count == 1 ? "Nominativo OA" : "Nominativi OA"
        }
        if item.otVoteValue > 0 && item.oaVoteValue <= 0 {
            return item.nominatives.count == 1 ? "Nominativo OT" : "Nominativi OT"
        }
        return item.nominatives.count == 1 ? "Nominativo" : "Nominativi"
    }
}

private struct SchedaTecnicaActionTile: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(SchedaTecnicaPalette.accentSoft)

            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.54))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SchedaTecnicaPalette.panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SchedaTecnicaPalette.panelStroke, lineWidth: 1)
        )
    }
}

private struct SchedaTecnicaContestoPortaleCard: View {
    let context: TechnicalSheetContextDTO
    @Binding var stagioneSelezionataID: String

    var body: some View {
        SchedaTecnicaSectionCard(
            titolo: "Filtri scheda",
            sottotitolo: "Stagione attiva e riferimenti essenziali della tua scheda tecnica.",
            actionTitle: nil
        ) {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SchedaTecnicaContestoCampo(label: "Associato", value: context.associato)
                    SchedaTecnicaContestoCampo(label: "Sezione", value: context.section)
                    SchedaTecnicaContestoPickerCampo(
                        label: "Stagione",
                        selection: $stagioneSelezionataID,
                        options: context.seasonOptions
                    )
                    SchedaTecnicaContestoCampo(label: "Scheda", value: "Personale")
                }

                SchedaTecnicaContestoCampo(
                    label: "Ind. Partenza",
                    value: context.departureAddress
                )
            }
        }
    }
}

private struct SchedaTecnicaContestoCampo: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.56))
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SchedaTecnicaPalette.panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SchedaTecnicaPalette.panelStroke, lineWidth: 1)
        )
    }
}

private struct SchedaTecnicaContestoPickerCampo: View {
    let label: String
    @Binding var selection: String
    let options: [TechnicalSheetSeasonOptionDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.56))

            Picker(label, selection: $selection) {
                ForEach(options) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SchedaTecnicaPalette.panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SchedaTecnicaPalette.panelStroke, lineWidth: 1)
        )
    }
}

private struct SchedaTecnicaGareList: View {
    let items: [TechnicalSheetMatchDTO]
    let seasonId: String
    let token: String
    @State private var filtroSelezionato: SchedaTecnicaFiltroGare

    init(items: [TechnicalSheetMatchDTO], seasonId: String, token: String) {
        self.items = items
        self.seasonId = seasonId
        self.token = token
        // Se ci sono gare senza risultato le mostriamo subito: e la vista
        // piu utile per l'arbitro quando apre questa schermata da telefono.
        _filtroSelezionato = State(
            initialValue: items.contains(where: { $0.result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                ? .daVerificare
                : .tutte
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SchedaTecnicaGareFiltroSegment(
                selection: $filtroSelezionato,
                counts: [
                    .daVerificare: pendingItems.count,
                    .tutte: items.count,
                    .completate: completedItems.count
                ]
            )

            if itemsVisibili.isEmpty {
                StatoVuotoView(
                    titolo: "Nessuna gara nel filtro selezionato",
                    messaggio: "Prova a cambiare filtro per vedere l'intero storico della stagione."
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(itemsVisibili) { item in
                        NavigationLink {
                            VistaSchedaTecnicaDettaglioGara(
                                token: token,
                                matchId: item.matchId,
                                titolo: item.matchLabel,
                                seasonId: seasonId
                            )
                        } label: {
                            SchedaTecnicaGaraCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var pendingItems: [TechnicalSheetMatchDTO] {
        items.filter { $0.result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var completedItems: [TechnicalSheetMatchDTO] {
        items.filter { !$0.result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var itemsVisibili: [TechnicalSheetMatchDTO] {
        switch filtroSelezionato {
        case .daVerificare:
            return pendingItems
        case .tutte:
            return items
        case .completate:
            return completedItems
        }
    }
}

private struct SchedaTecnicaGareHeader: View {
    let totalMatches: Int
    let completedMatches: Int
    let pendingMatches: Int

    var body: some View {
        // Questa panoramica usa la stessa grammatica visiva dei rimborsi:
        // quattro metriche immediate, senza hero card o colori fuori tema.
        SchedaTecnicaMetricGrid(
            items: [
                .init(label: "Totale gare", value: "\(totalMatches)"),
                .init(label: "Da verificare", value: "\(pendingMatches)"),
                .init(label: "Con risultato", value: "\(completedMatches)"),
                .init(label: "Completamento", value: progressLabel)
            ]
        )
    }

    private var progressLabel: String {
        guard totalMatches > 0 else { return "0%" }
        let progress = Int((Double(completedMatches) / Double(totalMatches)) * 100)
        return "\(progress)% completato"
    }
}

private struct SchedaTecnicaGareFiltroSegment: View {
    @Binding var selection: SchedaTecnicaFiltroGare
    let counts: [SchedaTecnicaFiltroGare: Int]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(SchedaTecnicaFiltroGare.allCases) { filtro in
                Button {
                    selection = filtro
                } label: {
                    VStack(spacing: 4) {
                        Text(filtro.titolo)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                        Text("\(counts[filtro, default: 0])")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(selection == filtro ? .white : SchedaTecnicaPalette.textSoft)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(SchedaTecnicaPalette.panelFill)
                            if selection == filtro {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(SchedaTecnicaPalette.actionGradient)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selection == filtro ? Color.white.opacity(0.16) : SchedaTecnicaPalette.panelStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SchedaTecnicaDashboardView: View {
    let overview: TechnicalSheetOverviewDTO

    var body: some View {
        SchedaTecnicaSectionCard(
            titolo: "Riepilogo stagione",
            sottotitolo: "Panoramica essenziale della stagione tecnica.",
            actionTitle: nil
        ) {
            VStack(alignment: .leading, spacing: 16) {
                SchedaTecnicaMetricGrid(
                    items: [
                        .init(label: "Gare svolte", value: "\(overview.summary.completedMatches)"),
                        .init(label: "Rimborsi registrati", value: "\(overview.summary.reimbursementsCount)"),
                        .init(label: "Totale rimborsi", value: overview.summary.totalRefunds),
                        .init(label: "Totale km", value: overview.summary.totalDistance)
                    ]
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    SchedaTecnicaInfoTile(label: "Associato", value: overview.context.associato)
                    SchedaTecnicaInfoTile(label: "Stagione", value: overview.context.seasonLabel)
                    SchedaTecnicaInfoTile(label: "Media rimborso", value: overview.summary.averageRefund)
                    SchedaTecnicaInfoTile(label: "Media voto", value: overview.votes.average)
                    SchedaTecnicaInfoTile(label: "Sezione", value: overview.context.section)
                    SchedaTecnicaInfoTile(label: "Organico", value: overview.context.structureLabel)
                }

                if !overview.context.departureAddress.isEmpty {
                    BloccoTestoView(
                        titolo: "Indirizzo di partenza",
                        testo: overview.context.departureAddress
                    )
                }
            }
        }
    }
}

private struct SchedaTecnicaBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(SchedaTecnicaPalette.actionGradient)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }
}

private struct SchedaTecnicaTabBar: View {
    @Binding var selection: SchedaTecnicaTab

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Menu scheda")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.56))

            HStack(spacing: 8) {
                ForEach(SchedaTecnicaTab.allCases) { tab in
                    Button {
                        selection = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(selection == tab ? .white : SchedaTecnicaPalette.textSoft)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(SchedaTecnicaPalette.panelFill)
                                    if selection == tab {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(SchedaTecnicaPalette.actionGradient)
                                    }
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(selection == tab ? Color.white.opacity(0.16) : SchedaTecnicaPalette.panelStroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.descrizione)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct SchedaTecnicaSectionCard<Content: View>: View {
    let titolo: String
    let sottotitolo: String
    let actionTitle: String?
    // La card non riceve piu' una URL gia' pronta con il token dentro: riceve
    // una funzione che la costruisce al tocco con un ticket monouso.
    let actionProvider: () async -> URL?
    let content: Content

    init(
        titolo: String,
        sottotitolo: String,
        actionTitle: String?,
        actionProvider: @escaping () async -> URL? = { nil },
        @ViewBuilder content: () -> Content
    ) {
        self.titolo = titolo
        self.sottotitolo = sottotitolo
        self.actionTitle = actionTitle
        self.actionProvider = actionProvider
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titolo)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if !sottotitolo.isEmpty {
                    Text(sottotitolo)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let actionTitle {
                TicketedDownloadLink {
                    await actionProvider()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text(actionTitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(SchedaTecnicaPalette.actionGradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                }
                .accessibilityHint("Scarica il documento PDF della sezione selezionata")
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(SchedaTecnicaPalette.panelGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 10, y: 6)
    }
}

private struct SchedaTecnicaMetricItem: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

private struct SchedaTecnicaMetricGrid: View {
    let items: [SchedaTecnicaMetricItem]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.label.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.54))
                    Text(item.value.isEmpty ? "-" : item.value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SchedaTecnicaPalette.panelFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SchedaTecnicaPalette.panelStroke, lineWidth: 1)
                )
            }
        }
    }
}

private struct SchedaTecnicaGaraCard: View {
    let item: TechnicalSheetMatchDTO
    var mostraCallToAction = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleLine)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(competitionLine)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                SchedaTecnicaInfoTile(label: "Data", value: item.date)
                SchedaTecnicaInfoTile(label: "Ora", value: item.time)
                SchedaTecnicaInfoTile(label: "Ruolo", value: item.roleLabel)
                SchedaTecnicaInfoTile(label: "Giornata", value: item.giornataLabel)
                SchedaTecnicaInfoTile(label: "Risultato", value: resultValue)
                SchedaTecnicaInfoTile(label: "Stato", value: statusValue)
                SchedaTecnicaInfoTile(label: "Comitato", value: item.committee)
                SchedaTecnicaInfoTile(label: "Girone", value: item.group)
            }

            if mostraCallToAction {
                SchedaTecnicaActionTile(
                    title: "Apri dettaglio gara",
                    systemImage: "chevron.right.circle.fill"
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SchedaTecnicaPalette.panelGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 5)
    }

    private var competitionLine: String {
        let parti = [
            item.category.isEmpty ? nil : item.category,
            item.group.isEmpty ? nil : "Girone \(item.group)",
            item.committee.isEmpty ? nil : item.committee
        ]
        .compactMap { $0 }

        return parti.isEmpty ? "Dettagli competizione non disponibili" : parti.joined(separator: " · ")
    }

    private var titleLine: String {
        if !item.homeTeam.isEmpty && !item.awayTeam.isEmpty {
            return "\(item.homeTeam) - \(item.awayTeam)"
        }
        if !item.matchLabel.isEmpty {
            return item.matchLabel
        }
        return "Gara"
    }

    private var resultValue: String {
        let trimmed = item.result.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return "Da verificare"
    }

    private var statusValue: String {
        let trimmed = item.status.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return item.result.isEmpty ? "Da verificare" : "Completata"
    }
}

private struct SchedaTecnicaRimborsoCard: View {
    let item: TechnicalSheetReimbursementDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.matchLabel)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(competitionLine)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                SchedaTecnicaInfoTile(label: "Data", value: item.date)
                SchedaTecnicaInfoTile(label: "Ora", value: item.time)
                SchedaTecnicaInfoTile(label: "Ruolo", value: item.roleLabel)
                SchedaTecnicaInfoTile(label: "Giornata", value: item.giornataLabel)
                SchedaTecnicaInfoTile(label: "Rimborso", value: item.refund)
                SchedaTecnicaInfoTile(label: "Chilometri", value: item.distance)
                SchedaTecnicaInfoTile(label: "Omologazione", value: item.approval)
                SchedaTecnicaInfoTile(label: "Stato", value: item.status)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SchedaTecnicaPalette.panelGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 5)
    }

    private var competitionLine: String {
        [item.category, item.group.isEmpty ? nil : "Girone \(item.group)"]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

private struct SchedaTecnicaInfoTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.52))
            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SchedaTecnicaPalette.panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(SchedaTecnicaPalette.panelStroke, lineWidth: 1)
        )
    }
}

private struct SchedaTecnicaCampoView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.56))

            Text(value.isEmpty ? "-" : value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SchedaTecnicaPalette.panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SchedaTecnicaPalette.panelStroke, lineWidth: 1)
        )
    }
}

private struct SchedaTecnicaCollaboratoreCard: View {
    let item: TechnicalSheetRelatedAssignmentDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.name)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text(item.role.isEmpty ? "Collaboratore" : item.role)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.72))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                SchedaTecnicaInfoTile(label: "Sezione", value: item.section)
                SchedaTecnicaInfoTile(label: "Telefono", value: item.phone)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SchedaTecnicaPalette.panelGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 5)
    }
}

private struct SchedaTecnicaAnagrafeView: View {
    let text: String

    private var righe: [SchedaTecnicaAnagrafeRiga] {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.map { line in
            guard let separator = line.firstIndex(of: ":") else {
                return SchedaTecnicaAnagrafeRiga(label: "", value: line, isParagraph: true)
            }
            let label = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if label.isEmpty || value.isEmpty || label.count > 36 {
                return SchedaTecnicaAnagrafeRiga(label: "", value: line, isParagraph: true)
            }
            return SchedaTecnicaAnagrafeRiga(label: label, value: value, isParagraph: false)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(righe) { row in
                if row.isParagraph {
                    BloccoTestoView(titolo: "Informazioni", testo: row.value)
                } else {
                    SchedaTecnicaCampoView(label: row.label, value: row.value)
                }
            }
        }
    }
}

private struct SchedaTecnicaAnagrafeRiga: Identifiable {
    let label: String
    let value: String
    let isParagraph: Bool
    var id: String { "\(label)|\(value)|\(isParagraph)" }
}
