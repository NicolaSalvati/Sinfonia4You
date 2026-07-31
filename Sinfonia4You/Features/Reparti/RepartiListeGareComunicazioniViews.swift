import SwiftUI

private enum AccettazioneGarePalette {
    static let accent = Color(hex: 0x4EA0FF)
    static let accentSoft = Color(hex: 0x9EC8FF)
    static let surface = Color.white.opacity(0.045)
    static let inlineSurface = Color.white.opacity(0.08)
    static let textMuted = Color.white.opacity(0.66)
}

// Io tengo in questo file le liste "operative" del reparto:
// accettazione gare e comunicazioni, con tutte le card dedicate.
struct VistaListaAccettazioneGare: View {
    let token: String
    let rows: [RigaModuloDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BachecaAccettazioneGareView(
                conteggio: rows.count,
                accettate: rows.filter { $0.status.lowercased() == "accepted" }.count,
                inAttesa: rows.filter { $0.status.lowercased() == "pending" || $0.status.isEmpty }.count
            )

            if rows.isEmpty {
                AccettazioneGareEmptyStateView(
                    titolo: "Nessuna gara disponibile",
                    messaggio: "Non ci sono designazioni da mostrare in questo momento."
                )
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(rows) { row in
                        NavigationLink {
                            VistaDettaglioGara(token: token, designazioneId: row.id, titolo: row.title)
                        } label: {
                            SchedaAccettazioneGaraView(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct VistaListaComunicazioni: View {
    let token: String
    let snapshot: SnapshotModuloDTO
    @ObservedObject private var comunicazioniNotifier = ComunicazioniNotificationStore.shared
    @State private var evidenziateNuove: Set<String> = []

    private var rows: [RigaModuloDTO] { snapshot.rows }

    private var allegatiCount: Int {
        rows.reduce(0) { $0 + $1.attachments.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderComunicazioniView(
                totale: rows.count,
                nuove: evidenziateNuove.intersection(Set(rows.map(\.id))).count,
                allegati: allegatiCount,
                intro: testoRipulitoPerUI(snapshot.introText)
            )

            if rows.isEmpty {
                StatoVuotoView(
                    titolo: "Nessuna comunicazione",
                    messaggio: "Non ci sono comunicazioni da mostrare in questo momento."
                )
            } else {
                LazyVStack(spacing: 18) {
                    ForEach(rows) { row in
                        SchedaComunicazioneView(
                            token: token,
                            row: row,
                            isNew: evidenziateNuove.contains(row.id)
                        )
                    }
                }
            }

            if !snapshot.legalText.isEmpty {
                BloccoInformativoComunicazioniView(
                    titolo: "Nota",
                    testo: snapshot.legalText
                )
            }
        }
        .task {
            sincronizzaStatoLettura()
        }
        .onChange(of: rows.map(\.id).joined(separator: "|")) { _, _ in
            sincronizzaStatoLettura()
        }
    }

    private func sincronizzaStatoLettura() {
        comunicazioniNotifier.applySnapshot(rows)
        evidenziateNuove = comunicazioniNotifier.unreadCommunicationIDs.intersection(Set(rows.map(\.id)))
        comunicazioniNotifier.markItemsAsRead(rows)
    }
}

private struct HeaderComunicazioniView: View {
    let totale: Int
    let nuove: Int
    let allegati: Int
    let intro: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 54, height: 54)

                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x9EC8FF))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Comunicazioni in evidenza")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(intro.isEmpty ? "Messaggi recenti e allegati pronti da consultare." : intro)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(3)
                }
            }

            HStack(spacing: 10) {
                StatComunicazioniPillView(label: "Mostrate", value: "\(totale)")
                StatComunicazioniPillView(label: "Nuove", value: "\(nuove)")
                StatComunicazioniPillView(label: "Allegati", value: "\(allegati)")
                StatComunicazioniPillView(label: "Stato", value: nuove > 0 ? "Nuove" : (totale > 0 ? "Lette" : "Vuote"))
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

struct SchedaComunicazioneView: View {
    let token: String
    let row: RigaModuloDTO
    let isNew: Bool

    private let apiClient = APIClient.shared

    private var titolo: String {
        testoRipulitoPerUI(row.title.isEmpty ? "Comunicazione" : row.title)
    }

    private var dataInvio: String {
        let subtitle = testoRipulitoPerUI(row.subtitle)
        if !subtitle.isEmpty {
            return subtitle
        }
        return valoreCampo(matching: ["data", "pubblicazione", "inviata", "inserimento"])
    }

    private var mittente: String {
        let stato = testoRipulitoPerUI(row.status)
        if !stato.isEmpty {
            return stato
        }
        return valoreCampo(matching: ["sezione", "mittente", "ufficio", "provenienza"])
    }

    private var corpo: String {
        let prioritari = row.fields.filter {
            let label = testoRipulitoPerUI($0.label).lowercased()
            return label.contains("testo")
                || label.contains("messaggio")
                || label.contains("contenuto")
                || label.contains("descrizione")
                || label.contains("oggetto")
        }

        if let first = prioritari.first {
            return testoRipulitoPerUI(first.value)
        }

        let fallback = row.fields
            .map { field -> String in
                let value = testoRipulitoPerUI(field.value)
                return value
            }
            .filter { !$0.isEmpty }

        return fallback.joined(separator: "\n\n")
    }

    private var campiSecondari: [CampoModuloDTO] {
        row.fields.filter { field in
            let label = testoRipulitoPerUI(field.label).lowercased()
            return !(label.contains("testo")
                || label.contains("messaggio")
                || label.contains("contenuto")
                || label.contains("descrizione")
                || label.contains("oggetto"))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        if isNew {
                            BadgeComunicazioneView(
                                titolo: "NUOVA",
                                accentColor: Color(hex: 0x63D9A6)
                            )
                        }

                        if !mittente.isEmpty {
                            BadgeComunicazioneView(
                                titolo: mittente,
                                accentColor: Color(hex: 0x6EA8FF)
                            )
                        }
                    }

                    Text(titolo)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)
            }

            HStack(spacing: 10) {
                if !dataInvio.isEmpty {
                    MetaComunicazioneChipView(icon: "calendar.badge.clock", title: "Data", value: dataInvio)
                }
                if !row.attachments.isEmpty {
                    MetaComunicazioneChipView(icon: "paperclip", title: "Allegati", value: "\(row.attachments.count)")
                }
            }

            if !corpo.isEmpty {
                BloccoDettaglioComunicazioneView(
                    icon: "text.alignleft",
                    titolo: "Messaggio",
                    testo: corpo,
                    lineLimit: nil
                )
            }

            if !campiSecondari.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(campiSecondari) { field in
                        if !testoRipulitoPerUI(field.value).isEmpty {
                            MetaSecondariaComunicazioneView(
                                titolo: testoRipulitoPerUI(field.label),
                                valore: testoRipulitoPerUI(field.value)
                            )
                        }
                    }
                }
            }

            if !row.attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(row.attachments) { attachment in
                            TicketedDownloadLink {
                                await urlAllegato(attachment)
                            } label: {
                                Label(
                                    testoRipulitoPerUI(attachment.label.isEmpty ? "Apri allegato" : attachment.label),
                                    systemImage: "paperclip"
                                )
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.white.opacity(0.08))
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
                .stroke(isNew ? Color(hex: 0x63D9A6).opacity(0.28) : Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func valoreCampo(matching labels: [String]) -> String {
        row.fields.first { field in
            let label = testoRipulitoPerUI(field.label).lowercased()
            return labels.contains { label.contains($0) }
        }
        .map { testoRipulitoPerUI($0.value) } ?? ""
    }

    private func urlAllegato(_ attachment: AllegatoModuloDTO) async -> URL? {
        if attachment.url.hasPrefix("communication:") {
            let communicationId = attachment.url.replacingOccurrences(of: "communication:", with: "")
            return await apiClient.urlDownloadAllegatoComunicazione(token: token, communicationId: communicationId)
        }
        return await apiClient.urlDownloadPortale(
            token: token,
            remoteURL: attachment.url,
            suggestedName: attachment.label
        )
    }
}

struct StatComunicazioniPillView: View {
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }
}

private struct BadgeComunicazioneView: View {
    let titolo: String
    let accentColor: Color

    var body: some View {
        Text(titolo)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(accentColor.opacity(0.24))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accentColor.opacity(0.36), lineWidth: 1)
            )
    }
}

private struct MetaComunicazioneChipView: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: 0x9EC8FF))

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.52))

                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct BloccoDettaglioComunicazioneView: View {
    let icon: String
    let titolo: String
    let testo: String
    let lineLimit: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: 0x20457D).opacity(0.72))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x9EC8FF))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(titolo.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.52))

                Text(testo)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(lineLimit)
                    .fixedSize(horizontal: false, vertical: true)
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
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct MetaSecondariaComunicazioneView: View {
    let titolo: String
    let valore: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titolo.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.50))

            Text(valore)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
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

// Io riuso questo blocco anche in altre sezioni (es. area personale), quindi lo lascio non-private.
struct BloccoInformativoComunicazioniView: View {
    let titolo: String
    let testo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titolo)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(testoRipulitoPerUI(testo))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct SchedaAccettazioneGaraView: View {
    let row: RigaModuloDTO

    private var data: String { valore("Data") }
    private var ora: String { valore("Ora") }
    private var categoria: String { categoriaCompleta(valore("Categoria")) }
    private var girone: String { valore("Girone") }
    private var giornata: String { valore("Giornata") }
    private var ruolo: String { valore("Ruolo") }
    private var ruoloCompattoLabel: String { ruoloCompatto(ruolo) }
    private var titoloPulito: String { testoRipulitoPerUI(row.title.isEmpty ? "Gara" : row.title) }
    private var gironeLabel: String {
        let cleaned = testoRipulitoPerUI(girone)
        guard !cleaned.isEmpty else { return "-" }
        if cleaned.lowercased().hasPrefix("girone") { return cleaned }
        return "Girone \(cleaned)"
    }
    private var descrizioneBreve: String {
        [
            categoria.isEmpty ? nil : categoria,
            girone.isEmpty ? nil : gironeLabel,
            giornata.isEmpty ? nil : testoRipulitoPerUI(giornata)
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(statoColore)
                .frame(width: 6)
                .padding(.vertical, 12)
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PARTITA DESIGNATA")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AccettazioneGarePalette.accent)
                            .tracking(1.1)

                        Text(titoloPulito)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        if !descrizioneBreve.isEmpty {
                            Text(descrizioneBreve)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AccettazioneGarePalette.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 10) {
                        AccettazioneStatoBadgeView(
                            title: statoLabel,
                            accentColor: statoColore
                        )

                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AccettazioneGarePalette.accentSoft)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AccettazioneGarePalette.inlineSurface)
                            )
                    }
                }

                HStack(spacing: 8) {
                    AccettazioneInfoBadgeView(icon: "calendar", text: data)
                    AccettazioneInfoBadgeView(icon: "clock", text: ora)
                    if !ruoloCompattoLabel.isEmpty {
                        AccettazioneInfoBadgeView(icon: "figure.soccer", text: ruoloCompattoLabel)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    SchedaMetaGaraView(titolo: "Ruolo", valore: ruoloCompattoLabel, accentColor: statoColore)
                    SchedaMetaGaraView(titolo: "Categoria", valore: categoria, accentColor: AccettazioneGarePalette.accent)
                    SchedaMetaGaraView(titolo: "Girone", valore: gironeLabel, accentColor: AccettazioneGarePalette.accentSoft)
                    SchedaMetaGaraView(titolo: "Giornata", valore: giornata, accentColor: AccettazioneGarePalette.accentSoft)
                }

                HStack {
                    Text("Apri dettagli gara")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AccettazioneGarePalette.accent)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AccettazioneGarePalette.accent)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AccettazioneGarePalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AccettazioneGarePalette.accent.opacity(0.24), lineWidth: 1)
        )
    }

    private func valore(_ label: String) -> String {
        testoRipulitoPerUI(
            row.fields.first(where: { $0.label.caseInsensitiveCompare(label) == .orderedSame })?.value ?? ""
        )
    }

    private var statoLabel: String {
        let raw = row.status.lowercased()
        if raw == "accepted" { return "Accettata" }
        if raw == "rejected" { return "Rifiutata" }
        if raw == "expired" { return "Scaduta" }
        if raw == "pending" { return "In attesa" }
        if !row.subtitle.isEmpty { return row.subtitle }
        return "In attesa"
    }

    private var statoColore: Color {
        let raw = row.status.lowercased()
        if raw == "accepted" { return AccettazioneGarePalette.accent }
        if raw == "rejected" { return Color(hex: 0xFF6A6A) }
        if raw == "expired" { return Color(hex: 0x8A93A8) }
        return Color(hex: 0xFFB24A)
    }
}

private struct AccettazioneStatoBadgeView: View {
    let title: String
    let accentColor: Color

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AccettazioneGarePalette.inlineSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accentColor.opacity(0.36), lineWidth: 1)
            )
    }
}

private struct AccettazioneInfoBadgeView: View {
    let icon: String
    let text: String

    private var cleanedText: String {
        testoRipulitoPerUI(text)
    }

    var body: some View {
        if !cleanedText.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AccettazioneGarePalette.accentSoft)

                Text(cleanedText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AccettazioneGarePalette.inlineSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AccettazioneGarePalette.accent.opacity(0.16), lineWidth: 1)
            )
        }
    }
}

struct StatoGaraBadgeView: View {
    let title: String
    let accentColor: Color

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(accentColor.opacity(0.24))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accentColor.opacity(0.36), lineWidth: 1)
            )
    }
}

struct InfoBadgeView: View {
    let icon: String
    let text: String

    private var cleanedText: String {
        testoRipulitoPerUI(text)
    }

    var body: some View {
        if !cleanedText.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.70))

                Text(cleanedText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(hex: 0x76AEFF).opacity(0.18))
            )
        }
    }
}

struct MiniDettaglioColonnaView: View {
    let titolo: String
    let valore: String

    private var valorePulito: String {
        let cleaned = testoRipulitoPerUI(valore)
        return cleaned.isEmpty ? "-" : cleaned
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titolo.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.48))

            Text(valorePulito)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0x7BAFFF).opacity(0.14))
        )
    }
}

private struct SchedaMetaGaraView: View {
    let titolo: String
    let valore: String
    let accentColor: Color

    private var valorePulito: String {
        let cleaned = testoRipulitoPerUI(valore)
        return cleaned.isEmpty ? "-" : cleaned
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titolo.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accentColor.opacity(0.92))

            Text(valorePulito)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
                .minimumScaleFactor(0.84)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AccettazioneGarePalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accentColor.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct BachecaAccettazioneGareView: View {
    let conteggio: Int
    let accettate: Int
    let inAttesa: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AccettazioneGarePalette.inlineSurface)
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AccettazioneGarePalette.accentSoft)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("ACCETTAZIONE GARE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AccettazioneGarePalette.accent)
                        .tracking(1.2)

                    Text("Panoramica designazioni")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Apri subito la gara giusta, controlla ruolo e competizione senza perdere tempo.")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(AccettazioneGarePalette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                StatPillView(label: "Totali", value: "\(conteggio)")
                StatPillView(label: "Accettate", value: "\(accettate)")
                StatPillView(label: "In attesa", value: "\(inAttesa)")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AccettazioneGarePalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AccettazioneGarePalette.accent.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct StatPillView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AccettazioneGarePalette.accentSoft)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AccettazioneGarePalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AccettazioneGarePalette.accent.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct AccettazioneGareEmptyStateView: View {
    let titolo: String
    let messaggio: String

    var body: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AccettazioneGarePalette.inlineSurface)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "sportscourt")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AccettazioneGarePalette.accentSoft)
                }

            Text(titolo)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(messaggio)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AccettazioneGarePalette.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AccettazioneGarePalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AccettazioneGarePalette.accent.opacity(0.24), lineWidth: 1)
        )
    }
}
