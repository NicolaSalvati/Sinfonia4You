//
//  RefertoAssistenteViews.swift
//  Sinfonia4You
//
//  Viste dedicate al flusso referto degli assistenti.
//

import SwiftUI

struct RefertoSceltaSegnalazioneView: View {
    let titolo: String
    let sottotitolo: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isSelected ? Color(hex: 0x66D48C) : Color.white.opacity(0.42))

                VStack(alignment: .leading, spacing: 6) {
                    Text(titolo)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(sottotitolo)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Color(hex: 0x1C4C89).opacity(0.58) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? Color(hex: 0x6FB8FF) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RefertoEsitoInviatoView: View {
    @Environment(\.dismiss) private var dismiss
    let dettaglio: DettaglioRefertoDTO

    private var esitoTitolo: String {
        dettaglio.segnalazioneValue == "2" ? "SEGNALA EVENTO" : "NIENTE DA SEGNALARE"
    }

    private var ufficialeAssistente: [String: String]? {
        let ruolo = testoRipulitoPerUI(dettaglio.item.activity).uppercased()
        if let exact = dettaglio.officials.first(where: {
            testoRipulitoPerUI($0["Ruolo"] ?? "").uppercased() == ruolo
        }) {
            return exact
        }
        return dettaglio.officials.first(where: {
            testoRipulitoPerUI($0["Ruolo"] ?? "").uppercased().hasPrefix("AA")
        }) ?? dettaglio.officials.first
    }

    private var titoloAssistente: String {
        let activity = testoRipulitoPerUI(dettaglio.item.activity).uppercased()
        if activity == "AA1" {
            return "Assistente dell'arbitro n°1"
        }
        if activity == "AA2" {
            return "Assistente dell'arbitro n°2"
        }
        return dettaglio.reportTitle.isEmpty ? "Rapporto Assistente" : dettaglio.reportTitle
    }

    private var noteReadOnlyText: String {
        let clean = testoRipulitoPerUI(dettaglio.noteText)
        if !clean.isEmpty {
            return clean
        }
        if dettaglio.roleKind == "assistant" && dettaglio.segnalazioneValue != "2" {
            return "NIENTE DA SEGNALARE"
        }
        let placeholder = testoRipulitoPerUI(dettaglio.notePlaceholder)
        return placeholder.isEmpty ? "Nessuna nota inserita." : placeholder
    }

    var body: some View {
        if dettaglio.roleKind == "assistant" {
            assistantBody
        } else {
            genericBody
        }
    }

    private var genericBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Referto inviato")
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            BloccoTestoView(
                titolo: dettaglio.segnalazioneTitle.isEmpty ? "Esito" : dettaglio.segnalazioneTitle,
                testo: esitoTitolo
            )

            if !dettaglio.noteText.isEmpty {
                BloccoTestoView(
                    titolo: dettaglio.noteTitle.isEmpty ? "Testo inviato" : dettaglio.noteTitle,
                    testo: dettaglio.noteText
                )
            }
        }
    }

    private var assistantBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(titoloAssistente)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            assistantConsultazioneCard

            if let ufficialeAssistente {
                assistantIdentityGrid(ufficialeAssistente)
            }

            BloccoTestoView(
                titolo: dettaglio.segnalazioneTitle.isEmpty ? "Esito Segnalazione" : dettaglio.segnalazioneTitle,
                testo: esitoTitolo
            )

            assistantNoteCard
            assistantActionButtons
        }
    }

    private var assistantConsultazioneCard: some View {
        BloccoTestoView(
            titolo: "Consultazione",
            testo: "Rapporto già inviato al direttore di gara. Questa schermata è in sola lettura."
        )
    }

    private var assistantNoteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !dettaglio.noteRemaining.isEmpty {
                Text(dettaglio.noteRemaining)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFFD48B))
            }

            BloccoTestoView(
                titolo: dettaglio.noteTitle.isEmpty ? "Testo della Segnalazione" : dettaglio.noteTitle,
                testo: noteReadOnlyText
            )
        }
    }

    private var assistantActionButtons: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.backward.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Esci")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x2C7BE5), Color(hex: 0x1959AD)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)

            if dettaglio.canPrint {
                HStack(spacing: 10) {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Stampa")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(Color.white.opacity(0.62))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
            }
        }
    }

    private func assistantIdentityGrid(_ ufficialeAssistente: [String: String]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            RefertoAnteprimaCampoView(
                titolo: "Nome",
                valore: testoRipulitoPerUI(ufficialeAssistente["Nome"] ?? "")
            )
            RefertoAnteprimaCampoView(
                titolo: "Cognome",
                valore: testoRipulitoPerUI(ufficialeAssistente["Cognome"] ?? "")
            )
            RefertoAnteprimaCampoView(
                titolo: "Sezione",
                valore: testoRipulitoPerUI(ufficialeAssistente["Sezione"] ?? "")
            )
        }
    }
}

struct RefertoSintesiRapportoAssistenteView: View {
    let segnalazioneValue: String
    let noteText: String

    private var isEvento: Bool {
        segnalazioneValue == "2"
    }

    private var esito: String {
        isEvento ? "SEGNALA EVENTO" : "NIENTE DA SEGNALARE"
    }

    private var accent: Color {
        isEvento ? Color(hex: 0xF2B339) : Color(hex: 0x35C877)
    }

    private var testoSegnalazione: String {
        if isEvento {
            let clean = testoRipulitoPerUI(noteText)
            return clean.isEmpty ? "Nessun testo inserito." : clean
        }
        return "NIENTE DA SEGNALARE"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rapporto Assistente")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Anteprima rapida della segnalazione che sarà letta dal direttore di gara.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.70))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)
                    Text(esito)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(accent.opacity(0.22))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(accent.opacity(0.62), lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Testo della segnalazione")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.62))

                Text(testoSegnalazione)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: 0x0A1F41).opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

struct RefertoPopupSalvataggioAssistenteView: View {
    let dettaglio: DettaglioRefertoDTO
    let segnalazioneValue: String
    let noteText: String
    let onChiudi: () -> Void
    let onModifica: () -> Void
    let onEsci: () -> Void

    private var ufficialeCorrente: [String: String]? {
        let targetRole = testoRipulitoPerUI(dettaglio.item.activity).uppercased()
        if let directMatch = dettaglio.officials.first(where: {
            testoRipulitoPerUI($0["Ruolo"] ?? "").uppercased() == targetRole
        }) {
            return directMatch
        }

        return dettaglio.officials.first(where: {
            testoRipulitoPerUI($0["Ruolo"] ?? "").uppercased().hasPrefix("AA")
        }) ?? dettaglio.officials.first
    }

    private var titoloAssistente: String {
        let activity = testoRipulitoPerUI(dettaglio.item.activity).uppercased()
        if activity == "AA1" {
            return "Assistente dell'arbitro n°1"
        }
        if activity == "AA2" {
            return "Assistente dell'arbitro n°2"
        }
        let reportTitle = testoRipulitoPerUI(dettaglio.reportTitle)
        return reportTitle.isEmpty ? "Assistente dell'arbitro" : reportTitle
    }

    private var testoSegnalazione: String {
        if segnalazioneValue == "2" {
            let clean = testoRipulitoPerUI(noteText)
            return clean.isEmpty ? "Nessun testo inserito." : clean
        }
        return "NIENTE DA SEGNALARE"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView(showsIndicators: false) {
                contentView
                    .padding(18)
            }
            .frame(maxHeight: 620)
            .background(Color.clear)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x0F274B).opacity(0.98),
                            Color(hex: 0x081735).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.32), radius: 26, y: 14)
    }

    private var headerView: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Anteprima Referto")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Il rapporto e pronto per essere inviato all'arbitro.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.68))
            }

            Spacer(minLength: 0)

            Button(action: onChiudi) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: 0x143C78).opacity(0.96),
                    Color(hex: 0x0E284E).opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(titoloAssistente)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            introBannerView
            ufficialeSectionView
            segnalazioneSectionView
            actionButtonsView
        }
    }

    private var introBannerView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: 0x9FD1FF))
                .padding(.top, 1)

            Text("Anteprima della segnalazione inviata all'arbitro.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: 0xDCEEFF))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0x173A73).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: 0x6EA8FF).opacity(0.28), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var ufficialeSectionView: some View {
        if let ufficialeCorrente {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ufficiale di gara")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xA8D0FF))

                VStack(spacing: 10) {
                    previewFieldRow(
                        titolo: "Nome",
                        valore: testoRipulitoPerUI(ufficialeCorrente["Nome"] ?? "")
                    )
                    previewFieldRow(
                        titolo: "Cognome",
                        valore: testoRipulitoPerUI(ufficialeCorrente["Cognome"] ?? "")
                    )
                    previewFieldRow(
                        titolo: "Sezione",
                        valore: testoRipulitoPerUI(ufficialeCorrente["Sezione"] ?? "")
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
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var segnalazioneSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Testo della Segnalazione")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xA8D0FF))
                Spacer(minLength: 0)
            }

            Text(testoSegnalazione)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var actionButtonsView: some View {
        HStack(spacing: 10) {
            RefertoFooterButton(
                title: "Modifica",
                systemIcon: "pencil",
                tint: Color.white.opacity(0.10)
            ) {
                onModifica()
            }

            RefertoFooterButton(
                title: "Esci",
                systemIcon: "arrow.uturn.backward.circle.fill",
                tint: Color(hex: 0x2E7BE0)
            ) {
                onEsci()
            }
        }
    }

    private func previewFieldRow(titolo: String, valore: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(titolo)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: 0x9BC7FF))
                .textCase(.uppercase)
                .frame(width: 88, alignment: .leading)

            Text(valore.isEmpty ? "-" : valore)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
