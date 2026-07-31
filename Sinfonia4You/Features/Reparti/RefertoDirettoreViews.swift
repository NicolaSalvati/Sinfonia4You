//
//  RefertoDirettoreViews.swift
//  Sinfonia4You
//
//  Viste dedicate al flusso referto del direttore di gara.
//

import SwiftUI

struct RefertoDirettoreSvolgimentoView: View {
    private enum TeamTarget: String, Identifiable {
        case home
        case away

        var id: String { rawValue }
        var isHome: Bool { self == .home }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var addPersonTarget: TeamTarget?
    @State private var removePersonTarget: TeamTarget?
    @State private var manualPersonDraft = RefertoManualPersonDraftState.empty
    @State private var selectedPersonToRemove = ""

    let dettaglio: DettaglioRefertoDTO
    @ObservedObject var viewModel: DettaglioRefertoViewModel
    let token: String
    let designazioneId: String

    private var directorTabs: [String] {
        dettaglio.flowTabs.isEmpty ? ["Svolgimento", "Sicurezza"] : dettaglio.flowTabs
    }

    private var supportedTabs: [String] {
        directorTabs.filter {
            let lower = $0.lowercased()
            return lower.contains("svolg") || lower.contains("sicurezza") || lower.contains("liste") || lower.contains("durata")
        }
    }

    private var currentTab: String {
        let clean = viewModel.directorCurrentTab.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { return clean }
        if !dettaglio.currentTab.isEmpty { return dettaglio.currentTab }
        return directorTabs.first ?? "Svolgimento"
    }

    private var isSicurezzaTab: Bool {
        currentTab.lowercased().contains("sicurezza")
    }

    private var isListeTab: Bool {
        currentTab.lowercased().contains("liste")
    }

    private var isDurataTab: Bool {
        currentTab.lowercased().contains("durata")
    }

    private var isFirstSupportedTab: Bool {
        supportedTabs.first == currentTab || (!isSicurezzaTab && !isListeTab && !isDurataTab && supportedTabs.first == nil)
    }

    private var isLastSupportedTab: Bool {
        supportedTabs.last == currentTab
    }

    private var currentSupportedIndex: Int? {
        supportedTabs.firstIndex(of: currentTab)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !directorTabs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(directorTabs, id: \.self) { tab in
                            let enabled = supportedTabs.contains(tab)
                            Button {
                                guard enabled else { return }
                                viewModel.directorCurrentTab = tab
                                viewModel.errore = ""
                                viewModel.messaggioOperazione = ""
                            } label: {
                                Text(tab)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(tab == currentTab ? .white : Color.white.opacity(enabled ? 0.62 : 0.34))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(
                                                tab == currentTab
                                                    ? Color(hex: 0xF4A62A).opacity(0.95)
                                                    : Color.white.opacity(enabled ? 0.06 : 0.03)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(!enabled)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(
                                        tab == currentTab
                                            ? Color(hex: 0xFFD37A).opacity(0.95)
                                            : Color.white.opacity(enabled ? 0.12 : 0.05),
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                }
            }

            if isListeTab {
                directorListeContent
            } else if isDurataTab {
                directorDurataContent
            } else if isSicurezzaTab {
                directorSicurezzaContent
            } else {
                directorSvolgimentoContent
            }

            if !viewModel.errore.isEmpty {
                BloccoTestoView(titolo: "Errore", testo: viewModel.errore)
            }

            if !viewModel.messaggioOperazione.isEmpty {
                BloccoTestoView(titolo: "Esito", testo: viewModel.messaggioOperazione)
            }

            directorFooter
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .onAppear {
            if viewModel.directorCurrentTab.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.directorCurrentTab = dettaglio.currentTab.isEmpty ? (supportedTabs.first ?? "Svolgimento") : dettaglio.currentTab
            }
        }
        .sheet(item: $addPersonTarget) { target in
            RefertoDirectorAddPersonSheetView(
                teamName: teamState(for: target).teamName,
                draft: $manualPersonDraft,
                isLoading: viewModel.inSalvataggio,
                onCancel: {
                    addPersonTarget = nil
                    manualPersonDraft = .empty
                },
                onSubmit: {
                    Task {
                        await viewModel.aggiungiPersonaManuale(
                            token: token,
                            designazioneId: designazioneId,
                            isHome: target.isHome,
                            draft: manualPersonDraft
                        )
                        if viewModel.errore.isEmpty {
                            addPersonTarget = nil
                            manualPersonDraft = .empty
                        }
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $removePersonTarget) { target in
            RefertoDirectorRemovePersonSheetView(
                teamName: teamState(for: target).teamName,
                people: teamState(for: target).availablePeople,
                selectedPersonId: $selectedPersonToRemove,
                isLoading: viewModel.inSalvataggio,
                onCancel: {
                    removePersonTarget = nil
                    selectedPersonToRemove = ""
                },
                onConfirm: {
                    Task {
                        await viewModel.rimuoviPersonaManuale(
                            token: token,
                            designazioneId: designazioneId,
                            isHome: target.isHome,
                            personId: selectedPersonToRemove
                        )
                        if viewModel.errore.isEmpty {
                            removePersonTarget = nil
                            selectedPersonToRemove = ""
                        }
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var directorSvolgimentoContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(dettaglio.svolgimentoTitle.isEmpty ? "Svolgimento della Gara" : dettaglio.svolgimentoTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if !dettaglio.svolgimentoNotice.isEmpty {
                Text(dettaglio.svolgimentoNotice)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFFD65E))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }

            LazyVStack(spacing: 12) {
                ForEach(dettaglio.svolgimentoOptions) { option in
                    RefertoSvolgimentoOptionView(
                        option: option,
                        isSelected: viewModel.svolgimentoSelezionato == option.value
                    ) {
                        viewModel.svolgimentoSelezionato = option.value
                        viewModel.errore = ""
                        viewModel.messaggioOperazione = ""
                    }
                }
            }

            directorNotesBlock(
                title: dettaglio.noteTitle.isEmpty ? "Note sullo Svolgimento della Gara" : dettaglio.noteTitle,
                text: Binding(
                    get: { viewModel.noteSvolgimento },
                    set: {
                        viewModel.noteSvolgimento = $0
                        viewModel.errore = ""
                        viewModel.messaggioOperazione = ""
                    }
                ),
                placeholder: dettaglio.notePlaceholder,
                remaining: dettaglio.noteRemaining
            )
        }
    }

    private var directorSicurezzaContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            directorChoiceSection(
                title: dettaglio.ordineTitle.isEmpty ? "Misure d'Ordine" : dettaglio.ordineTitle,
                notice: dettaglio.ordineNotice,
                options: dettaglio.ordineOptions,
                selectedValue: viewModel.ordineSelezionato
            ) { value in
                viewModel.ordineSelezionato = value
                viewModel.errore = ""
                viewModel.messaggioOperazione = ""
            }

            directorChoiceSection(
                title: dettaglio.ambulanzaTitle.isEmpty ? "Ambulanza" : dettaglio.ambulanzaTitle,
                notice: dettaglio.ambulanzaNotice,
                options: dettaglio.ambulanzaOptions,
                selectedValue: viewModel.ambulanzaSelezionata
            ) { value in
                viewModel.ambulanzaSelezionata = value
                viewModel.errore = ""
                viewModel.messaggioOperazione = ""
            }

            directorNotesBlock(
                title: dettaglio.ordineNoteTitle.isEmpty ? "Note sulle Misure d'Ordine e l'Ambulanza" : dettaglio.ordineNoteTitle,
                text: Binding(
                    get: { viewModel.noteOrdine },
                    set: {
                        viewModel.noteOrdine = $0
                        viewModel.errore = ""
                        viewModel.messaggioOperazione = ""
                    }
                ),
                placeholder: dettaglio.ordineNotePlaceholder,
                remaining: dettaglio.ordineNoteRemaining
            )
        }
    }

    private var directorListeContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Liste Gara")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Seleziona titolari, panchina e dirigenti per entrambe le squadre. Capitano e vice-capitano devono essere univoci per squadra. Se una persona non è presente nell'archivio Sinfonia4You puoi aggiungerla e poi usarla subito nella lista.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            directorTeamListCard(isHome: true, team: viewModel.listaCasa)
            directorTeamListCard(isHome: false, team: viewModel.listaFuori)
        }
    }

    private var directorDurataContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(viewModel.directorDurataTitle.isEmpty ? "Durata" : viewModel.directorDurataTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                directorDurataInfoCard(
                    title: viewModel.directorDurataStartTitle.isEmpty ? "Orario di Inizio Ufficiale della Gara" : viewModel.directorDurataStartTitle,
                    value: viewModel.directorDurataStartTime
                )
                directorDurataInfoCard(
                    title: viewModel.directorDurataEndTitle.isEmpty ? "Orario di Fine della Gara" : viewModel.directorDurataEndTitle,
                    value: viewModel.directorDurataEndTime
                )
            }

            if !viewModel.directorDurataNotice.isEmpty {
                Text(viewModel.directorDurataNotice)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFFD65E))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }

            directorDurataToolbar

            ForEach(viewModel.directorRegulationSegments) { segment in
                directorDurataSegmentCard(
                    segment: segment,
                    options: segment.isInterval ? viewModel.directorDurataIntervalOptions : viewModel.directorDurataGameOptions,
                    accent: segment.isInterval ? Color(hex: 0xFFD65E) : Color(hex: 0x68B5FF),
                    canAddEvent: !segment.isInterval,
                    canRemoveRow: !segment.isInterval && segment.rows.count > 1
                )
            }

            if !viewModel.directorExtraSegments.isEmpty {
                Text("Tempi supplementari")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            ForEach(viewModel.directorExtraSegments) { segment in
                directorDurataSegmentCard(
                    segment: segment,
                    options: segment.isInterval ? viewModel.directorDurataIntervalOptions : viewModel.directorDurataGameOptions,
                    accent: segment.isInterval ? Color(hex: 0xFFD65E) : Color(hex: 0x9EE37D),
                    canAddEvent: !segment.isInterval,
                    canRemoveRow: !segment.isInterval && segment.rows.count > 1
                )
            }

            if !viewModel.directorPenaltySegments.isEmpty {
                Text("Tiri di rigore")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            ForEach(viewModel.directorPenaltySegments) { segment in
                directorDurataSegmentCard(
                    segment: segment,
                    options: segment.isInterval ? viewModel.directorDurataIntervalOptions : viewModel.directorDurataRigoriOptions,
                    accent: segment.isInterval ? Color(hex: 0xFFD65E) : Color(hex: 0xFF9078),
                    canAddEvent: !segment.isInterval,
                    canRemoveRow: !segment.isInterval && segment.rows.count > 1
                )
            }
        }
    }

    private var directorDurataToolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    viewModel.aggiungiTempoRegolamentare()
                } label: {
                    Label("Tempo di gioco", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(hex: 0x7BD389))

                Button {
                    viewModel.rimuoviTempoRegolamentare()
                } label: {
                    Label("Rimuovi tempo", systemImage: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(0.72))
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.aggiungiTempoSupplementare()
                } label: {
                    Label("Supplementare", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(hex: 0x7BD389))

                Button {
                    viewModel.rimuoviTempoSupplementare()
                } label: {
                    Label("Rimuovi supplementare", systemImage: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(0.72))
                .disabled(viewModel.directorExtraSegments.isEmpty)
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.aggiungiTiriDiRigore()
                } label: {
                    Label("Tiri di rigore", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(hex: 0x7BD389))
                .disabled(!viewModel.directorPenaltySegments.isEmpty)

                Button {
                    viewModel.rimuoviTiriDiRigore()
                } label: {
                    Label("Rimuovi rigori", systemImage: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(0.72))
                .disabled(viewModel.directorPenaltySegments.isEmpty)
            }
        }
    }

    private func directorDurataInfoCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: 0xA8D0FF))

            Text(value.isEmpty ? "--:--" : value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func directorDurataSegmentCard(
        segment: RefertoDirectorDurationSegmentState,
        options: [RefertoSelectOptionDTO],
        accent: Color,
        canAddEvent: Bool,
        canRemoveRow: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(segment.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 12)

                if canAddEvent {
                    Button {
                        viewModel.aggiungiEventoDurata(phaseId: segment.phaseId, periodNumber: segment.periodNumber)
                    } label: {
                        Label("Aggiungi evento", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(accent)
                }
            }

            ForEach(segment.rows) { row in
                RefertoDirectorDurataRowEditorView(
                    row: row,
                    options: options,
                    accent: accent,
                    canRemove: canRemoveRow,
                    onTypeChange: {
                        viewModel.aggiornaDurataRiga(
                            phaseId: segment.phaseId,
                            periodNumber: segment.periodNumber,
                            markerType: segment.markerType,
                            rowId: row.id,
                            durationType: $0
                        )
                    },
                    onMinutesChange: {
                        viewModel.aggiornaDurataRiga(
                            phaseId: segment.phaseId,
                            periodNumber: segment.periodNumber,
                            markerType: segment.markerType,
                            rowId: row.id,
                            minutes: $0
                        )
                    },
                    onNoteChange: {
                        viewModel.aggiornaDurataRiga(
                            phaseId: segment.phaseId,
                            periodNumber: segment.periodNumber,
                            markerType: segment.markerType,
                            rowId: row.id,
                            note: $0
                        )
                    },
                    onRemove: {
                        viewModel.rimuoviEventoDurata(
                            phaseId: segment.phaseId,
                            periodNumber: segment.periodNumber,
                            rowId: row.id
                        )
                    }
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func directorTeamListCard(isHome: Bool, team: RefertoDirectorTeamState) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Text(team.teamName.isEmpty ? (isHome ? "Squadra locale" : "Squadra ospite") : team.teamName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 10) {
                    Button {
                        manualPersonDraft = .empty
                        addPersonTarget = isHome ? .home : .away
                    } label: {
                        Label("Aggiungi persona", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(hex: 0x7BD389))

                    Button {
                        selectedPersonToRemove = ""
                        removePersonTarget = isHome ? .home : .away
                    } label: {
                        Label("Rimuovi persona", systemImage: "person.badge.minus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .disabled(team.availablePeople.isEmpty)
                }
            }

            directorPlayerSection(
                title: "Calciatori titolari",
                rows: team.starters,
                team: team,
                isHome: isHome,
                section: "starters",
                accent: Color(hex: 0xF0B029)
            )

            directorPlayerSection(
                title: "Calciatori di riserva",
                rows: team.substitutes,
                team: team,
                isHome: isHome,
                section: "substitutes",
                accent: Color(hex: 0x6AC0FF)
            )

            directorStaffSection(
                title: "Dirigenti",
                rows: team.staff,
                team: team,
                isHome: isHome
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func teamState(for target: TeamTarget) -> RefertoDirectorTeamState {
        target.isHome ? viewModel.listaCasa : viewModel.listaFuori
    }

    private func directorPlayerSection(
        title: String,
        rows: [RefertoDirectorPlayerRowState],
        team: RefertoDirectorTeamState,
        isHome: Bool,
        section: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 12)

                Button {
                    viewModel.rimuoviRigaGiocatore(isHome: isHome, section: section)
                } label: {
                    Label("Rimuovi", systemImage: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(0.72))

                Button {
                    viewModel.aggiungiRigaGiocatore(isHome: isHome, section: section)
                } label: {
                    Label("Aggiungi", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(accent)
            }

            ForEach(rows) { row in
                RefertoDirectorPlayerEditorView(
                    row: row,
                    people: team.availablePeople,
                    documentOptions: dettaglio.documentOptions ?? [],
                    accent: accent,
                    onNumberChange: { viewModel.aggiornaNumeroMaglia(isHome: isHome, section: section, order: row.order, value: $0) },
                    onPersonChange: { viewModel.aggiornaPersonaCalciatore(isHome: isHome, section: section, order: row.order, value: $0) },
                    onCaptainChange: { viewModel.aggiornaCapitano(isHome: isHome, section: section, order: row.order, value: $0) },
                    onDocumentTypeChange: { viewModel.aggiornaDocumentoCalciatore(isHome: isHome, section: section, order: row.order, type: $0, number: nil) },
                    onDocumentNumberChange: { viewModel.aggiornaDocumentoCalciatore(isHome: isHome, section: section, order: row.order, type: nil, number: $0) }
                )
            }
        }
    }

    private func directorStaffSection(
        title: String,
        rows: [RefertoDirectorStaffRowState],
        team: RefertoDirectorTeamState,
        isHome: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 12)

                Button {
                    viewModel.rimuoviDirigente(isHome: isHome)
                } label: {
                    Label("Rimuovi", systemImage: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(0.72))

                Button {
                    viewModel.aggiungiDirigente(isHome: isHome)
                } label: {
                    Label("Aggiungi", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(hex: 0x7BD389))
            }

            ForEach(rows) { row in
                RefertoDirectorStaffEditorView(
                    row: row,
                    people: team.availablePeople,
                    roleOptions: (dettaglio.staffRoleOptions ?? []).filter { option in
                        isHome || option.value != "7"
                    },
                    documentOptions: dettaglio.documentOptions ?? [],
                    onRoleChange: { viewModel.aggiornaDirigente(isHome: isHome, order: row.order, roleId: $0) },
                    onPersonChange: { viewModel.aggiornaDirigente(isHome: isHome, order: row.order, personId: $0) },
                    onDocumentTypeChange: { viewModel.aggiornaDirigente(isHome: isHome, order: row.order, documentType: $0) },
                    onDocumentNumberChange: { viewModel.aggiornaDirigente(isHome: isHome, order: row.order, documentNumber: $0) }
                )
            }
        }
    }

    private func directorChoiceSection(
        title: String,
        notice: String,
        options: [RefertoSvolgimentoOptionDTO],
        selectedValue: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if !notice.isEmpty {
                Text(notice)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFFD65E))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }

            LazyVStack(spacing: 12) {
                ForEach(options) { option in
                    RefertoSvolgimentoOptionView(
                        option: option,
                        isSelected: selectedValue == option.value
                    ) {
                        onSelect(option.value)
                    }
                }
            }
        }
    }

    private func directorNotesBlock(
        title: String,
        text: Binding<String>,
        placeholder: String,
        remaining: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            TextEditor(text: text)
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .frame(minHeight: 150)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty, !placeholder.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.32))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 22)
                    }
                }

            if !remaining.isEmpty {
                Text(remaining)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
            }
        }
    }

    private var directorFooter: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            RefertoFooterButton(
                title: isFirstSupportedTab ? "Esci" : "Precedente",
                systemIcon: isFirstSupportedTab ? "xmark.circle.fill" : "arrow.left.circle.fill",
                tint: Color.white.opacity(0.08)
            ) {
                if isFirstSupportedTab {
                    dismiss()
                } else if let index = currentSupportedIndex, index > 0 {
                    let previous = supportedTabs[index - 1]
                    viewModel.directorCurrentTab = previous
                }
            }

            RefertoFooterButton(
                title: viewModel.inSalvataggio ? "Salvataggio..." : "Salva scheda",
                systemIcon: "square.and.arrow.down.fill",
                tint: Color(hex: 0xF3A52A)
            ) {
                Task {
                    await viewModel.salva(token: token, designazioneId: designazioneId)
                }
            }
            .disabled(viewModel.inSalvataggio)

            RefertoFooterButton(
                title: "Salva tutto",
                systemIcon: "externaldrive.fill.badge.checkmark",
                tint: Color(hex: 0x2C73D6)
            ) {
                Task {
                    await viewModel.salva(token: token, designazioneId: designazioneId)
                }
            }
            .disabled(viewModel.inSalvataggio)

            RefertoFooterButton(
                title: "Invia al G.S.",
                systemIcon: "envelope.fill",
                tint: Color(hex: 0xE5B11D),
                isDisabled: true
            ) {}

            RefertoFooterButton(
                title: "Stampa",
                systemIcon: "printer.fill",
                tint: Color(hex: 0xC24545),
                isDisabled: true
            ) {}

            RefertoFooterButton(
                title: "Successivo",
                systemIcon: "arrow.right.circle.fill",
                tint: Color(hex: 0x2A73D8),
                isDisabled: isLastSupportedTab
            ) {
                if isFirstSupportedTab, !supportedTabs.isEmpty {
                    let svolgimento = viewModel.svolgimentoSelezionato.trimmingCharacters(in: .whitespacesAndNewlines)
                    if svolgimento.isEmpty {
                        viewModel.errore = "Seleziona lo svolgimento della gara prima di proseguire."
                    } else if supportedTabs.count > 1 {
                        viewModel.directorCurrentTab = supportedTabs[1]
                    }
                } else if let index = currentSupportedIndex, index < supportedTabs.count - 1 {
                    viewModel.directorCurrentTab = supportedTabs[index + 1]
                }
            }
        }
    }
}
