//
//  FormOperativiViews.swift
//  Sinfonia4You
//
//  Viste native dei moduli operativi in scrittura.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

private enum IbanOperativoPalette {
    static let accent = Color(hex: 0x4EA0FF)
    static let accentSoft = Color(hex: 0x9EC8FF)
    static let surface = Color.white.opacity(0.045)
    static let inlineSurface = Color.white.opacity(0.08)
    static let textMuted = Color.white.opacity(0.66)
}

private enum DocumentiOperativiPalette {
    static let accent = Color(hex: 0x4EA0FF)
    static let accentSoft = Color(hex: 0x9EC8FF)
    static let surface = Color.white.opacity(0.045)
    static let inlineSurface = Color.white.opacity(0.08)
    static let textMuted = Color.white.opacity(0.66)
    static let uploaded = Color(hex: 0x4EA0FF)
    static let pending = Color(hex: 0xF3B24F)
    static let missing = Color.white.opacity(0.50)
}

@ViewBuilder
func vistaDestinazioneModulo(
    token: String,
    modulo: RepartoSintesiDTO,
    onRequireLogout: @escaping () -> Void
) -> some View {
    switch modulo.id {
    case "iban":
        VistaIbanOperativa(token: token)
    case "certificate_renewal":
        VistaRinnovoCertificatoOperativo(token: token)
    case "indisponibilita_request":
        VistaIndisponibilitaOperativa(token: token)
    case "congedo_request":
        VistaCongedoOperativo(token: token)
    case "preclusione_request":
        VistaPreclusioneOperativa(token: token)
    case "domande_request":
        VistaDomandeOperative(token: token)
    case "documents":
        VistaDocumentiOperativi(token: token)
    case "account":
        VistaAccountOperativo(token: token, onRequireLogout: onRequireLogout)
    case "events":
        VistaEventiOperativi(token: token)
    case "technical_sheet":
        VistaSchedaTecnica(token: token)
    case "match_report":
        VistaRapportoGaraModulo(token: token)
    case "regulations":
        VistaRegolamentiOperativi()
    default:
        VistaSnapshotModulo(token: token, modulo: modulo)
    }
}

private struct DocumentoRegolamento: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let badge: String
    let systemIcon: String
    let url: URL
}

private let documentiRegolamento: [DocumentoRegolamento] = [
    DocumentoRegolamento(
        id: "football",
        title: "Gioco del Calcio",
        subtitle: "Testo ufficiale aggiornato 2025 per il calcio a 11.",
        badge: "2025",
        systemIcon: "soccerball.inverse",
        url: URL(string: "https://www.aia-figc.it/download/regolamenti/reg_2025.pdf")!
    ),
    DocumentoRegolamento(
        id: "futsal",
        title: "Calcio a 5",
        subtitle: "Regolamento ufficiale aggiornato 2025.",
        badge: "2025",
        systemIcon: "figure.indoor.soccer",
        url: URL(string: "https://www.aia-figc.it/download/regolamenti/reg_2025_c5.pdf")!
    ),
    DocumentoRegolamento(
        id: "beach",
        title: "Beach Soccer",
        subtitle: "Regolamento ufficiale aggiornato 2026.",
        badge: "2026",
        systemIcon: "sun.max",
        url: URL(string: "https://www.aia-figc.it/download/regolamenti/reg_2026_beachsoccer.pdf?v=1")!
    )
]

struct VistaRegolamentiOperativi: View {
    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    RegolamentiHeaderView()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Documenti disponibili")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        ForEach(documentiRegolamento) { documento in
                            NavigationLink {
                                VistaPDFRegolamento(documento: documento)
                            } label: {
                                RegolamentoCardView(documento: documento)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Regolamenti")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct RegolamentiHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 56, height: 56)

                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x9EC8FF))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Regolamenti")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Apri subito i PDF ufficiali AIA utili prima della gara.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Trovi qui i regolamenti di Gioco del Calcio, Calcio a 5 e Beach Soccer sempre raggiungibili dal menu Gestione Gare.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: 0xD7E8FF).opacity(0.90))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x1778D8), Color(hex: 0x14386E)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct RegolamentoCardView: View {
    let documento: DocumentoRegolamento

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: documento.systemIcon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(hex: 0x8DBDFF))
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(documento.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(documento.badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(hex: 0x2E7BE0).opacity(0.28))
                        )
                }

                Text(documento.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.42))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct VistaPDFRegolamento: View {
    let documento: DocumentoRegolamento
    @State private var document: PDFDocument?
    @State private var inCaricamento = true
    @State private var errore = ""

    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            Group {
                if inCaricamento {
                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(.white)
                        Text("Sto caricando il regolamento ufficiale.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                } else if let document {
                    PDFDocumentView(document: document)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 120)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        StatoVuotoView(
                            titolo: "Regolamento non disponibile",
                            messaggio: errore.isEmpty ? "Non sono riuscito ad aprire il PDF ufficiale." : errore
                        )

                        Link(destination: documento.url) {
                            PulsanteSecondarioView(titolo: "Apri sul sito ufficiale")
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 18)
                    }
                }
            }
        }
        .navigationTitle(documento.title)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Link(destination: documento.url) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.white)
                }
            }
        }
        .task {
            await caricaDocumento()
        }
    }

    private func caricaDocumento() async {
        guard inCaricamento else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: documento.url)
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                throw URLError(.badServerResponse)
            }

            guard let pdf = PDFDocument(data: data) else {
                errore = "Il file ricevuto non è un PDF valido."
                inCaricamento = false
                return
            }

            document = pdf
            errore = ""
        } catch {
            errore = error.localizedDescription
        }

        inCaricamento = false
    }
}

private struct PDFDocumentView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.usePageViewController(false)
        view.document = document
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

struct VistaIbanOperativa: View {
    let token: String
    @StateObject private var viewModel = IbanOperativoViewModel()
    @State private var mostraPicker = false
    @State private var mostraConferma = false

    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.inCaricamento {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                    } else if !viewModel.errore.isEmpty && viewModel.config == nil {
                        StatoVuotoView(titolo: "Gestione IBAN non disponibile", messaggio: viewModel.errore)
                    } else if let config = viewModel.config {
                        let inserimentoBloccato = ibanInsertionLocked(config)

                        IbanOperativoHeaderView(
                            titolo: config.title,
                            stato: config.currentStatus,
                            hasIban: !config.currentIban.isEmpty
                        )

                        IbanOperativoSummaryView(
                            iban: config.currentIban,
                            stato: config.currentStatus
                        )

                        if !viewModel.messaggio.isEmpty {
                            IbanOperativoInfoCard(
                                titolo: "Esito",
                                testo: viewModel.messaggio,
                                icon: "checkmark.circle.fill"
                            )
                        }
                        if !viewModel.errore.isEmpty {
                            IbanOperativoInfoCard(
                                titolo: "Errore",
                                testo: viewModel.errore,
                                icon: "exclamationmark.triangle.fill"
                            )
                        }
                        if !config.introText.isEmpty && !inserimentoBloccato {
                            IbanOperativoInfoCard(
                                titolo: "Istruzioni",
                                testo: config.introText,
                                icon: "text.document.fill"
                            )
                        }

                        if inserimentoBloccato {
                            IbanOperativoLockedStateView(
                                message: ibanLockedMessage(config)
                            )
                        } else {
                            IbanOperativoSectionCard(
                                titolo: "Aggiorna coordinate",
                                sottotitolo: "Inserisci il nuovo IBAN come sul portale e verifica il codice prima di confermare."
                            ) {
                                CampoTestoOperativo(
                                    titolo: "Nuovo IBAN",
                                    placeholder: "Inserisci IBAN",
                                    text: $viewModel.ibanCode
                                )
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .keyboardType(.asciiCapable)
                            }

                            IbanOperativoSectionCard(
                                titolo: "Modulo allegato",
                                sottotitolo: "Carica il documento richiesto nel formato previsto dal modulo."
                            ) {
                                SelettoreFileOperativo(
                                    titolo: "Documento",
                                    file: viewModel.fileSelezionato,
                                    buttonTitle: "Seleziona file",
                                    supportText: "Formati: \(config.allowedExtensions.joined(separator: ", "))",
                                    onPick: { mostraPicker = true },
                                    onClear: { viewModel.fileSelezionato = nil }
                                )
                            }

                            IbanOperativoSectionCard(
                                titolo: "Dichiarazione obbligatoria",
                                sottotitolo: "La spunta è richiesta per abilitare l'inserimento del nuovo IBAN."
                            ) {
                                IbanOperativoDeclarationRowView(
                                    text: config.declarationText,
                                    isChecked: $viewModel.dichiarazioneConfermata
                                )
                            }

                            Button(action: {
                                if viewModel.preparaInvio() {
                                    mostraConferma = true
                                }
                            }) {
                                PulsantePrimarioView(
                                    titolo: viewModel.inInvio ? "Invio..." : config.submitLabel,
                                    coloreA: 0x1E7BEA,
                                    coloreB: 0x0C4B9B
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.puoPresentareConferma)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Gestione IBAN")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.carica(token: token) }
        .onChange(of: viewModel.ibanCode) { _, newValue in
            viewModel.aggiornaIbanInput(newValue)
        }
        .fileImporter(isPresented: $mostraPicker, allowedContentTypes: tipiFileConsentiti) { result in
            importaFile(result: result, errore: $viewModel.errore) { viewModel.fileSelezionato = $0 }
        }
        .alert("Conferma invio", isPresented: $mostraConferma) {
            Button("Annulla", role: .cancel) {}
            Button("Invia") {
                Task { _ = await viewModel.invia(token: token) }
            }
        } message: {
            Text("Conferma il cambio IBAN e l'eventuale allegato.")
        }
    }

    private func ibanInsertionLocked(_ config: IbanConfigDTO) -> Bool {
        let status = config.currentStatus.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let intro = config.introText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if status.contains("ATTESA APPROVAZIONE") || status.contains("ATTESA APPROVAZIONE MODIFICA") {
            return true
        }
        if intro.contains("non è possibile inserire nuove coordinate al momento")
            || intro.contains("non e possibile inserire nuove coordinate al momento")
            || intro.contains("dati in attesa di approvazione")
            || intro.contains("dati in attesa di approvazione o cancellazione") {
            return true
        }
        return false
    }

    private func ibanLockedMessage(_ config: IbanConfigDTO) -> String {
        let intro = config.introText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !intro.isEmpty {
            return intro
        }
        return "Poiché esistono dati in attesa di approvazione o cancellazione, non è possibile inserire nuove coordinate al momento."
    }
}

private struct IbanOperativoLockedStateView: View {
    let message: String

    var body: some View {
        IbanOperativoSectionCard(
            titolo: "Inserimento temporaneamente bloccato",
            sottotitolo: "Il portale ha già registrato una richiesta e attende la validazione della modifica."
        ) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "hourglass.badge.exclamationmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(IbanOperativoPalette.accentSoft)
                    }

                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(IbanOperativoPalette.inlineSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(IbanOperativoPalette.accent.opacity(0.18), lineWidth: 1)
            )
        }
    }
}

private struct IbanOperativoDeclarationRowView: View {
    let text: String
    @Binding var isChecked: Bool

    private var declarationText: String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty
            ? "Dichiaro, sotto la mia responsabilità, che l'IBAN qui indicato è associato ad uno strumento bancario a me intestato e che lo stesso può ricevere bonifici in entrata."
            : clean
    }

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isChecked ? IbanOperativoPalette.accent.opacity(0.24) : Color.white.opacity(0.06))
                        .frame(width: 28, height: 28)

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isChecked ? IbanOperativoPalette.accent.opacity(0.70) : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                        .frame(width: 28, height: 28)

                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(declarationText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(isChecked ? "Dichiarazione confermata" : "Seleziona per confermare la dichiarazione")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isChecked ? IbanOperativoPalette.accentSoft : IbanOperativoPalette.textMuted)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(IbanOperativoPalette.inlineSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(IbanOperativoPalette.accent.opacity(isChecked ? 0.28 : 0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct IbanOperativoHeaderView: View {
    let titolo: String
    let stato: String
    let hasIban: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(IbanOperativoPalette.inlineSurface)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(IbanOperativoPalette.accentSoft)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("GESTIONE IBAN")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(IbanOperativoPalette.accent)
                        .tracking(1.2)

                    Text(titolo)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Coordinate correnti, stato del modulo e aggiornamento in un unico spazio ordinato.")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(IbanOperativoPalette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                IbanOperativoBadge(
                    title: stato.isEmpty ? "Stato non disponibile" : stato,
                    icon: "checklist"
                )
                IbanOperativoBadge(
                    title: hasIban ? "IBAN presente" : "IBAN assente",
                    icon: "creditcard.and.123"
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(IbanOperativoPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(IbanOperativoPalette.accent.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct IbanOperativoSummaryView: View {
    let iban: String
    let stato: String

    private var ibanPulito: String {
        iban.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Coordinate attuali")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text("IBAN")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(IbanOperativoPalette.accentSoft)

                Text(ibanPulito.isEmpty ? "Non presente" : ibanPulito)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(IbanOperativoPalette.inlineSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(IbanOperativoPalette.accent.opacity(0.16), lineWidth: 1)
            )

            HStack(spacing: 10) {
                IbanOperativoMiniStat(title: "Stato", value: stato.isEmpty ? "-" : stato)
                IbanOperativoMiniStat(title: "Verifica", value: ibanPulito.isEmpty ? "Richiesta" : "Pronta")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(IbanOperativoPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(IbanOperativoPalette.accent.opacity(0.20), lineWidth: 1)
        )
    }
}

private struct IbanOperativoSectionCard<Content: View>: View {
    let titolo: String
    let sottotitolo: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(titolo)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(sottotitolo)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(IbanOperativoPalette.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(IbanOperativoPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(IbanOperativoPalette.accent.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct IbanOperativoInfoCard: View {
    let titolo: String
    let testo: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(IbanOperativoPalette.inlineSurface)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(IbanOperativoPalette.accentSoft)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(titolo)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(testo)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(IbanOperativoPalette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(IbanOperativoPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(IbanOperativoPalette.accent.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct IbanOperativoBadge: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(IbanOperativoPalette.inlineSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(IbanOperativoPalette.accent.opacity(0.16), lineWidth: 1)
            )
    }
}

private struct IbanOperativoMiniStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(IbanOperativoPalette.accentSoft)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(IbanOperativoPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(IbanOperativoPalette.accent.opacity(0.16), lineWidth: 1)
        )
    }
}

struct VistaRinnovoCertificatoOperativo: View {
    let token: String
    @StateObject private var viewModel = RinnovoCertificatoViewModel()
    @State private var mostraPicker = false
    @State private var mostraConferma = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.inCaricamento {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 32)
                } else if !viewModel.errore.isEmpty && viewModel.config == nil {
                    StatoVuotoView(titolo: "Rinnovo certificato non disponibile", messaggio: viewModel.errore)
                } else if let config = viewModel.config {
                    CardTitoloView(titolo: config.title, sottotitolo: "Rinnovo certificato")
                    riepilogoCorrente(title: "Certificato attuale", rows: [
                        ("Tipo", config.currentType),
                        ("Scadenza", config.currentExpiry),
                        ("Ente", config.currentIssuer),
                        ("Validatore", config.validatorLabel)
                    ])
                    statoMessaggi(errore: viewModel.errore, messaggio: viewModel.messaggio)
                    if !config.introText.isEmpty { BloccoTestoView(titolo: "Istruzioni", testo: config.introText) }

                    PickerOperativo(titolo: "Tipo certificato", selection: $viewModel.tipoSelezionato, options: config.types)
                    CampoTestoOperativo(titolo: "Data rilascio", placeholder: "GG/MM/AAAA", text: $viewModel.dataRilascio)
                    CampoTestoOperativo(titolo: "Data scadenza", placeholder: "GG/MM/AAAA", text: $viewModel.dataScadenza)
                    CampoTestoOperativo(titolo: "Ente certificatore", placeholder: "Medico / struttura", text: $viewModel.enteCertificatore)
                    CampoAreaOperativa(titolo: "Note", text: $viewModel.note, maxLen: config.noteMaxLen)
                    SelettoreFileOperativo(
                        titolo: "Certificato",
                        file: viewModel.fileSelezionato,
                        buttonTitle: "Allega certificato",
                        supportText: "Max \(config.maxSizeBytes / 1024) KB · \(config.allowedExtensions.joined(separator: ", "))",
                        onPick: { mostraPicker = true },
                        onClear: { viewModel.fileSelezionato = nil }
                    )
                    if !config.legalText.isEmpty { BloccoTestoView(titolo: "Trattamento e validità", testo: config.legalText) }
                    Button(action: { mostraConferma = true }) {
                        PulsantePrimarioView(titolo: viewModel.inInvio ? "Invio..." : "Invia rinnovo", coloreA: 0x1E7BEA, coloreB: 0x0C4B9B)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.inInvio)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
        .navigationTitle("Rinnovo Certificato")
        .task { await viewModel.carica(token: token) }
        .fileImporter(isPresented: $mostraPicker, allowedContentTypes: tipiFileConsentiti) { result in
            importaFile(result: result, errore: $viewModel.errore) { viewModel.fileSelezionato = $0 }
        }
        .alert("Conferma rinnovo", isPresented: $mostraConferma) {
            Button("Annulla", role: .cancel) {}
            Button("Invia") {
                Task { _ = await viewModel.invia(token: token) }
            }
        } message: {
            Text("Conferma l'invio del rinnovo certificato al portale.")
        }
    }
}

struct VistaIndisponibilitaOperativa: View {
    let token: String
    @StateObject private var viewModel = IndisponibilitaOperativaViewModel()
    @State private var mostraPicker = false
    @State private var mostraConferma = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.inCaricamento {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 32)
                } else if !viewModel.errore.isEmpty && viewModel.config == nil {
                    StatoVuotoView(titolo: "Richiesta indisponibilità non disponibile", messaggio: viewModel.errore)
                } else if let config = viewModel.config {
                    CardTitoloView(titolo: config.title, sottotitolo: config.sectionTitle)
                    riepilogoCorrente(title: "Vincoli", rows: [
                        ("Validatore", config.validatorLabel),
                        ("Massimo giorni", String(config.maxDays))
                    ])
                    statoMessaggi(errore: viewModel.errore, messaggio: viewModel.messaggio)
                    if !config.introText.isEmpty { BloccoTestoView(titolo: "Istruzioni", testo: config.introText) }
                    CampoTestoOperativo(titolo: "Data inizio", placeholder: "GG/MM/AAAA", text: $viewModel.startDate)
                    CampoTestoOperativo(titolo: "Data fine", placeholder: "GG/MM/AAAA", text: $viewModel.endDate)
                    PickerOperativo(titolo: "Tipo indisponibilità", selection: $viewModel.tipoSelezionato, options: config.types)
                    PickerOperativo(titolo: "Motivo indisponibilità", selection: $viewModel.motivoSelezionato, options: config.reasons)
                    CampoAreaOperativa(titolo: "Note", text: $viewModel.note, maxLen: config.noteMaxLen)
                    SelettoreFileOperativo(
                        titolo: "Allegato",
                        file: viewModel.fileSelezionato,
                        buttonTitle: "Seleziona allegato",
                        supportText: "Max \(config.maxSizeBytes / 1024) KB · \(config.allowedExtensions.joined(separator: ", "))",
                        onPick: { mostraPicker = true },
                        onClear: { viewModel.fileSelezionato = nil }
                    )
                    if !config.legalText.isEmpty { BloccoTestoView(titolo: "Normativa", testo: config.legalText) }
                    Button(action: { mostraConferma = true }) {
                        PulsantePrimarioView(titolo: viewModel.inInvio ? "Invio..." : "Invia richiesta", coloreA: 0x1E7BEA, coloreB: 0x0C4B9B)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.inInvio)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
        .navigationTitle("Indisponibilità")
        .task { await viewModel.carica(token: token) }
        .fileImporter(isPresented: $mostraPicker, allowedContentTypes: tipiFileConsentiti) { result in
            importaFile(result: result, errore: $viewModel.errore) { viewModel.fileSelezionato = $0 }
        }
        .alert("Conferma richiesta", isPresented: $mostraConferma) {
            Button("Annulla", role: .cancel) {}
            Button("Invia") {
                Task { _ = await viewModel.invia(token: token) }
            }
        } message: {
            Text("Vuoi inviare questa richiesta di indisponibilità?")
        }
    }
}

struct VistaCongedoOperativo: View {
    let token: String
    @StateObject private var viewModel = CongedoOperativoViewModel()
    @State private var mostraPicker = false
    @State private var mostraConferma = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.inCaricamento {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 32)
                } else if !viewModel.errore.isEmpty && viewModel.config == nil {
                    StatoVuotoView(titolo: "Richiesta congedo non disponibile", messaggio: viewModel.errore)
                } else if let config = viewModel.config {
                    CardTitoloView(titolo: config.title, sottotitolo: config.sectionTitle)
                    riepilogoCorrente(title: "Vincoli", rows: [
                        ("Validatore", config.validatorLabel),
                        ("Massimo giorni", String(config.maxDays))
                    ])
                    statoMessaggi(errore: viewModel.errore, messaggio: viewModel.messaggio)
                    if !config.introText.isEmpty { BloccoTestoView(titolo: "Istruzioni", testo: config.introText) }
                    CampoTestoOperativo(titolo: "Data inizio", placeholder: "GG/MM/AAAA", text: $viewModel.startDate)
                    CampoTestoOperativo(titolo: "Data fine", placeholder: "GG/MM/AAAA", text: $viewModel.endDate)
                    PickerOperativo(titolo: "Motivo congedo", selection: $viewModel.motivoSelezionato, options: config.reasons)
                    CampoAreaOperativa(titolo: "Note", text: $viewModel.note, maxLen: config.noteMaxLen)
                    SelettoreFileOperativo(
                        titolo: "Allegato",
                        file: viewModel.fileSelezionato,
                        buttonTitle: "Seleziona allegato",
                        supportText: "Max \(config.maxSizeBytes / 1024) KB · \(config.allowedExtensions.joined(separator: ", "))",
                        onPick: { mostraPicker = true },
                        onClear: { viewModel.fileSelezionato = nil }
                    )
                    if !config.legalText.isEmpty { BloccoTestoView(titolo: "Normativa", testo: config.legalText) }
                    Button(action: { mostraConferma = true }) {
                        PulsantePrimarioView(titolo: viewModel.inInvio ? "Invio..." : "Invia congedo", coloreA: 0x1E7BEA, coloreB: 0x0C4B9B)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.inInvio)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
        .navigationTitle("Congedo")
        .task { await viewModel.carica(token: token) }
        .fileImporter(isPresented: $mostraPicker, allowedContentTypes: tipiFileConsentiti) { result in
            importaFile(result: result, errore: $viewModel.errore) { viewModel.fileSelezionato = $0 }
        }
        .alert("Conferma congedo", isPresented: $mostraConferma) {
            Button("Annulla", role: .cancel) {}
            Button("Invia") {
                Task { _ = await viewModel.invia(token: token) }
            }
        } message: {
            Text("Vuoi inviare questa richiesta di congedo?")
        }
    }
}

struct VistaPreclusioneOperativa: View {
    let token: String
    @StateObject private var viewModel = PreclusioneOperativaViewModel()
    @State private var mostraConferma = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.inCaricamento {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 32)
                } else if !viewModel.errore.isEmpty && viewModel.config == nil {
                    StatoVuotoView(titolo: "Richiesta preclusione non disponibile", messaggio: viewModel.errore)
                } else if let config = viewModel.config {
                    CardTitoloView(titolo: config.title, sottotitolo: config.sectionTitle)
                    statoMessaggi(errore: viewModel.errore, messaggio: viewModel.messaggio)
                    if !config.introText.isEmpty { BloccoTestoView(titolo: "Istruzioni", testo: config.introText) }
                    PickerOperativo(titolo: "Tipo preclusione", selection: $viewModel.tipoSelezionato, options: config.types)
                        .onChange(of: viewModel.tipoSelezionato) { _, value in
                            viewModel.aggiornaTipo(value)
                        }
                    PickerOperativo(titolo: "Durata", selection: $viewModel.opzioneSpeciale, options: config.specialCases)
                    if viewModel.opzioneSpeciale == "0" {
                        CampoTestoOperativo(titolo: "Data fine", placeholder: "GG/MM/AAAA", text: $viewModel.endDate)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filtro ricerca")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        PickerOperativo(titolo: "Campo", selection: $viewModel.filtroCampo, options: viewModel.configRicercaCorrente.fieldOptions)
                        PickerOperativo(titolo: "Ambito", selection: $viewModel.filtroScope, options: viewModel.configRicercaCorrente.scopeOptions)
                        PickerOperativo(titolo: "Risultati", selection: $viewModel.filtroRisultati, options: viewModel.configRicercaCorrente.resultOptions)
                        CampoTestoOperativo(titolo: "Ricerca", placeholder: "Comune, società, squadra o impianto", text: $viewModel.termineRicerca)
                        Button {
                            Task { await viewModel.cerca(token: token) }
                        } label: {
                            PulsanteSecondarioView(titolo: viewModel.inRicerca ? "Ricerca..." : "Cerca")
                        }
                        .buttonStyle(.plain)
                    }

                    if !viewModel.risultati.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Risultati")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            ForEach(viewModel.risultati) { result in
                                Button {
                                    viewModel.selezionaRisultato(result)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(result.label)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                        if viewModel.selezioneId == result.itemId {
                                            Text("Selezionato")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Color(hex: 0x9DD7FF))
                                        }
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.white.opacity(viewModel.selezioneId == result.itemId ? 0.10 : 0.05))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !viewModel.selezioneLabel.isEmpty {
                        BloccoTestoView(titolo: "Selezione attuale", testo: viewModel.selezioneLabel)
                    }

                    CampoAreaOperativa(titolo: "Note", text: $viewModel.note, maxLen: config.noteMaxLen)
                    if !config.legalText.isEmpty { BloccoTestoView(titolo: "Normativa", testo: config.legalText) }
                    Button(action: { mostraConferma = true }) {
                        PulsantePrimarioView(titolo: viewModel.inInvio ? "Invio..." : "Invia preclusione", coloreA: 0x1E7BEA, coloreB: 0x0C4B9B)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.inInvio)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
        .navigationTitle("Preclusioni")
        .task { await viewModel.carica(token: token) }
        .alert("Conferma preclusione", isPresented: $mostraConferma) {
            Button("Annulla", role: .cancel) {}
            Button("Invia") {
                Task { _ = await viewModel.invia(token: token) }
            }
        } message: {
            Text("Conferma l'invio della richiesta di preclusione.")
        }
    }
}

struct VistaDomandeOperative: View {
    let token: String
    @StateObject private var viewModel = DomandeOperativeViewModel()
    @State private var mostraPicker = false
    @State private var mostraConferma = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.inCaricamento {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 32)
                } else if !viewModel.errore.isEmpty && viewModel.config == nil {
                    StatoVuotoView(titolo: "Domande non disponibili", messaggio: viewModel.errore)
                } else if let config = viewModel.config {
                    CardTitoloView(titolo: config.title, sottotitolo: config.sectionTitle)
                    statoMessaggi(errore: viewModel.errore, messaggio: viewModel.messaggio)
                    if !config.introText.isEmpty { BloccoTestoView(titolo: "Istruzioni", testo: config.introText) }
                    PickerOperativo(titolo: "Domanda", selection: $viewModel.domandaSelezionata, options: config.options)
                    CampoAreaOperativa(titolo: "Note", text: $viewModel.note, maxLen: config.noteMaxLen)
                    SelettoreFileOperativo(
                        titolo: "Allegato richiesta",
                        file: viewModel.fileSelezionato,
                        buttonTitle: "Allega richiesta",
                        supportText: "Max \(config.maxSizeBytes / 1024) KB · \(config.allowedExtensions.joined(separator: ", "))",
                        onPick: { mostraPicker = true },
                        onClear: { viewModel.fileSelezionato = nil }
                    )
                    Button(action: { mostraConferma = true }) {
                        PulsantePrimarioView(titolo: viewModel.inInvio ? "Invio..." : "Invia domanda", coloreA: 0x1E7BEA, coloreB: 0x0C4B9B)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.inInvio)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
        .navigationTitle("Nuova Domanda")
        .task { await viewModel.carica(token: token) }
        .fileImporter(isPresented: $mostraPicker, allowedContentTypes: tipiFileConsentiti) { result in
            importaFile(result: result, errore: $viewModel.errore) { viewModel.fileSelezionato = $0 }
        }
        .alert("Conferma domanda", isPresented: $mostraConferma) {
            Button("Annulla", role: .cancel) {}
            Button("Invia") {
                Task { _ = await viewModel.invia(token: token) }
            }
        } message: {
            Text("Sei sicuro di voler inviare questa domanda?")
        }
    }
}

struct VistaDocumentiOperativi: View {
    let token: String
    @StateObject private var viewModel = DocumentiOperativiViewModel()
    @State private var mostraEsitoSuccesso = false
    private let apiClient = APIClient.shared

    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.inCaricamento {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                    } else if !viewModel.errore.isEmpty && viewModel.config == nil {
                        StatoVuotoView(titolo: "Gestione documenti non disponibile", messaggio: viewModel.errore)
                    } else if let config = viewModel.config {
                        DocumentiOperativiHeaderView(
                            titolo: config.title,
                            totale: viewModel.items.count,
                            mancanti: viewModel.documentiDaCaricare.count,
                            caricati: viewModel.documentiCaricati.count,
                            inAttesa: viewModel.documentiInAttesa.count
                        )

                        if !viewModel.errore.isEmpty {
                            DocumentiOperativiNoticeView(
                                titolo: "Errore",
                                testo: viewModel.errore,
                                icon: "exclamationmark.triangle.fill"
                            )
                        }

                        if viewModel.items.isEmpty {
                            StatoVuotoView(
                                titolo: "Nessun documento disponibile",
                                messaggio: "Il portale non ha restituito documenti gestibili in questo momento."
                            )
                        } else {
                            DocumentiOperativiInfoCardView(
                                testo: "Ogni riga riprende il portale: tipologia, stato, ultimo caricamento, allegato e stessa azione Carica/Modifica."
                            )

                            if !viewModel.documentiDaCaricare.isEmpty {
                                DocumentiOperativiSectionView(
                                    titolo: "Documenti da caricare",
                                    sottotitolo: "Documenti mancanti o mai caricati.",
                                    count: viewModel.documentiDaCaricare.count,
                                    tone: .missing
                                ) {
                                    ForEach(viewModel.documentiDaCaricare) { item in
                                        DocumentiOperativiRowView(
                                            item: item,
                                            hasAttachment: !item.attachmentUrl.isEmpty,
                                            attachmentProvider: { await allegatoURL(item) },
                                            onAction: { viewModel.preparaUpload(per: item) }
                                        )
                                    }
                                }
                            }

                            if !viewModel.documentiInAttesa.isEmpty {
                                DocumentiOperativiSectionView(
                                    titolo: "Documenti in attesa",
                                    sottotitolo: "Documenti inviati e in verifica sul portale.",
                                    count: viewModel.documentiInAttesa.count,
                                    tone: .pending
                                ) {
                                    ForEach(viewModel.documentiInAttesa) { item in
                                        DocumentiOperativiRowView(
                                            item: item,
                                            hasAttachment: !item.attachmentUrl.isEmpty,
                                            attachmentProvider: { await allegatoURL(item) },
                                            onAction: { viewModel.preparaUpload(per: item) }
                                        )
                                    }
                                }
                            }

                            if !viewModel.documentiCaricati.isEmpty {
                                DocumentiOperativiSectionView(
                                    titolo: "Documenti caricati",
                                    sottotitolo: "Documenti già presenti e aggiornabili con lo stesso flusso.",
                                    count: viewModel.documentiCaricati.count,
                                    tone: .uploaded
                                ) {
                                    ForEach(viewModel.documentiCaricati) { item in
                                        DocumentiOperativiRowView(
                                            item: item,
                                            hasAttachment: !item.attachmentUrl.isEmpty,
                                            attachmentProvider: { await allegatoURL(item) },
                                            onAction: { viewModel.preparaUpload(per: item) }
                                        )
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
        .navigationTitle("Documenti")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.carica(token: token) }
        .sheet(item: $viewModel.documentoAttivo) { documento in
            if let config = viewModel.config {
                DocumentiOperativiUploadSheetView(
                    documento: documento,
                    maxSizeBytes: config.maxSizeBytes,
                    allowedExtensions: config.allowedExtensions,
                    fileSelezionato: viewModel.fileSelezionato,
                    inInvio: viewModel.inInvio,
                    errore: viewModel.errore,
                    onPick: { },
                    onSelectFile: { file in
                        guard file.fileName.lowercased().hasSuffix(".pdf") || file.mimeType == "application/pdf" else {
                            viewModel.errore = "Puoi caricare solo documenti PDF."
                            return
                        }
                        viewModel.errore = ""
                        viewModel.fileSelezionato = file
                    },
                    onImportError: { messaggio in
                        viewModel.errore = messaggio
                    },
                    onClear: { viewModel.fileSelezionato = nil },
                    onClose: { viewModel.chiudiUpload() },
                    onSubmit: {
                        Task {
                            let esito = await viewModel.invia(token: token)
                            if esito {
                                mostraEsitoSuccesso = true
                            }
                        }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .alert("Operazione conclusa con successo", isPresented: $mostraEsitoSuccesso) {
            Button("Ok", role: .cancel) {
                viewModel.messaggio = ""
            }
        } message: {
            Text(viewModel.messaggio.isEmpty ? "Documento caricato correttamente." : viewModel.messaggio)
        }
    }

    private func allegatoURL(_ item: DocumentoConfigItemDTO) async -> URL? {
        guard !item.attachmentUrl.isEmpty else { return nil }
        return await apiClient.urlDownloadPortale(token: token, remoteURL: item.attachmentUrl, suggestedName: item.title)
    }
}

private struct DocumentiOperativiHeaderView: View {
    let titolo: String
    let totale: Int
    let mancanti: Int
    let caricati: Int
    let inAttesa: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DocumentiOperativiPalette.accentSoft)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DocumentiOperativiPalette.inlineSurface)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(titolo)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Vista operativa pulita: apri la riga giusta, controlla lo stato e carica o modifica il PDF dal tuo iPhone.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DocumentiOperativiPalette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                DocumentiOperativiBadgeView(titolo: "Totali", value: "\(totale)")
                DocumentiOperativiBadgeView(titolo: "Da caricare", value: "\(mancanti)")
                DocumentiOperativiBadgeView(titolo: "In attesa", value: "\(inAttesa)")
                DocumentiOperativiBadgeView(titolo: "Caricati", value: "\(caricati)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(DocumentiOperativiPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(DocumentiOperativiPalette.accent.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct DocumentiOperativiBadgeView: View {
    let titolo: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titolo.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DocumentiOperativiPalette.accentSoft)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DocumentiOperativiPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DocumentiOperativiPalette.accent.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct DocumentiOperativiInfoCardView: View {
    let testo: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DocumentiOperativiPalette.accentSoft)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(DocumentiOperativiPalette.inlineSurface)
                )

            Text(testo)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DocumentiOperativiPalette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DocumentiOperativiPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct DocumentiOperativiNoticeView: View {
    let titolo: String
    let testo: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: 0xF3B24F))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color(hex: 0xF3B24F).opacity(0.18))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(titolo)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(testo)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DocumentiOperativiPalette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DocumentiOperativiPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: 0xF3B24F).opacity(0.35), lineWidth: 1)
        )
    }
}

private enum DocumentiOperativiSectionTone {
    case missing
    case pending
    case uploaded

    var color: Color {
        switch self {
        case .missing:
            return DocumentiOperativiPalette.textMuted
        case .pending:
            return DocumentiOperativiPalette.pending
        case .uploaded:
            return DocumentiOperativiPalette.accent
        }
    }
}

private struct DocumentiOperativiSectionView<Content: View>: View {
    let titolo: String
    let sottotitolo: String
    let count: Int
    let tone: DocumentiOperativiSectionTone
    let content: Content

    init(
        titolo: String,
        sottotitolo: String,
        count: Int,
        tone: DocumentiOperativiSectionTone,
        @ViewBuilder content: () -> Content
    ) {
        self.titolo = titolo
        self.sottotitolo = sottotitolo
        self.count = count
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titolo)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(sottotitolo)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DocumentiOperativiPalette.textMuted)
                }

                Spacer()

                Text("\(count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(tone.color.opacity(0.18))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(tone.color.opacity(0.45), lineWidth: 1)
                    )
            }

            VStack(spacing: 12) {
                content
            }
        }
    }
}

private struct DocumentiOperativiRowView: View {
    let item: DocumentoConfigItemDTO
    // La presenza dell'allegato e la sua URL sono ora separate: la URL viene
    // costruita solo al tocco, con un ticket monouso.
    let hasAttachment: Bool
    let attachmentProvider: () async -> URL?
    let onAction: () -> Void

    private var statusColor: Color {
        switch item.statusCode {
        case "uploaded":
            return DocumentiOperativiPalette.uploaded
        case "pending":
            return DocumentiOperativiPalette.pending
        default:
            return DocumentiOperativiPalette.missing
        }
    }

    private var attachmentText: String {
        hasAttachment ? "Disponibile" : "Non presente"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(statusColor.opacity(0.18))
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(item.actionLabel == "Modifica" ? "Documento già presente sul portale." : "Documento da caricare sul portale.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DocumentiOperativiPalette.textMuted)
                        }

                        Spacer(minLength: 8)

                        DocumentiOperativiStatusBadgeView(
                            label: item.statusLabel.isEmpty ? "Senza stato" : item.statusLabel,
                            color: statusColor
                        )
                    }

                    HStack(spacing: 10) {
                        DocumentiOperativiDataCellView(
                            titolo: "Ultimo caricamento",
                            valore: item.uploadedAt.isEmpty ? "Non disponibile" : item.uploadedAt
                        )
                        DocumentiOperativiDataCellView(
                            titolo: "Allegato",
                            valore: attachmentText
                        )
                    }

                    HStack(spacing: 10) {
                        Button(action: onAction) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text(item.actionLabel)
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(DocumentiOperativiPalette.accent)
                            )
                        }
                        .buttonStyle(.plain)

                        if hasAttachment {
                            TicketedDownloadLink {
                                await attachmentProvider()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "paperclip")
                                    Text("Apri allegato")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(DocumentiOperativiPalette.inlineSurface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DocumentiOperativiPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct DocumentiOperativiStatusBadgeView: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.20))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(color.opacity(0.45), lineWidth: 1)
            )
    }
}

private struct DocumentiOperativiDataCellView: View {
    let titolo: String
    let valore: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titolo)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DocumentiOperativiPalette.textMuted)
            Text(valore)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DocumentiOperativiPalette.inlineSurface)
        )
    }
}

private struct DocumentiOperativiUploadSheetView: View {
    let documento: DocumentoConfigItemDTO
    let maxSizeBytes: Int
    let allowedExtensions: [String]
    let fileSelezionato: FileSelezionatoApp?
    let inInvio: Bool
    let errore: String
    let onPick: () -> Void
    let onSelectFile: (FileSelezionatoApp) -> Void
    let onImportError: (String) -> Void
    let onClear: () -> Void
    let onClose: () -> Void
    let onSubmit: () -> Void
    @State private var mostraPicker = false

    private var specificheUpload: String {
        let dimensione = ByteCountFormatter.string(fromByteCount: Int64(maxSizeBytes), countStyle: .file)
        let estensioni = allowedExtensions.joined(separator: ", ").uppercased()
        return "Formato: \(estensioni) • Dimensione massima: \(dimensione)"
    }

    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    DocumentiOperativiUploadHeroView(
                        documento: documento,
                        onClose: onClose
                    )

                    DocumentiOperativiUploadSummaryCardView(
                        titolo: documento.title,
                        azione: documento.actionLabel,
                        specificheUpload: specificheUpload
                    )

                    DocumentiOperativiFilePickerCardView(
                        fileSelezionato: fileSelezionato,
                        supportText: specificheUpload,
                        onPick: {
                            onPick()
                            mostraPicker = true
                        },
                        onClear: onClear
                    )

                    if !errore.isEmpty {
                        DocumentiOperativiNoticeView(
                            titolo: "Errore",
                            testo: errore,
                            icon: "exclamationmark.triangle.fill"
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 140)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button(action: onClose) {
                    PulsanteSecondarioView(titolo: "Annulla")
                }
                .buttonStyle(.plain)

                Button(action: onSubmit) {
                    PulsantePrimarioView(
                        titolo: inInvio ? "Caricamento..." : documento.actionLabel,
                        coloreA: 0x4EA0FF,
                        coloreB: 0x2D6EE8
                    )
                }
                .buttonStyle(.plain)
                .disabled(fileSelezionato == nil || inInvio)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 18)
            .background(.ultraThinMaterial)
        }
        .fileImporter(isPresented: $mostraPicker, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                let started = url.startAccessingSecurityScopedResource()
                defer {
                    if started {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let data = try Data(contentsOf: url)
                    let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                    onSelectFile(FileSelezionatoApp(fileName: url.lastPathComponent, mimeType: mime, data: data))
                } catch {
                    onImportError("Non riesco a leggere il PDF selezionato dal telefono.")
                }
            case .failure(let error):
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
                    return
                }
                onImportError("Non riesco ad aprire il selettore file in questo momento.")
            }
        }
        .interactiveDismissDisabled(inInvio)
    }
}

private struct DocumentiOperativiUploadHeroView: View {
    let documento: DocumentoConfigItemDTO
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DocumentiOperativiPalette.inlineSurface)
                    .frame(width: 56, height: 56)

                Image(systemName: "square.and.arrow.up.on.square.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DocumentiOperativiPalette.accentSoft)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(documento.actionLabel)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Scelgo un PDF da File su iPhone e lo invio direttamente per questa tipologia documento.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DocumentiOperativiPalette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(DocumentiOperativiPalette.inlineSurface)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct DocumentiOperativiUploadSummaryCardView: View {
    let titolo: String
    let azione: String
    let specificheUpload: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(azione.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(DocumentiOperativiPalette.accent.opacity(0.22))
                    )

                Text("PDF")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(DocumentiOperativiPalette.inlineSurface)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Tipologia documento")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DocumentiOperativiPalette.textMuted)

                Text(titolo)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(specificheUpload)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DocumentiOperativiPalette.textMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DocumentiOperativiPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DocumentiOperativiPalette.accent.opacity(0.28), lineWidth: 1)
        )
    }
}

private struct DocumentiOperativiFilePickerCardView: View {
    let fileSelezionato: FileSelezionatoApp?
    let supportText: String
    let onPick: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("File PDF")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.82))
                Spacer()
                Text("Da File su iPhone")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DocumentiOperativiPalette.textMuted)
            }

            if let fileSelezionato {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DocumentiOperativiPalette.inlineSurface)
                            .frame(width: 52, height: 52)

                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(DocumentiOperativiPalette.accentSoft)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("PDF selezionato")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(fileSelezionato.fileName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Dimensione: \(ByteCountFormatter.string(fromByteCount: Int64(fileSelezionato.data.count), countStyle: .file))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DocumentiOperativiPalette.textMuted)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(DocumentiOperativiPalette.inlineSurface)
                )

                HStack(spacing: 10) {
                    Button(action: onPick) {
                        Label("Cambia PDF", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(DocumentiOperativiPalette.accent)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onClear) {
                        Label("Rimuovi", systemImage: "trash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(action: onPick) {
                    VStack(spacing: 14) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(DocumentiOperativiPalette.accentSoft)
                        Text("Scegli PDF da File")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Apro il selettore File di iPhone. Da lì puoi scegliere il PDF che vuoi caricare, senza permessi speciali del portale.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DocumentiOperativiPalette.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(DocumentiOperativiPalette.inlineSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(DocumentiOperativiPalette.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [7, 5]))
                    )
                }
                .buttonStyle(.plain)
            }

            Text(supportText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DocumentiOperativiPalette.textMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DocumentiOperativiPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct DocumentiOperativiUploadFieldView: View {
    let titolo: String
    let valore: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titolo)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DocumentiOperativiPalette.textMuted)
            Text(valore)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(DocumentiOperativiPalette.inlineSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
    }
}

struct VistaAccountOperativo: View {
    let token: String
    let onRequireLogout: () -> Void
    @StateObject private var viewModel = AccountOperativoViewModel()
    @State private var mostraConferma = false

    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if viewModel.inCaricamento {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                    } else if !viewModel.errore.isEmpty && viewModel.config == nil {
                        StatoVuotoView(titolo: "Account non disponibile", messaggio: viewModel.errore)
                    } else if let config = viewModel.config {
                        AccountOperativoHeaderView(
                            titolo: config.title,
                            sottotitolo: config.sectionTitle
                        )

                        statoMessaggi(errore: viewModel.errore, messaggio: viewModel.messaggio)

                        AccountOperativoPanoramicaView(
                            richiedeNuovoLogin: viewModel.richiedeNuovoLogin,
                            totalRules: config.rules.count
                        )

                        if !config.rules.isEmpty {
                            AccountOperativoRegoleView(rules: config.rules)
                        }

                        AccountOperativoFormCardView(
                            oldPassword: $viewModel.oldPassword,
                            newPassword: $viewModel.newPassword,
                            confirmPassword: $viewModel.confirmPassword
                        )

                        Button(action: { mostraConferma = true }) {
                            PulsantePrimarioView(
                                titolo: viewModel.inInvio ? "Aggiornamento..." : config.submitLabel,
                                coloreA: 0x1E7BEA,
                                coloreB: 0x0C4B9B
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.puoInviare)

                        if viewModel.richiedeNuovoLogin {
                            AccountOperativoReloginCardView(action: onRequireLogout)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Account")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.carica(token: token) }
        .alert("Conferma cambio password", isPresented: $mostraConferma) {
            Button("Annulla", role: .cancel) {}
            Button("Conferma") {
                Task { _ = await viewModel.invia(token: token) }
            }
        } message: {
            Text("Vuoi cambiare la password e chiudere la sessione corrente?")
        }
    }
}

private struct AccountOperativoHeaderView: View {
    let titolo: String
    let sottotitolo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 56, height: 56)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x9EC8FF))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(titolo)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Gestisci password e sicurezza del tuo accesso in modo chiaro e ordinato.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(sottotitolo)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: 0xD7E8FF).opacity(0.90))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x1778D8), Color(hex: 0x14386E)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct AccountOperativoPanoramicaView: View {
    let richiedeNuovoLogin: Bool
    let totalRules: Int

    var body: some View {
        HStack(spacing: 12) {
            AccountOperativoStatCardView(
                icon: "checkmark.shield",
                title: "Stato",
                value: richiedeNuovoLogin ? "Aggiornato" : "Protetto",
                accentColor: richiedeNuovoLogin ? Color(hex: 0x58D39B) : Color(hex: 0x9EC8FF)
            )

            AccountOperativoStatCardView(
                icon: "text.badge.checkmark",
                title: "Regole",
                value: "\(totalRules)",
                accentColor: Color(hex: 0x9EC8FF)
            )
        }
    }
}

private struct AccountOperativoStatCardView: View {
    let icon: String
    let title: String
    let value: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accentColor)

            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.56))

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct AccountOperativoRegoleView: View {
    let rules: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Regole Password")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Prima di confermare, controlla che la nuova password rispetti questi requisiti.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: 0x67D7A2))
                            .padding(.top, 2)

                        Text(rule)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.90))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct AccountOperativoFormCardView: View {
    @Binding var oldPassword: String
    @Binding var newPassword: String
    @Binding var confirmPassword: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Aggiorna Password")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Compila i campi in ordine. Dopo il cambio password potrebbe essere richiesto un nuovo accesso.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)

            CampoTestoOperativo(
                titolo: "Password attuale",
                placeholder: "Inserisci la password attuale",
                text: $oldPassword,
                secure: true
            )
            CampoTestoOperativo(
                titolo: "Nuova password",
                placeholder: "Inserisci la nuova password",
                text: $newPassword,
                secure: true
            )
            CampoTestoOperativo(
                titolo: "Conferma nuova password",
                placeholder: "Ripeti la nuova password",
                text: $confirmPassword,
                secure: true
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct AccountOperativoReloginCardView: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: 0x63D9A6))

                Text("Nuovo accesso richiesto")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text("Per applicare in modo corretto le nuove credenziali, chiudi la sessione e accedi di nuovo.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                PulsanteSecondarioView(titolo: "Esci e rifai login")
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color(hex: 0x63D9A6).opacity(0.24), lineWidth: 1)
        )
    }
}

struct VistaEventiOperativi: View {
    let token: String
    @StateObject private var viewModel = EventiOperativiViewModel()
    @ObservedObject private var eventiNotifier = EventiNotificationStore.shared
    @State private var evidenziatiNuovi: Set<String> = []
    private let apiClient = APIClient.shared

    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    EventiHeaderView(
                        totale: viewModel.items.count,
                        nuovi: evidenziatiNuovi.intersection(Set(viewModel.items.map(\.eventId))).count
                    )

                    statoMessaggi(errore: viewModel.errore, messaggio: viewModel.messaggio)

                    if viewModel.inCaricamento {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                    } else if viewModel.items.isEmpty {
                        StatoVuotoView(titolo: "Nessun evento", messaggio: "Non risultano eventi disponibili.")
                    } else {
                        LazyVStack(spacing: 18) {
                            ForEach(viewModel.items) { item in
                                EventoOperativoCardView(
                                    item: item,
                                    isNew: evidenziatiNuovi.contains(item.eventId),
                                    hasAllegato: !item.attachmentUrl.isEmpty,
                                    allegatoProvider: { await allegatoEventoURL(item) },
                                    onAccept: {
                                        Task {
                                            await viewModel.accetta(token: token, eventId: item.eventId)
                                            eventiNotifier.markItemsAsRead(viewModel.items)
                                            evidenziatiNuovi.remove(item.eventId)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Eventi")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await caricaEventi()
        }
        .refreshable {
            await caricaEventi()
        }
    }

    private func allegatoEventoURL(_ item: EventoItemDTO) async -> URL? {
        guard !item.attachmentUrl.isEmpty else { return nil }
        return await apiClient.urlDownloadAllegatoEvento(token: token, eventId: item.eventId)
    }

    private func caricaEventi() async {
        let nuoviPrimaDellaLettura = eventiNotifier.unreadEventIDs
        await viewModel.carica(token: token)
        evidenziatiNuovi.formUnion(nuoviPrimaDellaLettura)
        eventiNotifier.markItemsAsRead(viewModel.items)
    }
}

private struct EventiHeaderView: View {
    let totale: Int
    let nuovi: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 54, height: 54)

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x9EC8FF))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Elenco Eventi")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Convocazioni aggiornate e stato lettura sempre allineato.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
            }

            HStack(spacing: 10) {
                EventiStatPillView(label: "Totali", value: "\(totale)")
                EventiStatPillView(label: "Nuovi", value: "\(nuovi)")
                EventiStatPillView(label: "Stato", value: nuovi > 0 ? "Attivi" : "Letti")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x1778D8), Color(hex: 0x14386E)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct EventoOperativoCardView: View {
    let item: EventoItemDTO
    let isNew: Bool
    let hasAllegato: Bool
    let allegatoProvider: () async -> URL?
    let onAccept: () -> Void

    @State private var mostraNotaCompleta = false

    private var titoloEvento: String {
        eventoTestoPulito(item.eventType.isEmpty ? "Evento" : item.eventType)
    }

    private var luogoPulito: String {
        eventoTestoPulito(item.place)
    }

    private var notaPulita: String {
        eventoTestoPulito(item.note)
    }

    private var dataLabel: String {
        [eventoTestoPulito(item.startDate), eventoTestoPulito(item.startTime)]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var fineLabel: String {
        [eventoTestoPulito(item.endDate), eventoTestoPulito(item.endTime)]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var statoColor: Color {
        let status = item.statusLabel.lowercased()
        if item.canAccept { return Color(hex: 0xFFB24A) }
        if status.contains("accett") { return Color(hex: 0x54D38A) }
        if status.contains("rifiut") { return Color(hex: 0xFF6A6A) }
        return Color(hex: 0x7FA4D6)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if isNew {
                            EventiBadgeView(
                                titolo: "NUOVO",
                                accentColor: Color(hex: 0x63D9A6)
                            )
                        }

                        EventiBadgeView(
                            titolo: eventoTestoPulito(item.statusLabel.isEmpty ? "Evento" : item.statusLabel),
                            accentColor: statoColor
                        )
                    }

                    Text(titoloEvento)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                if item.canAccept {
                    Button(action: onAccept) {
                        Text(eventoTestoPulito(item.actionLabel.isEmpty ? "Accetta" : item.actionLabel))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(hex: 0x2A8E55).opacity(0.92))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                EventiMetaChipView(icon: "calendar", title: "Inizio", value: dataLabel)
                EventiMetaChipView(icon: "clock.arrow.circlepath", title: "Fine", value: fineLabel)
            }

            if !luogoPulito.isEmpty {
                EventiDettaglioBloccoView(
                    icon: "mappin.and.ellipse",
                    titolo: "Luogo",
                    testo: luogoPulito
                )
            }

            if !notaPulita.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    EventiDettaglioBloccoView(
                        icon: "text.alignleft",
                        titolo: "Note",
                        testo: notaPulita,
                        lineLimit: mostraNotaCompleta ? nil : 5
                    )

                    if notaPulita.count > 220 {
                        Button(mostraNotaCompleta ? "Mostra meno" : "Mostra tutto") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mostraNotaCompleta.toggle()
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: 0x9EC8FF))
                    }
                }
            }

            HStack(spacing: 12) {
                if hasAllegato {
                    TicketedDownloadLink {
                        await allegatoProvider()
                    } label: {
                        Label("Apri allegato", systemImage: "paperclip")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x12345F).opacity(0.94),
                            Color(hex: 0x10264A).opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(isNew ? Color(hex: 0x63D9A6).opacity(0.30) : Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct EventiBadgeView: View {
    let titolo: String
    let accentColor: Color

    var body: some View {
        Text(titolo)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(accentColor.opacity(0.22))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accentColor.opacity(0.36), lineWidth: 1)
            )
    }
}

private struct EventiStatPillView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(hex: 0xCFE4FF).opacity(0.82))

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }
}

private struct EventiMetaChipView: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.48))

            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: 0x9EC8FF))

                Text(value.isEmpty ? "-" : value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct EventiDettaglioBloccoView: View {
    let icon: String
    let titolo: String
    let testo: String
    var lineLimit: Int? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: 0x2E7BE0).opacity(0.18))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x9EC8FF))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(titolo.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.46))

                Text(testo)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(lineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private func eventoTestoPulito(_ raw: String) -> String {
    var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return "" }

    if let encoded = cleaned.data(using: .isoLatin1),
       let decoded = String(data: encoded, encoding: .utf8),
       !decoded.isEmpty {
        cleaned = decoded
    }

    cleaned = cleaned.replacingOccurrences(of: "\u{00A0}", with: " ")
    cleaned = cleaned.replacingOccurrences(of: "Â", with: "")

    while cleaned.contains("  ") {
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
    }

    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
}

private struct CampoTestoOperativo: View {
    private enum CampoAttivo: Hashable {
        case protetto
        case visibile
    }

    let titolo: String
    let placeholder: String
    @Binding var text: String
    var secure: Bool = false
    @State private var mostraTestoSensibile = false
    @FocusState private var campoAttivo: CampoAttivo?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titolo)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
            HStack(spacing: 10) {
                Group {
                    if usaCampoProtetto {
                        SecureField(placeholder, text: $text)
                            .focused($campoAttivo, equals: .protetto)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    } else {
                        TextField(placeholder, text: $text)
                            .focused($campoAttivo, equals: .visibile)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)

                if secure {
                    // Tengo il toggle dentro questo componente, così password in chiaro e protetta
                    // condividono sfondo, padding e focus senza duplicare un secondo campo custom.
                    Button(action: alternaVisibilitaPassword) {
                        Image(systemName: mostraTestoSensibile ? "eye.slash" : "eye")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.64))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                }
            }
            .background(sfondoCampo)
            .overlay(bordoCampo)
        }
    }

    private var sfondoCampo: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.06))
    }

    private var bordoCampo: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.white.opacity(0.10), lineWidth: 1)
    }

    private var usaCampoProtetto: Bool {
        secure && !mostraTestoSensibile
    }

    private func alternaVisibilitaPassword() {
        mostraTestoSensibile.toggle()
        let destinazione: CampoAttivo = usaCampoProtetto ? .protetto : .visibile
        Task { @MainActor in
            campoAttivo = destinazione
        }
    }
}

private struct CampoAreaOperativa: View {
    let titolo: String
    @Binding var text: String
    let maxLen: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(titolo)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.82))
                Spacer()
                Text("\(text.count)/\(maxLen)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .frame(minHeight: 120)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
    }
}

private struct PickerOperativo: View {
    let titolo: String
    @Binding var selection: String
    let options: [OpzioneModuloDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titolo)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
            Picker(titolo, selection: $selection) {
                ForEach(options) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }
}

private struct SelettoreFileOperativo: View {
    let titolo: String
    let file: FileSelezionatoApp?
    let buttonTitle: String
    let supportText: String
    let onPick: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titolo)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))

            if let file {
                VStack(alignment: .leading, spacing: 6) {
                    Text(file.fileName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Dimensione: \(ByteCountFormatter.string(fromByteCount: Int64(file.data.count), countStyle: .file))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            }

            HStack(spacing: 10) {
                Button(buttonTitle, action: onPick)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: 0x1E7BEA))
                if file != nil {
                    Button("Rimuovi", role: .destructive, action: onClear)
                        .buttonStyle(.bordered)
                }
            }

            if !supportText.isEmpty {
                Text(supportText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
    }
}

private struct PulsantePrimarioView: View {
    let titolo: String
    let coloreA: UInt
    let coloreB: UInt

    var body: some View {
        Text(titolo)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: coloreA), Color(hex: coloreB)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
    }
}

private struct PulsanteSecondarioView: View {
    let titolo: String

    var body: some View {
        Text(titolo)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

@ViewBuilder
private func statoMessaggi(errore: String, messaggio: String) -> some View {
    if !messaggio.isEmpty {
        BloccoTestoView(titolo: "Esito", testo: messaggio)
    }
    if !errore.isEmpty {
        BloccoTestoView(titolo: "Errore", testo: errore)
    }
}

private func riepilogoCorrente(title: String, rows: [(String, String)]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(title)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)

        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            if !row.1.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.0)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                    Text(row.1)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.05))
    )
    .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.10), lineWidth: 1)
    )
}

private let tipiFileConsentiti: [UTType] = [
    .pdf,
    .image,
    .content,
    .item,
]

private func importaFile(
    result: Result<URL, Error>,
    errore: Binding<String>,
    onSuccess: (FileSelezionatoApp) -> Void
) {
    switch result {
    case .success(let url):
        let started = url.startAccessingSecurityScopedResource()
        defer {
            if started {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            onSuccess(FileSelezionatoApp(fileName: url.lastPathComponent, mimeType: mime, data: data))
        } catch {
            errore.wrappedValue = "Non riesco a leggere il file selezionato."
        }
    case .failure(let error):
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
            return
        }
        errore.wrappedValue = "Selezione file non valida."
    }
}
