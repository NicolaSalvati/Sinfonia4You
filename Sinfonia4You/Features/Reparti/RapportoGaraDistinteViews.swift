import PhotosUI
import SwiftUI
import UIKit
import VisionKit

struct RapportoGaraDistinteSectionView: View {
    let sessione: SessioneRapportoGara

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RapportoGaraDistinteNoticeBanner()

            ForEach(LatoSquadraRapportoGara.allCases) { lato in
                NavigationLink {
                    RapportoGaraDistintaTeamDetailView(
                        sessionID: sessione.id,
                        lato: lato,
                        titoloSessione: sessione.titoloGara,
                        expectedTeamName: sessione.nomeSquadraAttesa(for: lato)
                    )
                } label: {
                    RapportoGaraDistintaSummaryCard(
                        lato: lato,
                        distinta: sessione.distinte.slot(for: lato)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RapportoGaraDistintaSummaryCard: View {
    let lato: LatoSquadraRapportoGara
    let distinta: DistintaSquadraRapportoGara?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Distinta squadra di \(lato.titolo.lowercased())")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(sottotitolo)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(RapportoGaraDistintePalette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                RapportoGaraDistintaStatusBadge(state: distinta?.processingState ?? .processing, isEmpty: distinta == nil)
            }

            if let distinta {
                HStack(spacing: 8) {
                    RapportoGaraDistintaMetricPill(label: "Giocatori", value: "\(distinta.players.count)")
                    RapportoGaraDistintaMetricPill(label: "Titolari", value: "\(distinta.starters.count)")
                    RapportoGaraDistintaMetricPill(label: "Staff", value: "\(distinta.staff.count)")
                    RapportoGaraDistintaMetricPill(label: "Verifiche", value: "\(distinta.alertCount)")
                }
            } else {
                HStack(spacing: 10) {
                    Label("Scansiona distinta", systemImage: "doc.text.viewfinder")
                    Label("Importa da Foto", systemImage: "photo.on.rectangle.angled")
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.78))
            }

            HStack(spacing: 8) {
                Text("Apri dettaglio")
                    .font(.system(size: 13.5, weight: .bold))
                Spacer(minLength: 0)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(RapportoGaraDistintePalette.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var sottotitolo: String {
        guard let distinta else {
            return "Acquisisci una sola immagine per squadra, poi controlla e correggi i dati estratti."
        }

        switch distinta.processingState {
        case .processing:
            return "Sto analizzando l'immagine e costruendo i dati strutturati della distinta."
        case .ready:
            return "Distinta pronta. Tocca per controllare tutti i giocatori, staff e documenti."
        case .needsReview:
            return "Distinta acquisita con alert. Serve una verifica manuale prima di usarla in gara."
        case .error:
            return distinta.lastErrorMessage.isEmpty
                ? "L'elaborazione OCR non e riuscita. Tocca per rielaborare o correggere a mano."
                : distinta.lastErrorMessage
        }
    }
}

private struct RapportoGaraDistinteNoticeBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(RapportoGaraDistintePalette.accent)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(RapportoGaraDistintePalette.inlineSurface)
                )

            Text("La distinta OCR e un supporto operativo. Controlla sempre nomi, documenti, titolari e staff prima di affidarti al dato in partita.")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDistintaTeamDetailView: View {
    let sessionID: UUID
    let lato: LatoSquadraRapportoGara
    let titoloSessione: String
    let expectedTeamName: String?

    @StateObject private var store = RapportoGaraStore.shared
    @State private var isShowingScanner = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isProcessingImage = false
    @State private var processingMessage = ""
    @State private var modalitaModificaManuale = false
    @State private var playerDraft: DistintaGiocatoreRapportoGara?
    @State private var playerInfo: DistintaGiocatoreRapportoGara?
    @State private var playerToDeleteID: UUID?
    @State private var staffDraft: DistintaStaffRapportoGara?
    @State private var staffInfo: DistintaStaffRapportoGara?
    @State private var staffToDeleteID: UUID?
    @State private var isAddingPlayer = false
    @State private var isAddingStaff = false
    @State private var mostraConfermaEliminazione = false

    private var sessione: SessioneRapportoGara? {
        store.sessione(per: sessionID)
    }

    private var distinta: DistintaSquadraRapportoGara? {
        store.distinta(per: sessionID, lato: lato)
    }

    private var previewImage: UIImage? {
        guard let url = store.urlImmagineDistinta(per: sessionID, lato: lato) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private var titoloNavigazione: String {
        "Distinta \(lato.titolo)"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [RapportoGaraDistintePalette.primaryStart, RapportoGaraDistintePalette.primaryEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    RapportoGaraDistinteNoticeBanner()

                    if !processingMessage.isEmpty {
                        RapportoGaraDistintaInlineBanner(message: processingMessage)
                    }

                    RapportoGaraDistintaHeroCard(
                        lato: lato,
                        state: distinta?.processingState ?? .processing,
                        isEmpty: distinta == nil,
                        warningCount: distinta?.alertCount ?? 0
                    )

                    RapportoGaraDistintaCard(
                        title: "Acquisizione",
                        subtitle: "Gestisci la foto della distinta, rielabora l'OCR o passa in correzione manuale."
                    ) {
                        VStack(spacing: 10) {
                            RapportoGaraDistintaPrimaryButton(
                                title: distinta == nil ? "Scansiona distinta" : "Sostituisci con scanner",
                                systemImage: "doc.text.viewfinder",
                                action: { isShowingScanner = true }
                            )

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                                RapportoGaraDistintaSecondaryButton(
                                    title: distinta == nil ? "Importa da Foto" : "Sostituisci da Foto",
                                    systemImage: "photo.on.rectangle.angled",
                                    fullWidth: true
                                )
                            }

                            if distinta != nil {
                                RapportoGaraDistintaSecondaryButton(
                                    title: "Rielabora OCR",
                                    systemImage: "arrow.clockwise",
                                    fullWidth: true,
                                    action: rielaboraDistinta
                                )

                                RapportoGaraDistintaSecondaryButton(
                                    title: modalitaModificaManuale ? "Chiudi modifica manuale" : "Modifica manualmente",
                                    systemImage: modalitaModificaManuale ? "checkmark.circle.fill" : "pencil.and.scribble",
                                    fullWidth: true
                                ) {
                                    modalitaModificaManuale.toggle()
                                }

                                RapportoGaraDistintaSecondaryButton(
                                    title: "Elimina distinta",
                                    systemImage: "trash",
                                    fullWidth: true
                                ) {
                                    mostraConfermaEliminazione = true
                                }
                            }
                        }
                        .opacity(isProcessingImage || distinta?.processingState == .processing ? 0.88 : 1)
                    }

                    if let previewImage {
                        RapportoGaraDistintaCard(title: "Immagine sorgente", subtitle: "Anteprima della distinta acquisita.") {
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                        }
                    }

                    if let distinta {
                        RapportoGaraDistintaCard(
                            title: "Giocatori",
                            subtitle: "Ordine identico alla distinta: una card per ogni persona, senza riordinare per numero di maglia.",
                            warningCount: distinta.playerReviewCount
                        ) {
                            if distinta.players.isEmpty {
                                RapportoGaraDistintaEmptyMessage(
                                    title: "Nessun giocatore estratto",
                                    message: "Acquisisci meglio la distinta oppure inserisci manualmente tutta la rosa."
                                )
                            } else {
                                RapportoGaraDistintaPlayersList(
                                    players: distinta.orderedPlayers,
                                    isEditable: modalitaModificaManuale,
                                    onInfo: { playerInfo = $0 },
                                    onEdit: { playerDraft = $0 }
                                )
                            }

                            if modalitaModificaManuale {
                                RapportoGaraDistintaSecondaryButton(
                                    title: distinta.players.isEmpty ? "Aggiungi primo giocatore" : "Aggiungi giocatore",
                                    systemImage: "plus.circle.fill",
                                    fullWidth: true
                                ) {
                                    isAddingPlayer = true
                                }
                            }
                        }

                        RapportoGaraDistintaCard(
                            title: "Staff",
                            subtitle: "Dirigenti, tecnici e altre figure di distinta.",
                            warningCount: distinta.staffReviewCount
                        ) {
                            if distinta.staff.isEmpty {
                                RapportoGaraDistintaEmptyMessage(
                                    title: "Nessuno staff estratto",
                                    message: "Aggiungi manualmente i ruoli presenti nella distinta."
                                )
                            } else {
                                RapportoGaraDistintaStaffGroupedList(
                                    groups: distinta.staffGrouped,
                                    isEditable: modalitaModificaManuale,
                                    onInfo: { staffInfo = $0 },
                                    onEdit: { staffDraft = $0 }
                                )
                            }

                            if modalitaModificaManuale {
                                RapportoGaraDistintaSecondaryButton(
                                    title: "Aggiungi staff",
                                    systemImage: "plus.circle.fill",
                                    fullWidth: true
                                ) {
                                    isAddingStaff = true
                                }
                            }
                        }
                    } else {
                        RapportoGaraDistintaCard(title: "Distinta non acquisita", subtitle: "Scansiona o importa una foto per iniziare.") {
                            RapportoGaraDistintaEmptyMessage(
                                title: "Nessun file disponibile",
                                message: "Acquisisci la distinta di \(lato.titolo.lowercased()) e poi rivedi i dati estratti."
                            )
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(titoloNavigazione)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $isShowingScanner) {
            RapportoGaraDocumentScannerView { image in
                handleAcquiredImage(image)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $playerDraft) { player in
            NavigationStack {
                RapportoGaraDistintaPlayerEditorView(
                    title: "Modifica giocatore",
                    player: player,
                    onSave: { savePlayer($0) },
                    onDelete: { playerToDeleteID = player.id }
                )
            }
            .sinfoniaNavigationRoot()
        }
        .sheet(item: $playerInfo) { player in
            NavigationStack {
                RapportoGaraDistintaPlayerInfoView(player: player)
            }
            .sinfoniaNavigationRoot()
        }
        .sheet(isPresented: $isAddingPlayer) {
            NavigationStack {
                RapportoGaraDistintaPlayerEditorView(
                    title: "Nuovo giocatore",
                    player: DistintaGiocatoreRapportoGara(order: prossimoOrdineGiocatore),
                    onSave: { savePlayer($0) }
                )
            }
            .sinfoniaNavigationRoot()
        }
        .sheet(item: $staffDraft) { item in
            NavigationStack {
                RapportoGaraDistintaStaffEditorView(
                    title: "Modifica staff",
                    item: item,
                    onSave: { saveStaff($0) },
                    onDelete: { staffToDeleteID = item.id }
                )
            }
            .sinfoniaNavigationRoot()
        }
        .sheet(item: $staffInfo) { item in
            NavigationStack {
                RapportoGaraDistintaStaffInfoView(item: item)
            }
            .sinfoniaNavigationRoot()
        }
        .sheet(isPresented: $isAddingStaff) {
            NavigationStack {
                RapportoGaraDistintaStaffEditorView(
                    title: "Nuovo staff",
                    item: DistintaStaffRapportoGara(order: prossimoOrdineStaff, roleKind: .altro),
                    onSave: { saveStaff($0) }
                )
            }
            .sinfoniaNavigationRoot()
        }
        .confirmationDialog(
            "Eliminare la distinta?",
            isPresented: $mostraConfermaEliminazione,
            titleVisibility: .visible
        ) {
            Button("Elimina distinta", role: .destructive) {
                store.eliminaDistinta(sessionID: sessionID, lato: lato)
                modalitaModificaManuale = false
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Vengono rimossi l'immagine sorgente, l'OCR strutturato e le correzioni manuali di questa squadra.")
        }
        .alert("Eliminare il giocatore?", isPresented: Binding(
            get: { playerToDeleteID != nil },
            set: { if !$0 { playerToDeleteID = nil } }
        )) {
            Button("Elimina", role: .destructive) {
                guard let playerToDeleteID else { return }
                deletePlayer(id: playerToDeleteID)
                self.playerToDeleteID = nil
            }
            Button("Annulla", role: .cancel) {
                playerToDeleteID = nil
            }
        }
        .alert("Eliminare la figura staff?", isPresented: Binding(
            get: { staffToDeleteID != nil },
            set: { if !$0 { staffToDeleteID = nil } }
        )) {
            Button("Elimina", role: .destructive) {
                guard let staffToDeleteID else { return }
                deleteStaff(id: staffToDeleteID)
                self.staffToDeleteID = nil
            }
            Button("Annulla", role: .cancel) {
                staffToDeleteID = nil
            }
        }
        .task(id: selectedPhotoItem?.itemIdentifier) {
            guard let selectedPhotoItem else { return }
            await loadPhotoItem(selectedPhotoItem)
        }
    }

    private var prossimoOrdineGiocatore: Int {
        (distinta?.players.map(\.order).max() ?? 0) + 1
    }

    private var prossimoOrdineStaff: Int {
        (distinta?.staff.map(\.order).max() ?? 0) + 1
    }

    private func handleAcquiredImage(_ image: UIImage) {
        Task {
            await processImage(image, replacingExisting: true)
        }
    }

    @MainActor
    private func loadPhotoItem(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                processingMessage = "Non riesco a leggere la foto selezionata."
                return
            }
            await processImage(image, replacingExisting: true)
        } catch {
            processingMessage = "Import da Foto non riuscito: \(error.localizedDescription)"
        }
        selectedPhotoItem = nil
    }

    @MainActor
    private func processImage(_ image: UIImage, replacingExisting: Bool) async {
        guard let imageData = RapportoGaraDistinteOCRService.jpegData(from: image) else {
            processingMessage = "Non riesco a preparare l'immagine per l'OCR."
            return
        }

        guard let sourceImage = store.preparaElaborazioneDistinta(
            sessionID: sessionID,
            lato: lato,
            imageData: imageData,
            pixelWidth: Int(image.size.width),
            pixelHeight: Int(image.size.height)
        ) else {
            processingMessage = "Archiviazione locale della distinta non riuscita."
            return
        }

        isProcessingImage = true
        processingMessage = "Sto leggendo la distinta di \(lato.titolo.lowercased())..."

        do {
            let result = try await RapportoGaraDistinteOCRService.processa(
                image: image,
                lato: lato,
                expectedTeamName: expectedTeamName
            )
            store.salvaRisultatoDistinta(
                sessionID: sessionID,
                lato: lato,
                result: result,
                sourceImage: sourceImage
            )
            processingMessage = replacingExisting
                ? "Distinta \(lato.titolo.lowercased()) aggiornata."
                : "Distinta \(lato.titolo.lowercased()) elaborata."
        } catch {
            let issue = DistintaIssueRapportoGara(
                severity: .error,
                message: error.localizedDescription,
                section: "ocr"
            )
            let fallback = DistintaSquadraRapportoGara(
                processingState: .error,
                sourceImage: sourceImage,
                teamLabelOCR: "",
                lastProcessedAt: Date(),
                players: [],
                staff: [],
                issues: [issue],
                lastErrorMessage: error.localizedDescription
            )
            store.aggiornaDistinta(sessionID: sessionID, lato: lato, distinta: fallback)
            processingMessage = error.localizedDescription
        }

        isProcessingImage = false
    }

    private func rielaboraDistinta() {
        guard let url = store.urlImmagineDistinta(per: sessionID, lato: lato),
              let image = UIImage(contentsOfFile: url.path) else {
            processingMessage = "Non trovo l'immagine sorgente per rielaborare la distinta."
            return
        }

        Task {
            await processImage(image, replacingExisting: false)
        }
    }

    private func savePlayer(_ player: DistintaGiocatoreRapportoGara) {
        guard var distinta else { return }

        if let index = distinta.players.firstIndex(where: { $0.id == player.id }) {
            distinta.players[index] = player
        } else {
            distinta.players.append(player)
        }

        distinta.players = canonicalPlayers(distinta.players)
        distinta.lastProcessedAt = Date()
        if distinta.processingState == .error {
            distinta.processingState = .needsReview
        }
        store.aggiornaDistinta(sessionID: sessionID, lato: lato, distinta: distinta)
        playerDraft = nil
        isAddingPlayer = false
    }

    private func deletePlayer(id: UUID) {
        guard var distinta else { return }
        distinta.players.removeAll { $0.id == id }
        distinta.players = canonicalPlayers(distinta.players)
        distinta.lastProcessedAt = Date()
        if distinta.processingState == .error {
            distinta.processingState = .needsReview
        }
        store.aggiornaDistinta(sessionID: sessionID, lato: lato, distinta: distinta)
        playerDraft = nil
    }

    private func saveStaff(_ item: DistintaStaffRapportoGara) {
        guard var distinta else { return }

        if let index = distinta.staff.firstIndex(where: { $0.id == item.id }) {
            distinta.staff[index] = item
        } else {
            distinta.staff.append(item)
        }

        distinta.staff = canonicalStaff(distinta.staff)
        distinta.lastProcessedAt = Date()
        if distinta.processingState == .error {
            distinta.processingState = .needsReview
        }
        store.aggiornaDistinta(sessionID: sessionID, lato: lato, distinta: distinta)
        staffDraft = nil
        isAddingStaff = false
    }

    private func deleteStaff(id: UUID) {
        guard var distinta else { return }
        distinta.staff.removeAll { $0.id == id }
        distinta.staff = canonicalStaff(distinta.staff)
        distinta.lastProcessedAt = Date()
        if distinta.processingState == .error {
            distinta.processingState = .needsReview
        }
        store.aggiornaDistinta(sessionID: sessionID, lato: lato, distinta: distinta)
        staffDraft = nil
    }

    private func canonicalPlayers(_ players: [DistintaGiocatoreRapportoGara]) -> [DistintaGiocatoreRapportoGara] {
        players
            .sorted { $0.order < $1.order }
            .enumerated()
            .map { offset, item in
                var value = item
                value.order = offset + 1
                return value
            }
    }

    private func canonicalStaff(_ items: [DistintaStaffRapportoGara]) -> [DistintaStaffRapportoGara] {
        items
            .sorted { left, right in
                if left.order == right.order {
                    return left.fullName < right.fullName
                }
                return left.order < right.order
            }
            .enumerated()
            .map { offset, item in
                var value = item
                value.order = offset + 1
                return value
            }
    }
}

private struct RapportoGaraDistintaPlayersList: View {
    let players: [DistintaGiocatoreRapportoGara]
    let isEditable: Bool
    let onInfo: (DistintaGiocatoreRapportoGara) -> Void
    let onEdit: (DistintaGiocatoreRapportoGara) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(players) { player in
                RapportoGaraDistintaPlayerCompactCard(
                    player: player,
                    showsWarning: player.requiresManualReview,
                    isEditable: isEditable,
                    onInfo: { onInfo(player) },
                    onEdit: { onEdit(player) }
                )
            }
        }
    }
}

private struct RapportoGaraDistintaPlayersSections: View {
    let starters: [DistintaGiocatoreRapportoGara]
    let substitutes: [DistintaGiocatoreRapportoGara]
    let isEditable: Bool
    let onInfo: (DistintaGiocatoreRapportoGara) -> Void
    let onEdit: (DistintaGiocatoreRapportoGara) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RapportoGaraDistintaPlayerGroup(
                title: "Titolari",
                subtitle: "Riconosciuti con `T`, puntino oppure, se assenti, dai primi 11 in ordine di distinta.",
                players: starters,
                emptyTitle: "Nessun titolare",
                emptyMessage: "Non ho rilevato titolari in modo affidabile. Controlla gli alert OCR o correggi a mano.",
                isEditable: isEditable,
                onInfo: onInfo,
                onEdit: onEdit
            )

            RapportoGaraDistintaPlayerGroup(
                title: "Panchina e altri giocatori",
                subtitle: "Tutti i nominativi restanti presenti in distinta.",
                players: substitutes,
                emptyTitle: "Nessun altro giocatore",
                emptyMessage: "La distinta al momento contiene solo titolari oppure l'OCR non ha estratto la panchina.",
                isEditable: isEditable,
                onInfo: onInfo,
                onEdit: onEdit
            )
        }
    }
}

private struct RapportoGaraDistintaPlayerGroup: View {
    let title: String
    let subtitle: String
    let players: [DistintaGiocatoreRapportoGara]
    let emptyTitle: String
    let emptyMessage: String
    let isEditable: Bool
    let onInfo: (DistintaGiocatoreRapportoGara) -> Void
    let onEdit: (DistintaGiocatoreRapportoGara) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text("\(players.count)")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }

            if players.isEmpty {
                RapportoGaraDistintaEmptyMessage(
                    title: emptyTitle,
                    message: emptyMessage
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(players) { player in
                        RapportoGaraDistintaPlayerCompactCard(
                            player: player,
                            showsWarning: player.requiresManualReview,
                            isEditable: isEditable,
                            onInfo: { onInfo(player) },
                            onEdit: { onEdit(player) }
                        )
                    }
                }
            }
        }
    }
}

private struct RapportoGaraDistintaPlayerCompactCard: View {
    let player: DistintaGiocatoreRapportoGara
    let showsWarning: Bool
    let isEditable: Bool
    let onInfo: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [RapportoGaraDistintePalette.primaryStart, RapportoGaraDistintePalette.primaryEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(player.shirtNumber.nonEmpty ?? "—")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 6) {
                    Text(player.fullName.nonEmpty ?? "Giocatore senza nominativo")
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !player.quickMetadataLine.isEmpty {
                        Text(player.quickMetadataLine)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.68))
                    }
                }

                HStack(spacing: 8) {
                    if showsWarning {
                        RapportoGaraDistintaWarningDot()
                    }

                    Button(action: onInfo) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(RapportoGaraDistintePalette.accentSoft)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)

                    if isEditable {
                        Button(action: onEdit) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(RapportoGaraDistintePalette.accentSoft)
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDistintaStaffGroupedList: View {
    let groups: [(DistintaRoleKindRapportoGara, [DistintaStaffRapportoGara])]
    let isEditable: Bool
    let onInfo: (DistintaStaffRapportoGara) -> Void
    let onEdit: (DistintaStaffRapportoGara) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(groups, id: \.0) { group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(group.0.titolo)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(.white)

                        Spacer(minLength: 0)

                        Text("\(group.1.count)")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                    }

                    VStack(spacing: 10) {
                        ForEach(group.1) { item in
                            RapportoGaraDistintaStaffCompactCard(
                                item: item,
                                showsWarning: item.requiresManualReview,
                                isEditable: isEditable,
                                onInfo: { onInfo(item) },
                                onEdit: { onEdit(item) }
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct RapportoGaraDistintaStaffCompactCard: View {
    let item: DistintaStaffRapportoGara
    let showsWarning: Bool
    let isEditable: Bool
    let onInfo: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.fullName.nonEmpty ?? "Figura staff senza nominativo")
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(.white)

                Text(item.documentSummary)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .lineLimit(2)

                if let release = item.documentReleasedBy.nonEmpty {
                    Text(release)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.56))
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if showsWarning {
                    RapportoGaraDistintaWarningDot()
                }

                Button(action: onInfo) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(RapportoGaraDistintePalette.accentSoft)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)

                if isEditable {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(RapportoGaraDistintePalette.accentSoft)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDistintaMicroPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

private struct RapportoGaraDistintaInfoTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.52))

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDistintaMiniField: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.50))
            Text(value)
                .font(.system(size: 12.8, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDistintaDetailLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.60))
                .frame(width: 118, alignment: .leading)

            Text(value)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

private struct RapportoGaraDistintaPlayerInfoView: View {
    let player: DistintaGiocatoreRapportoGara
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                RapportoGaraDistintaCard(title: "Identita giocatore", subtitle: "Controllo completo dei dati della distinta.") {
                    VStack(spacing: 8) {
                        RapportoGaraDistintaDetailLine(label: "Numero", value: player.shirtNumber.nonEmpty ?? "Non indicato")
                        RapportoGaraDistintaDetailLine(label: "Data di nascita", value: player.birthDate.nonEmpty ?? "Non indicata")
                        RapportoGaraDistintaDetailLine(label: "Cognome", value: player.lastName.nonEmpty ?? "Non indicato")
                        RapportoGaraDistintaDetailLine(label: "Nome", value: player.firstName.nonEmpty ?? "Non indicato")
                        RapportoGaraDistintaDetailLine(label: "Documento", value: player.documentSummary.nonEmpty ?? "Non indicato")
                        RapportoGaraDistintaDetailLine(label: "Capitano / vice", value: player.captainLabel.nonEmpty ?? "Nessuno")
                        RapportoGaraDistintaDetailLine(label: "Matricola", value: player.matricola.nonEmpty ?? "Non indicata")
                    }
                }

                RapportoGaraDistintaCard(title: "Dettaglio documento", subtitle: "Tipo, numero e rilascio del documento di riconoscimento.") {
                    VStack(spacing: 8) {
                        RapportoGaraDistintaDetailLine(label: "Tipo", value: player.documentTypeRaw.nonEmpty ?? player.documentKind.titolo)
                        RapportoGaraDistintaDetailLine(label: "Numero", value: player.documentNumber.nonEmpty ?? "Non indicato")
                        RapportoGaraDistintaDetailLine(label: "Rilasciato da", value: player.documentReleasedBy.nonEmpty ?? "Non indicato")
                    }
                }
            }
            .padding(18)
        }
        .background(
            LinearGradient(
                colors: [RapportoGaraDistintePalette.primaryStart, RapportoGaraDistintePalette.primaryEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Dettaglio giocatore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Chiudi") {
                    dismiss()
                }
                .fontWeight(.bold)
            }
        }
    }
}

private struct RapportoGaraDistintaStaffInfoView: View {
    let item: DistintaStaffRapportoGara
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                RapportoGaraDistintaCard(title: "Figura staff", subtitle: "Controllo completo del ruolo e del documento associato.") {
                    VStack(spacing: 8) {
                        RapportoGaraDistintaDetailLine(label: "Ruolo", value: item.displayRole.nonEmpty ?? item.roleKind.titolo)
                        RapportoGaraDistintaDetailLine(label: "Nominativo", value: item.fullName.nonEmpty ?? "Non indicato")
                    }
                }

                RapportoGaraDistintaCard(title: "Documento", subtitle: "Tipo, numero e rilascio del documento registrato.") {
                    VStack(spacing: 8) {
                        RapportoGaraDistintaDetailLine(label: "Tipo", value: item.documentTypeRaw.nonEmpty ?? item.documentKind.titolo)
                        RapportoGaraDistintaDetailLine(label: "Numero", value: item.documentNumber.nonEmpty ?? "Non indicato")
                        RapportoGaraDistintaDetailLine(label: "Rilasciato da", value: item.documentReleasedBy.nonEmpty ?? "Non indicato")
                    }
                }
            }
            .padding(18)
        }
        .background(
            LinearGradient(
                colors: [RapportoGaraDistintePalette.primaryStart, RapportoGaraDistintePalette.primaryEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Dettaglio staff")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Chiudi") {
                    dismiss()
                }
                .fontWeight(.bold)
            }
        }
    }
}

private struct RapportoGaraDistintaActionPanel: View {
    let isProcessing: Bool
    let hasContent: Bool
    let onScan: () -> Void
    let onReprocess: () -> Void
    let onToggleManualEdit: () -> Void
    let onDelete: () -> Void
    let manualEditEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RapportoGaraDistintaPrimaryButton(
                    title: hasContent ? "Sostituisci con scanner" : "Scansiona distinta",
                    systemImage: "doc.text.viewfinder",
                    action: onScan
                )

                if hasContent {
                    RapportoGaraDistintaPrimaryButton(
                        title: "Rielabora",
                        systemImage: "arrow.clockwise",
                        action: onReprocess
                    )
                }
            }

            if hasContent {
                HStack(spacing: 10) {
                    RapportoGaraDistintaSecondaryButton(
                        title: manualEditEnabled ? "Chiudi modifica manuale" : "Modifica manualmente",
                        systemImage: manualEditEnabled ? "checkmark.circle.fill" : "pencil.and.scribble",
                        fullWidth: true,
                        action: onToggleManualEdit
                    )

                    RapportoGaraDistintaSecondaryButton(
                        title: "Elimina",
                        systemImage: "trash",
                        fullWidth: false,
                        action: onDelete
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .opacity(isProcessing ? 0.88 : 1)
    }
}

private struct RapportoGaraDistintaPlayersTable: View {
    let players: [DistintaGiocatoreRapportoGara]
    let isEditable: Bool
    let onTap: (DistintaGiocatoreRapportoGara) -> Void

    private let tableWidth: CGFloat = 940

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                RapportoGaraDistintaTableHeader(width: tableWidth) {
                    RapportoGaraDistintaTableTextCell("N.", width: 48)
                    RapportoGaraDistintaTableTextCell("Giocatore", width: 220)
                    RapportoGaraDistintaTableTextCell("Ruolo", width: 128)
                    RapportoGaraDistintaTableTextCell("Nascita", width: 108)
                    RapportoGaraDistintaTableTextCell("Matricola", width: 108)
                    RapportoGaraDistintaTableTextCell("Documento", width: 170)
                    RapportoGaraDistintaTableTextCell("Rilasciato da", width: 150)
                    RapportoGaraDistintaTableTextCell("Modifica", width: 76, alignment: .center)
                }

                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    RapportoGaraDistintaTableButtonRow(isEditable: isEditable, action: { onTap(player) }) {
                        RapportoGaraDistintaPlayerTableRow(player: player, isEditable: isEditable, isAlternate: index.isMultiple(of: 2))
                    }
                }
            }
            .frame(width: tableWidth, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDistintaPlayerTableRow: View {
    let player: DistintaGiocatoreRapportoGara
    let isEditable: Bool
    let isAlternate: Bool

    var body: some View {
        HStack(spacing: 0) {
            RapportoGaraDistintaTableValueCell(player.shirtNumber.nonEmpty ?? "—", width: 48)
            RapportoGaraDistintaTableValueCell(player.fullName.nonEmpty ?? "—", width: 220)
            RapportoGaraDistintaTableValueCell(player.tableRole, width: 128)
            RapportoGaraDistintaTableValueCell(player.birthDate.nonEmpty ?? "—", width: 108)
            RapportoGaraDistintaTableValueCell(player.matricola.nonEmpty ?? "—", width: 108)
            RapportoGaraDistintaTableValueCell(player.documentSummary, width: 170)
            RapportoGaraDistintaTableValueCell(player.documentReleasedBy.nonEmpty ?? "—", width: 150)
            HStack {
                Image(systemName: isEditable ? "pencil.circle.fill" : "circle.slash")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isEditable ? RapportoGaraDistintePalette.accentSoft : Color.white.opacity(0.28))
            }
            .frame(width: 76, alignment: .center)
        }
        .padding(.vertical, 10)
        .background(isAlternate ? Color.white.opacity(0.035) : Color.white.opacity(0.02))
    }
}

private struct RapportoGaraDistintaStaffTable: View {
    let items: [DistintaStaffRapportoGara]
    let isEditable: Bool
    let onTap: (DistintaStaffRapportoGara) -> Void

    private let tableWidth: CGFloat = 860

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                RapportoGaraDistintaTableHeader(width: tableWidth) {
                    RapportoGaraDistintaTableTextCell("Ruolo", width: 240)
                    RapportoGaraDistintaTableTextCell("Nominativo", width: 220)
                    RapportoGaraDistintaTableTextCell("Documento", width: 180)
                    RapportoGaraDistintaTableTextCell("Rilasciato da", width: 144)
                    RapportoGaraDistintaTableTextCell("Modifica", width: 76, alignment: .center)
                }

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    RapportoGaraDistintaTableButtonRow(isEditable: isEditable, action: { onTap(item) }) {
                        HStack(spacing: 0) {
                            RapportoGaraDistintaTableValueCell(item.displayRole.nonEmpty ?? "—", width: 240)
                            RapportoGaraDistintaTableValueCell(item.fullName.nonEmpty ?? "—", width: 220)
                            RapportoGaraDistintaTableValueCell(item.documentSummary, width: 180)
                            RapportoGaraDistintaTableValueCell(item.documentReleasedBy.nonEmpty ?? "—", width: 144)
                            HStack {
                                Image(systemName: isEditable ? "pencil.circle.fill" : "circle.slash")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(isEditable ? RapportoGaraDistintePalette.accentSoft : Color.white.opacity(0.28))
                            }
                            .frame(width: 76, alignment: .center)
                        }
                        .padding(.vertical, 10)
                        .background(index.isMultiple(of: 2) ? Color.white.opacity(0.035) : Color.white.opacity(0.02))
                    }
                }
            }
            .frame(width: tableWidth, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDistintaTableHeader<Content: View>: View {
    let width: CGFloat
    let content: Content

    init(width: CGFloat, @ViewBuilder content: () -> Content) {
        self.width = width
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .padding(.vertical, 10)
        .frame(width: width, alignment: .leading)
        .background(Color.white.opacity(0.08))
    }
}

private struct RapportoGaraDistintaTableTextCell: View {
    let text: String
    let width: CGFloat
    var alignment: Alignment = .leading

    init(_ text: String, width: CGFloat, alignment: Alignment = .leading) {
        self.text = text
        self.width = width
        self.alignment = alignment
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.62))
            .textCase(.uppercase)
            .lineLimit(1)
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, 12)
    }
}

private struct RapportoGaraDistintaTableValueCell: View {
    let text: String
    let width: CGFloat
    var alignment: Alignment = .leading

    init(_ text: String, width: CGFloat, alignment: Alignment = .leading) {
        self.text = text
        self.width = width
        self.alignment = alignment
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .frame(width: width, alignment: alignment)
            .padding(.horizontal, 12)
    }
}

private struct RapportoGaraDistintaTableButtonRow<Content: View>: View {
    let isEditable: Bool
    let action: () -> Void
    let content: Content

    init(isEditable: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isEditable = isEditable
        self.action = action
        self.content = content()
    }

    var body: some View {
        Group {
            if isEditable {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }
}

private struct RapportoGaraDistintaHeroCard: View {
    let lato: LatoSquadraRapportoGara
    let state: DistintaProcessingStateRapportoGara
    let isEmpty: Bool
    let warningCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("Distinta squadra di \(lato.titolo.lowercased())")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                RapportoGaraDistintaStatusBadge(state: state, isEmpty: isEmpty)
            }

            if warningCount > 0 {
                HStack(spacing: 10) {
                    RapportoGaraDistintaWarningDot(compact: false)

                    Text("\(warningCount) verifiche da controllare manualmente in questa distinta.")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [RapportoGaraDistintePalette.primaryStart.opacity(0.82), RapportoGaraDistintePalette.primaryEnd.opacity(0.96)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDistintaCard<Content: View>: View {
    let title: String
    let subtitle: String
    let warningCount: Int
    let content: Content

    init(
        title: String,
        subtitle: String,
        warningCount: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.warningCount = warningCount
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(RapportoGaraDistintePalette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if warningCount > 0 {
                    RapportoGaraDistintaSectionWarningBadge(count: warningCount)
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(RapportoGaraDistintePalette.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }
}

private struct RapportoGaraDistintaIssueRow: View {
    let issue: DistintaIssueRapportoGara

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: issue.severity == .error ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(issue.severity == .error ? Color(hex: 0xFF8B8B) : Color(hex: 0xFFD584))

                Text(issue.message)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let raw = issue.rawValue, !raw.isEmpty {
                Text(raw)
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .padding(.leading, 23)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDistintaPlayerRow: View {
    let player: DistintaGiocatoreRapportoGara
    let isEditable: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 6) {
                    Text(player.shirtNumber.isEmpty ? "--" : player.shirtNumber)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    if !player.captainLabel.isEmpty {
                        Text(player.captainLabel)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(RapportoGaraDistintePalette.accent)
                    }
                }
                .frame(width: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text(player.fullName.isEmpty ? "Giocatore senza nome" : player.fullName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    Text(detail)
                        .font(.system(size: 12.8, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.74))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if isEditable {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(RapportoGaraDistintePalette.accentSoft)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEditable)
    }

    private var detail: String {
        var parts: [String] = []
        if !player.birthDate.isEmpty {
            parts.append("Nato il \(player.birthDate)")
        }
        if !player.matricola.isEmpty {
            parts.append("Matricola \(player.matricola)")
        }
        if !player.documentTypeRaw.isEmpty || !player.documentNumber.isEmpty {
            let document = [player.documentTypeRaw, player.documentNumber].filter { !$0.isEmpty }.joined(separator: " ")
            if !document.isEmpty {
                parts.append(document)
            }
        }
        if !player.documentReleasedBy.isEmpty {
            parts.append(player.documentReleasedBy)
        }
        return parts.isEmpty ? "Nessun dettaglio aggiuntivo" : parts.joined(separator: " · ")
    }
}

private struct RapportoGaraDistintaStaffRow: View {
    let item: DistintaStaffRapportoGara
    let isEditable: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.displayRole)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(RapportoGaraDistintePalette.accentSoft)

                    Text(item.fullName.isEmpty ? "Nominativo da completare" : item.fullName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    Text(detail)
                        .font(.system(size: 12.8, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.74))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if isEditable {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(RapportoGaraDistintePalette.accentSoft)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEditable)
    }

    private var detail: String {
        var parts: [String] = []
        if !item.documentTypeRaw.isEmpty || !item.documentNumber.isEmpty {
            parts.append([item.documentTypeRaw, item.documentNumber].filter { !$0.isEmpty }.joined(separator: " "))
        }
        if !item.documentReleasedBy.isEmpty {
            parts.append(item.documentReleasedBy)
        }
        return parts.isEmpty ? "Nessun documento inserito" : parts.joined(separator: " · ")
    }
}

private struct RapportoGaraDistintaPlayerEditorView: View {
    let title: String
    let onSave: (DistintaGiocatoreRapportoGara) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: DistintaGiocatoreRapportoGara

    init(
        title: String,
        player: DistintaGiocatoreRapportoGara,
        onSave: @escaping (DistintaGiocatoreRapportoGara) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.title = title
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: player)
    }

    var body: some View {
        Form {
            Section("Identita") {
                TextField("Numero maglia", text: $draft.shirtNumber)
                    .keyboardType(.numberPad)
                TextField("Cognome", text: $draft.lastName)
                TextField("Nome", text: $draft.firstName)
                TextField("Data di nascita", text: $draft.birthDate)
                Toggle("Titolare", isOn: $draft.isStarter)
                Picker("Capitano / vice", selection: $draft.captainCode) {
                    Text("Nessuno").tag("")
                    Text("Capitano").tag("C")
                    Text("Vice").tag("V")
                }
            }

            Section("Tesseramento") {
                TextField("Matricola FIGC", text: $draft.matricola)
                Picker("Tipo documento", selection: $draft.documentKind) {
                    ForEach(DistintaDocumentKindRapportoGara.allCases) { kind in
                        Text(kind.titolo).tag(kind)
                    }
                }
                TextField("Tipo documento raw", text: $draft.documentTypeRaw)
                TextField("Numero documento", text: $draft.documentNumber)
                TextField("Rilasciato da", text: $draft.documentReleasedBy)
            }

            if onDelete != nil {
                Section {
                    Button("Elimina giocatore", role: .destructive) {
                        onDelete?()
                        dismiss()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [RapportoGaraDistintePalette.primaryStart, RapportoGaraDistintePalette.primaryEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Chiudi") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Salva") {
                    draft.shirtNumber = draft.shirtNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.firstName = draft.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.lastName = draft.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.birthDate = draft.birthDate.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.matricola = draft.matricola.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.documentTypeRaw = draft.documentTypeRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.documentNumber = draft.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.documentReleasedBy = draft.documentReleasedBy.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(draft)
                    dismiss()
                }
                .fontWeight(.bold)
            }
        }
    }
}

private struct RapportoGaraDistintaStaffEditorView: View {
    let title: String
    let onSave: (DistintaStaffRapportoGara) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: DistintaStaffRapportoGara

    init(
        title: String,
        item: DistintaStaffRapportoGara,
        onSave: @escaping (DistintaStaffRapportoGara) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.title = title
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: item)
    }

    var body: some View {
        Form {
            Section("Ruolo") {
                Picker("Ruolo", selection: $draft.roleKind) {
                    ForEach(DistintaRoleKindRapportoGara.allCases) { kind in
                        Text(kind.titolo).tag(kind)
                    }
                }
                TextField("Ruolo raw", text: $draft.roleRaw)
                TextField("Cognome", text: $draft.lastName)
                TextField("Nome", text: $draft.firstName)
            }

            Section("Documento") {
                Picker("Tipo documento", selection: $draft.documentKind) {
                    ForEach(DistintaDocumentKindRapportoGara.allCases) { kind in
                        Text(kind.titolo).tag(kind)
                    }
                }
                TextField("Tipo documento raw", text: $draft.documentTypeRaw)
                TextField("Numero documento", text: $draft.documentNumber)
                TextField("Rilasciato da", text: $draft.documentReleasedBy)
            }

            if onDelete != nil {
                Section {
                    Button("Elimina figura staff", role: .destructive) {
                        onDelete?()
                        dismiss()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [RapportoGaraDistintePalette.primaryStart, RapportoGaraDistintePalette.primaryEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Chiudi") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Salva") {
                    draft.roleRaw = draft.roleRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.firstName = draft.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.lastName = draft.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.documentTypeRaw = draft.documentTypeRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.documentNumber = draft.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.documentReleasedBy = draft.documentReleasedBy.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(draft)
                    dismiss()
                }
                .fontWeight(.bold)
            }
        }
    }
}

private struct RapportoGaraDocumentScannerView: UIViewControllerRepresentable {
    let onScan: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, dismiss: dismiss)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: RapportoGaraDocumentScannerView
        private let dismiss: DismissAction

        init(parent: RapportoGaraDocumentScannerView, dismiss: DismissAction) {
            self.parent = parent
            self.dismiss = dismiss
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let images = (0..<scan.pageCount).map(scan.imageOfPage(at:))
            if let combined = combine(images: images) {
                parent.onScan(combined)
            }
            dismiss()
        }

        private func combine(images: [UIImage]) -> UIImage? {
            guard !images.isEmpty else { return nil }
            if images.count == 1 {
                return images[0]
            }

            let targetWidth = images.map { $0.size.width }.max() ?? 0
            guard targetWidth > 0 else { return nil }

            let resizedHeights = images.map { image in
                image.size.height * (targetWidth / max(1, image.size.width))
            }

            let totalHeight = resizedHeights.reduce(0, +)
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetWidth, height: totalHeight))

            return renderer.image { _ in
                UIColor.white.setFill()
                UIBezierPath(rect: CGRect(x: 0, y: 0, width: targetWidth, height: totalHeight)).fill()

                var currentY: CGFloat = 0
                for (index, image) in images.enumerated() {
                    let height = resizedHeights[index]
                    image.draw(in: CGRect(x: 0, y: currentY, width: targetWidth, height: height))
                    currentY += height
                }
            }
        }
    }
}

private struct RapportoGaraDistintaStatusBadge: View {
    let state: DistintaProcessingStateRapportoGara
    let isEmpty: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.28))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(color.opacity(0.40), lineWidth: 1)
            )
    }

    private var label: String {
        if isEmpty {
            return "Da acquisire"
        }
        switch state {
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

    private var color: Color {
        if isEmpty {
            return RapportoGaraDistintePalette.accentSoft
        }
        switch state {
        case .processing:
            return RapportoGaraDistintePalette.accentSoft
        case .ready:
            return Color(hex: 0x82D4AE)
        case .needsReview:
            return Color(hex: 0xF4C56B)
        case .error:
            return Color(hex: 0xFF8B8B)
        }
    }
}

private struct RapportoGaraDistintaMetricPill: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.48))
            Text(value)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDistintaSectionWarningBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .bold))
            Text("\(count)")
                .font(.system(size: 11.5, weight: .bold))
        }
        .foregroundStyle(RapportoGaraDistintePalette.warning)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(RapportoGaraDistintePalette.warningBackground)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(RapportoGaraDistintePalette.warning.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDistintaWarningDot: View {
    var compact: Bool = true

    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: compact ? 12 : 13, weight: .bold))
            .foregroundStyle(RapportoGaraDistintePalette.warning)
            .frame(width: compact ? 28 : 30, height: compact ? 28 : 30)
            .background(
                Circle()
                    .fill(RapportoGaraDistintePalette.warningBackground)
            )
            .overlay(
                Circle()
                    .stroke(RapportoGaraDistintePalette.warning.opacity(0.35), lineWidth: 1)
            )
    }
}

private struct RapportoGaraDistintaInlineBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.white)

            Text(message)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDistintaEmptyMessage: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(RapportoGaraDistintePalette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct RapportoGaraDistintaPrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13.5, weight: .bold))
                Text(title)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [RapportoGaraDistintePalette.primaryStart, RapportoGaraDistintePalette.primaryEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RapportoGaraDistintaSecondaryButton: View {
    let title: String
    let systemImage: String
    let fullWidth: Bool
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    label
                }
                .buttonStyle(.plain)
            } else {
                label
            }
        }
    }

    private var label: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
            Text(title)
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
            if fullWidth {
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private enum RapportoGaraDistintePalette {
    static let primaryStart = Color(hex: 0x0D4C8D)
    static let primaryEnd = Color(hex: 0x101934)
    static let surface = Color(hex: 0x153C73).opacity(0.34)
    static let inlineSurface = Color(hex: 0x153C73).opacity(0.24)
    static let accent = Color(hex: 0x7EAEFF)
    static let accentSoft = Color(hex: 0x94C1FF)
    static let warning = Color(hex: 0xF6B35B)
    static let warningBackground = Color(hex: 0xF6B35B).opacity(0.16)
    static let textMuted = Color.white.opacity(0.66)
}

private extension SessioneRapportoGara {
    func nomeSquadraAttesa(for lato: LatoSquadraRapportoGara) -> String? {
        let separators = [" vs ", " VS ", " Vs ", " - ", " – ", " — "]
        for separator in separators {
            let parts = titoloGara.components(separatedBy: separator)
            guard parts.count == 2 else { continue }
            let cleaned = parts.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            switch lato {
            case .casa:
                return cleaned[0].isEmpty ? nil : cleaned[0]
            case .ospiti:
                return cleaned[1].isEmpty ? nil : cleaned[1]
            }
        }
        return nil
    }
}

private extension DistintaGiocatoreRapportoGara {
    var requiresManualReview: Bool {
        shirtNumber.nonEmpty == nil
        || fullName.nonEmpty == nil
        || birthDate.nonEmpty == nil
        || documentNumber.nonEmpty == nil
    }

    var quickMetadataLine: String {
        var parts: [String] = []
        parts.append(isStarter ? "Titolare" : "Panchina")
        if !captainLabel.isEmpty {
            parts.append(captainLabel)
        }
        return parts.joined(separator: " · ")
    }

    var tableRole: String {
        var parts: [String] = [isStarter ? "Titolare" : "Panchina"]
        if !captainLabel.isEmpty {
            parts.append(captainLabel)
        }
        return parts.joined(separator: " · ")
    }

    var documentSummary: String {
        let type = documentTypeRaw.nonEmpty ?? (documentKind == .altro ? "" : documentKind.titolo)
        let combined = [type, documentNumber].filter { !$0.isEmpty }.joined(separator: " ")
        return combined.isEmpty ? "—" : combined
    }
}

private extension DistintaStaffRapportoGara {
    var requiresManualReview: Bool {
        fullName.nonEmpty == nil
        || documentNumber.nonEmpty == nil
    }

    var documentSummary: String {
        let type = documentTypeRaw.nonEmpty ?? (documentKind == .altro ? "" : documentKind.titolo)
        let combined = [type, documentNumber].filter { !$0.isEmpty }.joined(separator: " ")
        return combined.isEmpty ? "—" : combined
    }
}

private extension DistintaSquadraRapportoGara {
    var playerReviewCount: Int {
        let parserIssues = issues.filter { $0.section == "giocatori" }.count
        let localIssues = players.filter(\.requiresManualReview).count
        return max(parserIssues, localIssues)
    }

    var staffReviewCount: Int {
        let parserIssues = issues.filter { $0.section == "staff" }.count
        let localIssues = staff.filter(\.requiresManualReview).count
        return max(parserIssues, localIssues)
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
