//
//  RepartiViews.swift
//  Sinfonia4You
//
//  Viste native per navigare i reparti dell'app tramite backend.
//

import SwiftUI
import UIKit

struct VistaElencoReparti: View {
    let token: String
    let titolo: String
    let moduliVisibili: [String]

    @StateObject private var viewModel = CatalogoRepartiViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text(titolo)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(sottotitoloSchermata)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.62))

                if viewModel.inCaricamento {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                } else if !viewModel.errore.isEmpty {
                    StatoVuotoView(
                        titolo: "Caricamento non riuscito",
                        messaggio: viewModel.errore
                    )
                } else {
                    ForEach(gruppiVisualizzati, id: \.titolo) { gruppo in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(gruppo.titolo)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.88))

                            ForEach(gruppo.moduli) { modulo in
                                NavigationLink(value: modulo) {
                                    SchedaRepartoView(modulo: modulo)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 126)
        }
        .task {
            await viewModel.carica(token: token)
        }
    }

    private var gruppiVisualizzati: [(titolo: String, moduli: [RepartoSintesiDTO])] {
        gruppiFiltrati + gruppiAggiuntivi
    }

    private var gruppiFiltrati: [(titolo: String, moduli: [RepartoSintesiDTO])] {
        viewModel.gruppi.compactMap { gruppo in
            let moduliBase = gruppo.modules.filter { moduliVisibili.isEmpty || moduliVisibili.contains($0.id) }
            let moduli = titolo == "Gestione Gare"
                ? moduliConRapportoGara(in: moduliBase)
                : moduliBase
            guard !moduli.isEmpty else { return nil }
            return (gruppo.title, moduli)
        }
    }

    private var gruppiAggiuntivi: [(titolo: String, moduli: [RepartoSintesiDTO])] {
        guard titolo == "Gestione Gare" else { return [] }

        return [(
            titolo: "Supporto Arbitrale",
            moduli: [
                RepartoSintesiDTO(
                    id: "regulations",
                    title: "Regolamenti",
                    subtitle: "Gioco del Calcio, Calcio a 5 e Beach Soccer in PDF ufficiale AIA.",
                    systemIcon: "book.closed"
                )
            ]
        )]
    }

    private func moduliConRapportoGara(in moduli: [RepartoSintesiDTO]) -> [RepartoSintesiDTO] {
        guard !moduli.contains(where: { $0.id == "match_report" }) else { return moduli }

        let moduloRapportoGara = RepartoSintesiDTO(
            id: "match_report",
            title: "Rapporto Gara",
            subtitle: "Apple Watch offline, cronometro live ed eventi vocali sincronizzati su iPhone.",
            systemIcon: "applewatch.watchface"
        )

        guard let index = moduli.firstIndex(where: { $0.id == "referti" }) else { return moduli }

        var risultato = moduli
        risultato.insert(moduloRapportoGara, at: index + 1)
        return risultato
    }

    private var sottotitoloSchermata: String {
        switch titolo {
        case "Gestione Gare":
            return "Consulta designazioni, scheda tecnica, referti, rapporto gara e regolamenti ufficiali in un'unica area ordinata."
        case "Notizie":
            return "Eventi e comunicazioni aggiornati dell'associazione."
        default:
            return "Tutti i reparti utili sono raccolti qui per una consultazione veloce."
        }
    }
}

struct VistaProfiloDashboard: View {
    let token: String
    let profilo: ProfiloArbitro
    let moduliVisibili: [String]

    @StateObject private var viewModel = CatalogoRepartiViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ProfiloHeroCardView(token: token, profilo: profilo)

                if viewModel.inCaricamento {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                } else if !viewModel.errore.isEmpty {
                    StatoVuotoView(
                        titolo: "Caricamento non riuscito",
                        messaggio: viewModel.errore
                    )
                } else {
                    ForEach(gruppiFiltrati, id: \.titolo) { gruppo in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(gruppo.titolo)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            ForEach(gruppo.moduli) { modulo in
                                NavigationLink(value: modulo) {
                                    SchedaRepartoView(modulo: modulo)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 126)
        }
        .task {
            await viewModel.carica(token: token)
        }
    }

    private var gruppiFiltrati: [(titolo: String, moduli: [RepartoSintesiDTO])] {
        viewModel.gruppi.compactMap { gruppo in
            let moduli = gruppo.modules.filter { moduliVisibili.isEmpty || moduliVisibili.contains($0.id) }
            guard !moduli.isEmpty else { return nil }
            return (gruppo.title, moduli)
        }
    }
}

struct VistaSnapshotModulo: View {
    let token: String
    let modulo: RepartoSintesiDTO

    @StateObject private var viewModel = SnapshotModuloViewModel()

    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            contenutoScroll
        }
        .navigationTitle(modulo.title)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.carica(token: token, moduleId: modulo.id)
        }
    }

    private var contenutoScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: modulo.id == "referti" ? 12 : 16) {
                if modulo.id != "referti" {
                    intestazione
                }

                if let snapshot = viewModel.snapshot {
                    if viewModel.inCaricamento {
                        ProgressView("Sto aggiornando il modulo...")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                    contenuto(snapshot: snapshot)
                } else if viewModel.inCaricamento {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 32)
                } else if !viewModel.errore.isEmpty {
                    StatoVuotoView(
                        titolo: "Modulo non disponibile",
                        messaggio: viewModel.errore
                    )
                } else {
                    StatoVuotoView(
                        titolo: "Nessun contenuto",
                        messaggio: "Il backend non ha restituito dati per questo reparto."
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, modulo.id == "referti" ? 10 : 18)
            .padding(.bottom, modulo.id == "referti" ? 100 : 120)
        }
    }

    @ViewBuilder
    private func contenuto(snapshot: SnapshotModuloDTO) -> some View {
        if snapshot.moduleId != "matches",
           snapshot.moduleId != "profile",
           snapshot.moduleId != "communications",
           snapshot.moduleId != "referti",
           snapshot.moduleId != "iban",
           !snapshot.highlights.isEmpty {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(snapshot.highlights) { highlight in
                    CardHighlightView(highlight: highlight)
                }
            }
        }

        if snapshot.moduleId != "communications",
           snapshot.moduleId != "profile",
           snapshot.moduleId != "referti",
           snapshot.moduleId != "curriculum",
           snapshot.moduleId != "iban",
           !snapshot.introText.isEmpty {
            BloccoTestoView(titolo: "Sintesi", testo: snapshot.introText)
        }

        if !snapshot.optionGroups.isEmpty {
            ForEach(snapshot.optionGroups) { gruppo in
                CardOpzioniView(gruppo: gruppo)
            }
        }

        // Io tengo qui solo il routing tra moduli: quando devo ritoccare una singola lista,
        // entro nel file dedicato senza sporcare questa vista principale.
        if snapshot.moduleId == "matches" {
            VistaListaAccettazioneGare(
                token: token,
                rows: snapshot.rows
            )
        } else if snapshot.moduleId == "referti" {
            VistaListaReferti(
                token: token,
                snapshot: snapshot,
                inAggiornamento: viewModel.inCaricamento,
                onAggiornaPeriodo: { dateFrom, dateTo in
                    await viewModel.carica(
                        token: token,
                        moduleId: snapshot.moduleId,
                        dateFrom: dateFrom,
                        dateTo: dateTo
                    )
                }
            )
        } else if snapshot.moduleId == "profile" {
            VistaAnagrafePersonale(
                token: token,
                snapshot: snapshot
            )
        } else if snapshot.moduleId == "iban" {
            VistaGestioneIBAN(
                token: token,
                snapshot: snapshot
            )
        } else if snapshot.moduleId == "curriculum" {
            VistaGestioneCurriculum(
                token: token,
                snapshot: snapshot
            )
        } else if snapshot.moduleId == "communications" {
            VistaListaComunicazioni(
                token: token,
                snapshot: snapshot
            )
        } else if !snapshot.rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dettagli")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                ForEach(snapshot.rows) { row in
                    RigaModuloCardView(
                        token: token,
                        row: row
                    )
                }
            }
        }

        if snapshot.moduleId != "communications",
           snapshot.moduleId != "profile",
           snapshot.moduleId != "curriculum",
           snapshot.moduleId != "iban",
           !snapshot.legalText.isEmpty {
            BloccoTestoView(titolo: "Note", testo: snapshot.legalText)
        }
    }

    private var intestazione: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: modulo.systemIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x89B9FF))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(modulo.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(modulo.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
            }
        }
    }
}

private struct VistaAnagrafePersonale: View {
    let token: String
    let snapshot: SnapshotModuloDTO

    private var righe: [RigaModuloDTO] { snapshot.rows }

    private var campi: [CampoModuloDTO] {
        righe.flatMap(\.fields).filter { !testoRipulitoPerUI($0.value).isEmpty }
    }

    private var allegati: [AllegatoModuloDTO] {
        righe.flatMap(\.attachments)
    }

    private var highlights: [HighlightModuloDTO] {
        snapshot.highlights.filter { !testoRipulitoPerUI($0.value).isEmpty }
    }

    private var gruppiCampi: [(titolo: String, campi: [CampoModuloDTO])] {
        let definitions: [(String, [String])] = [
            ("Identità", ["nome", "cognome", "codice", "qualifica", "ruolo", "sezione", "tessera", "matricola"]),
            ("Contatti", ["mail", "email", "pec", "telefono", "cellulare", "fax"]),
            ("Residenza", ["indirizzo", "via", "piazza", "comune", "citta", "città", "provincia", "cap", "residenza", "domicilio"]),
            ("Dati personali", ["nascita", "codice fiscale", "fiscale", "sesso", "nazional", "documento"])
        ]

        var remaining = campi
        var result: [(String, [CampoModuloDTO])] = []

        for definition in definitions {
            let matching = remaining.filter { field in
                let label = normalizeFieldLabel(field.label)
                return definition.1.contains { label.contains($0) }
            }

            if !matching.isEmpty {
                result.append((definition.0, matching))
                let matchingIDs = Set(matching.map(\.id))
                remaining.removeAll { matchingIDs.contains($0.id) }
            }
        }

        if !remaining.isEmpty {
            result.append(("Altri dati", remaining))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderAnagrafePersonaleView(
                totaleCampi: campi.count,
                totaleSezioni: gruppiCampi.count,
                intro: testoRipulitoPerUI(snapshot.introText)
            )

            if !highlights.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(highlights) { highlight in
                        CardHighlightProfiloView(highlight: highlight)
                    }
                }
            }

            if gruppiCampi.isEmpty {
                StatoVuotoView(
                    titolo: "Anagrafe non disponibile",
                    messaggio: "Non risultano dati anagrafici da mostrare in questo momento."
                )
            } else {
                ForEach(gruppiCampi, id: \.titolo) { gruppo in
                    SezioneAnagrafePersonaleView(categoria: gruppo.titolo, campi: gruppo.campi)
                }
            }

            if !allegati.isEmpty {
                AllegatiAnagrafeView(token: token, allegati: allegati)
            }

            if !snapshot.legalText.isEmpty {
                BloccoInformativoComunicazioniView(
                    titolo: "Nota",
                    testo: snapshot.legalText
                )
            }
        }
    }

    private func normalizeFieldLabel(_ raw: String) -> String {
        testoRipulitoPerUI(raw)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
}

private struct HeaderAnagrafePersonaleView: View {
    let totaleCampi: Int
    let totaleSezioni: Int
    let intro: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 54, height: 54)

                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x9EC8FF))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Anagrafe Personale")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(intro.isEmpty ? "Dati personali e riferimenti organizzati in una scheda più chiara." : intro)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(3)
                }
            }

            HStack(spacing: 10) {
                StatComunicazioniPillView(label: "Campi", value: "\(totaleCampi)")
                StatComunicazioniPillView(label: "Sezioni", value: "\(totaleSezioni)")
                StatComunicazioniPillView(label: "Stato", value: totaleCampi > 0 ? "Completa" : "Vuota")
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

private struct CardHighlightProfiloView: View {
    let highlight: HighlightModuloDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(testoRipulitoPerUI(highlight.label).uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.52))

            Text(testoRipulitoPerUI(highlight.value))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct SezioneAnagrafePersonaleView: View {
    let categoria: String
    let campi: [CampoModuloDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(categoria)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(campi) { field in
                    CampoAnagrafeView(
                        label: testoRipulitoPerUI(field.label),
                        value: testoRipulitoPerUI(field.value)
                    )
                }
            }
        }
    }
}

private struct CampoAnagrafeView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.50))

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct AllegatiAnagrafeView: View {
    let token: String
    let allegati: [AllegatoModuloDTO]

    private let apiClient = APIClient.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Allegati")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(allegati) { attachment in
                        // La URL viene risolta al tocco con un ticket monouso,
                        // cosi' il token di sessione non finisce mai nel link.
                        TicketedDownloadLink {
                            await apiClient.urlDownloadPortale(
                                token: token,
                                remoteURL: attachment.url,
                                suggestedName: attachment.label
                            )
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
}

private struct VistaGestioneCurriculum: View {
    let token: String
    let snapshot: SnapshotModuloDTO

    private var sezioni: [CurriculumSectionData] {
        snapshot.rows.map { row in
            CurriculumSectionData(row: row)
        }
    }

    private var totaleVoci: Int {
        sezioni.reduce(0) { partial, section in
            partial + section.entries.count
        }
    }

    private var totaleCampi: Int {
        sezioni.reduce(0) { partial, section in
            partial + section.totalFields
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderGestioneCurriculumView(
                totaleSezioni: sezioni.count,
                totaleVoci: totaleVoci,
                totaleCampi: totaleCampi,
                intro: testoRipulitoPerUI(snapshot.introText)
            )

            if sezioni.isEmpty {
                StatoVuotoView(
                    titolo: "Curriculum non disponibile",
                    messaggio: "Non risultano sezioni del curriculum in questo momento."
                )
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(sezioni) { section in
                        SezioneCurriculumView(
                            token: token,
                            section: section
                        )
                    }
                }
            }

            if !snapshot.legalText.isEmpty {
                BloccoInformativoComunicazioniView(
                    titolo: "Note",
                    testo: snapshot.legalText
                )
            }
        }
    }
}

private struct HeaderGestioneCurriculumView: View {
    let totaleSezioni: Int
    let totaleVoci: Int
    let totaleCampi: Int
    let intro: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 50, height: 50)

                    Image(systemName: "list.bullet.rectangle.portrait.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xA7CCFF))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Gestione Curriculum")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(intro.isEmpty ? "Qualifica, organo tecnico, sezione e storico dati in una vista piu ordinata." : intro)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(3)
                }
            }

            HStack(spacing: 10) {
                StatComunicazioniPillView(label: "Sezioni", value: "\(totaleSezioni)")
                StatComunicazioniPillView(label: "Voci", value: "\(totaleVoci)")
                StatComunicazioniPillView(label: "Campi", value: "\(totaleCampi)")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x1573D1), Color(hex: 0x123765)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct SezioneCurriculumView: View {
    let token: String
    let section: CurriculumSectionData

    private let apiClient = APIClient.shared

    private var toneColor: Color {
        let normalized = section.status
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()

        if normalized.contains("attiv")
            || normalized.contains("confermat")
            || normalized.contains("ok")
            || normalized.contains("valid") {
            return Color(hex: 0x4ED09A)
        }

        if normalized.contains("attes")
            || normalized.contains("verific")
            || normalized.contains("pending")
            || normalized.contains("bozza") {
            return Color(hex: 0xF5BA53)
        }

        return Color(hex: 0x92BFFF)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if !section.subtitle.isEmpty {
                        Text(section.subtitle)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.62))
                    }
                }

                Spacer(minLength: 8)

                if !section.status.isEmpty {
                    Text(section.status)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(toneColor.opacity(0.34))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                }
            }
            .padding(.bottom, 2)

            if !section.entries.isEmpty {
                CurriculumEntriesBlocksView(
                    entries: section.entries,
                    columns: section.columns,
                    toneColor: toneColor
                )
            }

            if !section.looseFields.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Dettagli aggiuntivi", systemImage: "square.stack.3d.down.right.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.84))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(section.looseFields) { field in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(testoRipulitoPerUI(field.label).uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.52))

                                Text(testoRipulitoPerUI(field.value))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            if !section.attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(section.attachments) { attachment in
                            TicketedDownloadLink {
                                await urlAllegato(attachment)
                            } label: {
                                Label(
                                    testoRipulitoPerUI(attachment.label.isEmpty ? "Apri allegato" : attachment.label),
                                    systemImage: "paperclip"
                                )
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(toneColor.opacity(0.22))
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.07), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(toneColor.opacity(0.9))
                .frame(width: 3)
                .padding(.vertical, 10)
        }
    }

    private func urlAllegato(_ attachment: AllegatoModuloDTO) async -> URL? {
        if attachment.url.hasPrefix("communication:") {
            let communicationId = attachment.url.replacingOccurrences(of: "communication:", with: "")
            return await apiClient.urlDownloadAllegatoComunicazione(token: token, communicationId: communicationId)
        }

        return await apiClient.urlDownloadPortale(
            token: token,
            remoteURL: attachment.url,
            suggestedName: attachment.label.isEmpty ? "allegato_curriculum" : attachment.label
        )
    }
}

private struct CurriculumEntriesBlocksView: View {
    let entries: [CurriculumEntryData]
    let columns: [String]
    let toneColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Voci curriculum", systemImage: "rectangle.grid.2x2.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.84))

            VStack(spacing: 10) {
                ForEach(entries) { entry in
                    CurriculumEntryBlockView(
                        entry: entry,
                        columns: columns,
                        toneColor: toneColor
                    )
                }
            }
        }
    }
}

private struct CurriculumEntryBlockView: View {
    let entry: CurriculumEntryData
    let columns: [String]
    let toneColor: Color

    private var pairs: [(label: String, value: String)] {
        columns.map { column in
            (column, testoRipulitoPerUI(entry.value(for: column)))
        }
    }

    private var filledCount: Int {
        pairs.filter { !$0.value.isEmpty }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Text("Voce \(entry.position)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(toneColor.opacity(0.30))
                    )

                Spacer(minLength: 8)

                Text("\(filledCount)/\(pairs.count) campi")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(pairs, id: \.label) { pair in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(testoRipulitoPerUI(pair.label).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.53))

                        Text(pair.value.isEmpty ? "—" : pair.value)
                            .font(.system(size: 13.5, weight: pair.value.isEmpty ? .medium : .semibold))
                            .foregroundStyle(pair.value.isEmpty ? Color.white.opacity(0.42) : .white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [toneColor.opacity(0.13), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct CurriculumSectionData: Identifiable {
    private static let entryLabelPattern = #"(?i)^voce\s*(\d+)\s*(?:\.|:|\-|\u00B7)\s*(.+)$"#
    private static let entryLabelRegex = try? NSRegularExpression(pattern: entryLabelPattern)

    let id: String
    let title: String
    let subtitle: String
    let status: String
    let columns: [String]
    let entries: [CurriculumEntryData]
    let looseFields: [CampoModuloDTO]
    let attachments: [AllegatoModuloDTO]

    var totalFields: Int {
        entries.reduce(0) { partial, item in
            partial + item.valuesByColumn.count
        } + looseFields.count
    }

    init(row: RigaModuloDTO) {
        id = row.id.isEmpty ? "curriculum-\(row.title)-\(row.subtitle)" : row.id
        title = testoRipulitoPerUI(row.title).isEmpty ? "Sezione Curriculum" : testoRipulitoPerUI(row.title)
        subtitle = testoRipulitoPerUI(row.subtitle)
        status = testoRipulitoPerUI(row.status)
        attachments = row.attachments

        var parsedByEntry: [Int: [String: String]] = [:]
        var orderedColumns: [String] = []
        var columnSet: Set<String> = []
        var remainingFields: [CampoModuloDTO] = []

        for field in row.fields {
            let cleanValue = testoRipulitoPerUI(field.value)
            guard !cleanValue.isEmpty else { continue }

            let cleanLabel = testoRipulitoPerUI(field.label)
            if let parsing = Self.parseCurriculumEntryLabel(cleanLabel) {
                if columnSet.insert(parsing.column).inserted {
                    orderedColumns.append(parsing.column)
                }
                var bag = parsedByEntry[parsing.entry] ?? [:]
                bag[parsing.column] = cleanValue
                parsedByEntry[parsing.entry] = bag
            } else {
                remainingFields.append(
                    CampoModuloDTO(
                        label: cleanLabel.isEmpty ? "Campo" : cleanLabel,
                        value: cleanValue
                    )
                )
            }
        }

        columns = orderedColumns
        entries = parsedByEntry
            .keys
            .sorted()
            .map { key in
                CurriculumEntryData(position: key, valuesByColumn: parsedByEntry[key] ?? [:])
            }
        looseFields = remainingFields
    }

    private static func parseCurriculumEntryLabel(_ rawLabel: String) -> (entry: Int, column: String)? {
        let normalized = testoRipulitoPerUI(rawLabel)
        guard !normalized.isEmpty else { return nil }

        guard let regex = entryLabelRegex else { return nil }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)

        guard let match = regex.firstMatch(in: normalized, options: [], range: range),
              let entryRange = Range(match.range(at: 1), in: normalized),
              let columnRange = Range(match.range(at: 2), in: normalized) else {
            return nil
        }

        let entry = Int(normalized[entryRange]) ?? 0
        let column = testoRipulitoPerUI(String(normalized[columnRange]))

        guard entry > 0 else { return nil }
        return (entry, column.isEmpty ? "Campo" : column)
    }
}

private struct CurriculumEntryData: Identifiable {
    let position: Int
    let valuesByColumn: [String: String]

    var id: String { "curriculum-entry-\(position)" }

    func value(for column: String) -> String {
        valuesByColumn[column] ?? ""
    }
}

private enum IbanStatusTone {
    case confirmed
    case review
    case neutral

    init(status rawValue: String) {
        let normalized = testoRipulitoPerUI(rawValue)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()

        if normalized.contains("confermat")
            || normalized.contains("approvat")
            || normalized.contains("attiv")
            || normalized == "ok"
            || normalized.contains("valid") {
            self = .confirmed
        } else if normalized.contains("attes")
            || normalized.contains("verific")
            || normalized.contains("pending")
            || normalized.contains("sospes") {
            self = .review
        } else {
            self = .neutral
        }
    }

    var accent: Color {
        switch self {
        case .confirmed:
            return Color(hex: 0x53D79D)
        case .review:
            return Color(hex: 0xF8BC47)
        case .neutral:
            return Color(hex: 0x8FC2FF)
        }
    }

    var icon: String {
        switch self {
        case .confirmed:
            return "checkmark.seal.fill"
        case .review:
            return "clock.badge.exclamationmark.fill"
        case .neutral:
            return "questionmark.circle.fill"
        }
    }

    var heroColors: [Color] {
        switch self {
        case .confirmed:
            return [Color(hex: 0x0E7A60), Color(hex: 0x123765)]
        case .review:
            return [Color(hex: 0xA4670E), Color(hex: 0x123765)]
        case .neutral:
            return [Color(hex: 0x1573D1), Color(hex: 0x123765)]
        }
    }

    var surfaceColors: [Color] {
        switch self {
        case .confirmed:
            return [Color(hex: 0x183D35), Color(hex: 0x0E223B)]
        case .review:
            return [Color(hex: 0x3D2E18), Color(hex: 0x10233B)]
        case .neutral:
            return [Color(hex: 0x183055), Color(hex: 0x10223D)]
        }
    }

    var softFill: Color {
        switch self {
        case .confirmed:
            return Color(hex: 0x53D79D).opacity(0.15)
        case .review:
            return Color(hex: 0xF8BC47).opacity(0.15)
        case .neutral:
            return Color(hex: 0x8FC2FF).opacity(0.15)
        }
    }
}

private enum IbanPalette {
    static let accent = Color(hex: 0x4EA0FF)
    static let accentSoft = Color(hex: 0x9EC8FF)
    static let surface = Color.white.opacity(0.045)
    static let inlineSurface = Color.white.opacity(0.08)
    static let textMuted = Color.white.opacity(0.66)
}

private struct VistaGestioneIBAN: View {
    let token: String
    let snapshot: SnapshotModuloDTO

    private var ibanValue: String {
        valueForHighlight(matching: ["iban"])
    }

    private var statoValue: String {
        valueForHighlight(matching: ["stato", "status"])
    }

    private var tone: IbanStatusTone {
        IbanStatusTone(status: statoValue)
    }

    private var extraHighlights: [HighlightModuloDTO] {
        snapshot.highlights.filter { highlight in
            let normalized = normalizedLabel(highlight.label)
            let isIban = normalized.contains("iban")
            let isStatus = normalized.contains("stato") || normalized.contains("status")
            return !isIban && !isStatus && !testoRipulitoPerUI(highlight.value).isEmpty
        }
    }

    private var rowsConContenuto: [RigaModuloDTO] {
        snapshot.rows.filter { row in
            if !testoRipulitoPerUI(row.title).isEmpty { return true }
            if !testoRipulitoPerUI(row.subtitle).isEmpty { return true }
            if !testoRipulitoPerUI(row.status).isEmpty { return true }
            if row.fields.contains(where: { !testoRipulitoPerUI($0.value).isEmpty }) { return true }
            if !row.attachments.isEmpty { return true }
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderGestioneIBANView(
                stato: testoRipulitoPerUI(statoValue),
                intro: testoRipulitoPerUI(snapshot.introText),
                hasIban: !testoRipulitoPerUI(ibanValue).isEmpty,
                tone: tone
            )

            IbanSummaryCardView(
                iban: testoRipulitoPerUI(ibanValue),
                stato: testoRipulitoPerUI(statoValue),
                tone: tone
            )

            if !extraHighlights.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(extraHighlights) { highlight in
                        IbanHighlightCardView(highlight: highlight, tone: tone)
                    }
                }
            }

            if !rowsConContenuto.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(IbanPalette.inlineSurface)
                            .frame(width: 32, height: 32)
                            .overlay {
                                Image(systemName: "text.document.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(IbanPalette.accentSoft)
                            }

                        Text("Storico e dettagli")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    ForEach(rowsConContenuto) { row in
                        IbanDettaglioCardView(token: token, row: row, tone: tone)
                    }
                }
            }

            if !snapshot.legalText.isEmpty {
                BloccoInformativoComunicazioniView(
                    titolo: "Dichiarazione",
                    testo: snapshot.legalText
                )
            }
        }
    }

    private func valueForHighlight(matching keywords: [String]) -> String {
        for highlight in snapshot.highlights {
            let normalized = normalizedLabel(highlight.label)
            if keywords.contains(where: { normalized.contains($0) }) {
                return highlight.value
            }
        }

        for row in snapshot.rows {
            for field in row.fields {
                let normalized = normalizedLabel(field.label)
                if keywords.contains(where: { normalized.contains($0) }) {
                    return field.value
                }
            }
        }

        return ""
    }

    private func normalizedLabel(_ raw: String) -> String {
        testoRipulitoPerUI(raw)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
}

private struct HeaderGestioneIBANView: View {
    let stato: String
    let intro: String
    let hasIban: Bool
    let tone: IbanStatusTone

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(IbanPalette.inlineSurface)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 23, weight: .black))
                            .foregroundStyle(IbanPalette.accentSoft)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text("GESTIONE IBAN")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(IbanPalette.accent)
                        .tracking(1.2)

                    Text("Gestione IBAN")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(intro.isEmpty ? "Coordinate bancarie, stato e controlli nello stesso spazio, con un layout più pulito." : intro)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(IbanPalette.textMuted)
                        .lineLimit(3)
                }
            }

            HStack(spacing: 8) {
                Label(stato.isEmpty ? "Stato non disponibile" : stato, systemImage: tone.icon)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(IbanPalette.inlineSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(IbanPalette.accent.opacity(0.24), lineWidth: 1)
                    )

                Label(hasIban ? "IBAN presente" : "IBAN assente", systemImage: "checklist")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(IbanPalette.inlineSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(IbanPalette.accent.opacity(0.16), lineWidth: 1)
                    )

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(IbanPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(IbanPalette.accent.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct IbanSummaryCardView: View {
    let iban: String
    let stato: String
    let tone: IbanStatusTone

    private var cleanIban: String {
        testoRipulitoPerUI(iban)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .uppercased()
    }

    private var groups: [String] {
        guard !cleanIban.isEmpty else { return [] }
        var result: [String] = []
        var current = ""
        for char in cleanIban {
            current.append(char)
            if current.count == 4 {
                result.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Coordinate correnti", systemImage: "creditcard.and.123")
                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))

            if groups.isEmpty {
                Text("IBAN non disponibile")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.84))
            } else {
                Text(cleanIban)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(IbanPalette.inlineSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(IbanPalette.accent.opacity(0.18), lineWidth: 1)
                    )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                    ForEach(groups, id: \.self) { chunk in
                        Text(chunk)
                            .font(.system(size: 14.5, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(IbanPalette.inlineSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(IbanPalette.accent.opacity(0.16), lineWidth: 1)
                            )
                    }
                }
            }

            HStack(spacing: 8) {
                if !stato.isEmpty {
                    Text(stato.uppercased())
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(IbanPalette.inlineSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(IbanPalette.accent.opacity(0.18), lineWidth: 1)
                        )
                }

                Text("Verifica sempre il codice prima di inviare documenti o aggiornamenti.")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(IbanPalette.textMuted)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(IbanPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(IbanPalette.accent.opacity(0.20), lineWidth: 1)
        )
    }
}

private struct IbanHighlightCardView: View {
    let highlight: HighlightModuloDTO
    let tone: IbanStatusTone

    private var iconName: String {
        let normalized = testoRipulitoPerUI(highlight.label)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()

        if normalized.contains("istituto") || normalized.contains("banca") {
            return "building.columns.fill"
        }
        if normalized.contains("intestat") || normalized.contains("titolare") {
            return "person.crop.rectangle.fill"
        }
        if normalized.contains("paese") || normalized.contains("nazione") {
            return "globe.europe.africa.fill"
        }
        return "square.text.square.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(IbanPalette.accentSoft)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(IbanPalette.inlineSurface)
                )

            Text(testoRipulitoPerUI(highlight.label).uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(IbanPalette.accentSoft.opacity(0.92))

            Text(testoRipulitoPerUI(highlight.value))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(IbanPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(IbanPalette.accent.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct IbanDettaglioCardView: View {
    let token: String
    let row: RigaModuloDTO
    let tone: IbanStatusTone

    private let apiClient = APIClient.shared

    private var campiVisibili: [CampoModuloDTO] {
        row.fields.filter { !testoRipulitoPerUI($0.value).isEmpty }
    }

    private var statoRiga: String {
        testoRipulitoPerUI(row.status)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(IbanPalette.accentSoft)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(IbanPalette.inlineSurface)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    if !testoRipulitoPerUI(row.title).isEmpty {
                        Text(testoRipulitoPerUI(row.title))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    if !testoRipulitoPerUI(row.subtitle).isEmpty {
                        Text(testoRipulitoPerUI(row.subtitle))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.66))
                    }
                }

                Spacer(minLength: 4)

                if !statoRiga.isEmpty {
                    Text(statoRiga.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(IbanPalette.inlineSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(IbanPalette.accent.opacity(0.18), lineWidth: 1)
                        )
                }
            }

            if !campiVisibili.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                    ForEach(campiVisibili) { field in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(testoRipulitoPerUI(field.label).uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.50))
                            Text(testoRipulitoPerUI(field.value))
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(IbanPalette.inlineSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(IbanPalette.accent.opacity(0.12), lineWidth: 1)
                        )
                    }
                }
            }

            if !row.attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(row.attachments) { attachment in
                            TicketedDownloadLink {
                                await urlAllegato(attachment)
                            } label: {
                                Label(
                                    testoRipulitoPerUI(attachment.label.isEmpty ? "Apri allegato" : attachment.label),
                                    systemImage: "paperclip.circle.fill"
                                )
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(IbanPalette.inlineSurface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(IbanPalette.accent.opacity(0.18), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(IbanPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(IbanPalette.accent.opacity(0.18), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(IbanPalette.accentSoft)
                .frame(width: 3)
                .padding(.vertical, 10)
        }
    }

    private func urlAllegato(_ attachment: AllegatoModuloDTO) async -> URL? {
        if attachment.url.hasPrefix("communication:") {
            let communicationId = attachment.url.replacingOccurrences(of: "communication:", with: "")
            return await apiClient.urlDownloadAllegatoComunicazione(token: token, communicationId: communicationId)
        }

        return await apiClient.urlDownloadPortale(
            token: token,
            remoteURL: attachment.url,
            suggestedName: attachment.label.isEmpty ? "allegato_iban" : attachment.label
        )
    }
}

private struct ProfiloHeroCardView: View {
    let token: String
    let profilo: ProfiloArbitro

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                AvatarProfiloRemotoView(token: token, initials: profilo.initials)

                VStack(alignment: .leading, spacing: 8) {
                    Text(profilo.fullName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if !profilo.role.isEmpty {
                        Text(profilo.role)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x94C1FF))
                    }

                    Text("Ultimo accesso: \(profilo.lastAccessLabel)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.66))
                }

                Spacer(minLength: 0)
            }

            ProfiloMetaRowView(
                items: [
                    ("Codice", profilo.code.isEmpty ? "-" : profilo.code),
                    ("Sezione", profilo.section.isEmpty ? "-" : profilo.section),
                    ("Ruolo", profilo.role.isEmpty ? "-" : profilo.role)
                ]
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x0D4C8D), Color(hex: 0x101934)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 18, y: 8)
    }
}

private struct AvatarProfiloRemotoView: View {
    let token: String
    let initials: String

    private let apiClient = APIClient.shared

    // La foto profilo veniva caricata con il token in query string. Ora la URL
    // viene risolta una sola volta con un ticket monouso.
    @State private var urlFoto: URL?

    var body: some View {
        Group {
            if let urlFoto {
                AsyncImage(url: urlFoto) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .task {
            guard urlFoto == nil else { return }
            urlFoto = await apiClient.urlFotoProfilo(token: token)
        }
        .frame(width: 92, height: 92)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.88), lineWidth: 2.5)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
    }

    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x193F74), Color(hex: 0x0C1D4A)],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 90
                    )
                )

            Text(initials)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

private struct ProfiloMetaRowView: View {
    let items: [(String, String)]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items.filter { !$0.1.isEmpty }, id: \.0) { item in
                ProfiloMetaTagView(title: item.0, value: item.1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct ProfiloMetaTagView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(hex: 0x7CB8FF))

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

struct VistaDettaglioGara: View {
    let token: String
    let designazioneId: String
    let titolo: String

    @StateObject private var viewModel = DettaglioGaraViewModel()

    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.inCaricamento {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 32)
                    } else if !viewModel.errore.isEmpty {
                        StatoVuotoView(titolo: "Dettaglio gara non disponibile", messaggio: viewModel.errore)
                    } else if let dettaglio = viewModel.dettaglio {
                        TestataDettaglioGaraView(
                            match: dettaglio.match,
                            classifica: viewModel.classifica
                        )

                        if !viewModel.messaggioOperazione.isEmpty {
                            BloccoTestoView(titolo: "Esito", testo: viewModel.messaggioOperazione)
                        }

                        SchedaPanoramicaDettaglioGaraView(dettaglio: dettaglio)

                        if !dettaglio.collaborators.isEmpty {
                            SchedaCollaboratoriGaraView(match: dettaglio.match, collaborators: dettaglio.collaborators)
                        } else if dettaglio.detailFields.competition.isEmpty && dettaglio.detailFields.whereLine.isEmpty && !dettaglio.detailText.isEmpty {
                            BloccoTestoView(titolo: "Informazioni Ufficiali", testo: dettaglio.detailText)
                        }

                        if let classifica = viewModel.classifica {
                            SchedaClassificaGaraView(
                                classifica: classifica,
                                homeTeam: dettaglio.match.homeTeam,
                                awayTeam: dettaglio.match.awayTeam
                            )
                        } else if viewModel.inCaricamentoClassifica {
                            SchedaClassificaLoadingView()
                        } else if !viewModel.erroreClassifica.isEmpty {
                            SchedaClassificaNonDisponibileView(messaggio: viewModel.erroreClassifica)
                        }

                        if dettaglio.match.canAccept || dettaglio.match.canReject {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Azioni disponibili")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)

                                HStack(spacing: 12) {
                                    if dettaglio.match.canAccept {
                                        Button {
                                            Task {
                                                await viewModel.eseguiAzione(
                                                    token: token,
                                                    designazioneId: designazioneId,
                                                    action: "accept"
                                                )
                                            }
                                        } label: {
                                            Text(viewModel.inAzione ? "Invio..." : "Accetta gara")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [Color(hex: 0x2A8E55), Color(hex: 0x16643C)],
                                                                startPoint: .leading,
                                                                endPoint: .trailing
                                                            )
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(viewModel.inAzione)
                                    }

                                    if dettaglio.match.canReject {
                                        Button {
                                            Task {
                                                await viewModel.eseguiAzione(
                                                    token: token,
                                                    designazioneId: designazioneId,
                                                    action: "reject"
                                                )
                                            }
                                        } label: {
                                            Text(viewModel.inAzione ? "Invio..." : "Rifiuta gara")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [Color(hex: 0xA84A4A), Color(hex: 0x742B2B)],
                                                                startPoint: .leading,
                                                                endPoint: .trailing
                                                            )
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(viewModel.inAzione)
                                    }
                                }
                            }
                            .padding(18)
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
                }
                .padding(.horizontal, 18)
                .padding(.top, 32)
                .padding(.bottom, 110)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sinfoniaBackNavigation()
        .task {
            await viewModel.carica(token: token, designazioneId: designazioneId)
        }
    }
}

struct VistaDettaglioReferto: View {
    let token: String
    let designazioneId: String
    let titolo: String
    let onAssistantFlowCompleted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DettaglioRefertoViewModel()

    init(
        token: String,
        designazioneId: String,
        titolo: String,
        onAssistantFlowCompleted: (() -> Void)? = nil
    ) {
        self.token = token
        self.designazioneId = designazioneId
        self.titolo = titolo
        self.onAssistantFlowCompleted = onAssistantFlowCompleted
    }

    var body: some View {
        ZStack {
            SfondoDettaglioRepartoView()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.inCaricamento {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 32)
                    } else if let dettaglio = viewModel.dettaglio {
                        let isDirettoreSvolgimento = dettaglio.roleKind != "assistant" && !dettaglio.svolgimentoOptions.isEmpty
                        CardTitoloView(
                            titolo: titolo,
                            sottotitolo: dettaglio.statusLabel ?? (dettaglio.item.canCompile ? "Da compilare" : "Già compilato")
                        )

                        RefertoSintesiPanoramicaView(dettaglio: dettaglio)

                        if !dettaglio.gameFields.isEmpty {
                            RefertoDatiGaraView(dettaglio: dettaglio)
                        }

                        if !(dettaglio.saveHint ?? "").isEmpty, dettaglio.item.canCompile {
                            BloccoTestoView(
                                titolo: dettaglio.roleKind == "assistant" ? "Invio del rapporto" : "Salvataggio",
                                testo: dettaglio.saveHint ?? ""
                            )
                        } else if !(dettaglio.readOnlyHint ?? "").isEmpty {
                            BloccoTestoView(
                                titolo: "Consultazione",
                                testo: dettaglio.readOnlyHint ?? ""
                            )
                        }

                        if !dettaglio.officials.isEmpty, !isDirettoreSvolgimento {
                            RefertoUfficialiDesignatiView(dettaglio: dettaglio)
                        }

                        if dettaglio.item.canCompile, isDirettoreSvolgimento {
                            RefertoDirettoreSvolgimentoView(
                                dettaglio: dettaglio,
                                viewModel: viewModel,
                                token: token,
                                designazioneId: designazioneId
                            )
                        } else if dettaglio.item.canCompile {
                            VStack(alignment: .leading, spacing: 14) {
                                Text(dettaglio.reportTitle.isEmpty
                                     ? (dettaglio.roleKind == "assistant" ? "Compilazione Rapporto" : "Compilazione Referto")
                                     : dettaglio.reportTitle)
                                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)

                                if !viewModel.anteprimaPronta, !dettaglio.segnalazioneNotice.isEmpty {
                                    Text(dettaglio.segnalazioneNotice)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.72))
                                }

                                if viewModel.anteprimaPronta, dettaglio.roleKind != "assistant" {
                                    RefertoAnteprimaInvioView(
                                        dettaglio: dettaglio,
                                        segnalazioneValue: viewModel.segnalazioneSelezionata,
                                        noteText: viewModel.noteEventi
                                    )
                                    HStack(spacing: 12) {
                                        Button {
                                            viewModel.annullaAnteprima()
                                        } label: {
                                            Text("Modifica")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 15)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                        .fill(Color.white.opacity(0.08))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(viewModel.inSalvataggio)

                                        Button {
                                            dismiss()
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: "arrow.uturn.backward.circle.fill")
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
                                                            colors: [Color(hex: 0x2C7BE5), Color(hex: 0x1859AF)],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(viewModel.inSalvataggio)
                                    }
                                } else {
                                    if dettaglio.roleKind == "assistant" {
                                        RefertoSintesiRapportoAssistenteView(
                                            segnalazioneValue: viewModel.segnalazioneSelezionata,
                                            noteText: viewModel.noteEventi
                                        )
                                    }

                                    VStack(spacing: 12) {
                                        RefertoSceltaSegnalazioneView(
                                            titolo: "Nulla da segnalare",
                                            sottotitolo: dettaglio.roleKind == "assistant"
                                                ? "Invia il rapporto senza annotazioni aggiuntive."
                                                : "Conferma che non ci sono eventi da riportare.",
                                            isSelected: viewModel.segnalazioneSelezionata == "1"
                                        ) {
                                            viewModel.selezionaSegnalazione("1")
                                        }

                                        RefertoSceltaSegnalazioneView(
                                            titolo: "Segnala evento",
                                            sottotitolo: dettaglio.roleKind == "assistant"
                                                ? "Scrivi quello che il direttore di gara deve leggere nel rapporto assistente."
                                                : "Aggiungi gli eventi che devono entrare nel referto ufficiale.",
                                            isSelected: viewModel.segnalazioneSelezionata == "2"
                                        ) {
                                            viewModel.selezionaSegnalazione("2")
                                        }
                                    }

                                    if viewModel.segnalazioneSelezionata == "2" {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(dettaglio.noteTitle.isEmpty ? "Descrizione eventi" : dettaglio.noteTitle)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Color.white.opacity(0.82))

                                            TextEditor(
                                                text: Binding(
                                                    get: { viewModel.noteEventi },
                                                    set: { viewModel.aggiornaNoteEventi($0) }
                                                )
                                            )
                                                .scrollContentBackground(.hidden)
                                                .foregroundStyle(.white)
                                                .frame(minHeight: 140)
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

                                    Button {
                                        Task {
                                            await viewModel.salva(token: token, designazioneId: designazioneId)
                                        }
                                    } label: {
                                        HStack(spacing: 10) {
                                            if viewModel.inSalvataggio {
                                                ProgressView()
                                                    .tint(.white)
                                            }
                                            Image(systemName: dettaglio.roleKind == "assistant" ? "internaldrive.fill" : "square.and.arrow.down.fill")
                                                .font(.system(size: 16, weight: .bold))

                                            Text(
                                                viewModel.inSalvataggio
                                                    ? "Operazione in corso..."
                                                    : (dettaglio.roleKind == "assistant"
                                                       ? assistantSaveButtonTitle(for: dettaglio)
                                                       : "Salva referto")
                                            )
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color(hex: 0x2A8E55), Color(hex: 0x16643C)],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(viewModel.inSalvataggio)
                                }

                                if !viewModel.errore.isEmpty {
                                    BloccoTestoView(
                                        titolo: "Errore",
                                        testo: viewModel.errore
                                    )
                                }

                                if !viewModel.messaggioOperazione.isEmpty {
                                    BloccoTestoView(titolo: "Esito", testo: viewModel.messaggioOperazione)
                                }

                                if !dettaglio.noteRemaining.isEmpty {
                                    Text(dettaglio.noteRemaining)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.62))
                                }
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
                        } else {
                            RefertoEsitoInviatoView(dettaglio: dettaglio)
                        }

                        if !dettaglio.templateFields.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Campi modulo")
                                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)

                                ForEach(dettaglio.templateFields) { field in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(field.label)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text(field.value)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.72))
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.white.opacity(0.04))
                                    )
                                }
                            }
                        }
                    } else if !viewModel.errore.isEmpty {
                        StatoVuotoView(titolo: "Referto non disponibile", messaggio: viewModel.errore)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 110)
            }
        }
        .navigationTitle("Dettaglio Referto")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.carica(token: token, designazioneId: designazioneId)
        }
        .overlay {
            if viewModel.mostraPopupSalvataggioAssistente, let dettaglio = viewModel.dettaglio {
                ZStack {
                    Color.black.opacity(0.42)
                        .ignoresSafeArea()

                    RefertoPopupSalvataggioAssistenteView(
                        dettaglio: dettaglio,
                        segnalazioneValue: viewModel.segnalazioneSelezionata,
                        noteText: viewModel.noteEventi,
                        onChiudi: {
                            viewModel.chiudiPopupSalvataggioAssistente()
                        },
                        onModifica: {
                            viewModel.chiudiPopupSalvataggioAssistente()
                        },
                        onEsci: {
                            viewModel.chiudiPopupSalvataggioAssistente()
                            onAssistantFlowCompleted?()
                            dismiss()
                        }
                    )
                    .frame(maxWidth: 940)
                    .padding(.horizontal, 16)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.mostraPopupSalvataggioAssistente)
    }

    private func assistantSaveButtonTitle(for dettaglio: DettaglioRefertoDTO) -> String {
        let label = testoRipulitoPerUI(dettaglio.saveLabel ?? "")
        return label.isEmpty ? "Salva" : label
    }
}

private struct RefertoSintesiPanoramicaView: View {
    let dettaglio: DettaglioRefertoDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(dettaglio.roleKind == "assistant" ? "RUOLO REFERTO" : "RIEPILOGO REFERTO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: 0xA8D0FF))

                    Text(dettaglio.roleLabel ?? dettaglio.item.activity)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 12)

                if let actionLabel = dettaglio.actionLabel, !actionLabel.isEmpty {
                    Text(actionLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MiniDettaglioColonnaView(titolo: "Categoria", valore: dettaglio.item.category)
                MiniDettaglioColonnaView(titolo: "Girone", valore: dettaglio.item.group)
                MiniDettaglioColonnaView(titolo: "Giornata", valore: dettaglio.item.giornata)
                MiniDettaglioColonnaView(titolo: "Numero gara", valore: dettaglio.item.numero)
            }

            if !dettaglio.reportTitle.isEmpty {
                Text(dettaglio.reportTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x123B71).opacity(0.94), Color(hex: 0x0E203F).opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct RefertoDatiGaraView: View {
    let dettaglio: DettaglioRefertoDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Dati Gara")
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(dettaglio.gameFields) { field in
                    RefertoCampoDettaglioView(
                        titolo: field.label,
                        valore: field.value
                    )
                }
            }
        }
    }
}

private struct RefertoUfficialiDesignatiView: View {
    let dettaglio: DettaglioRefertoDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ufficiali di Gara Designati")
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            LazyVStack(spacing: 12) {
                ForEach(Array(dettaglio.officials.enumerated()), id: \.offset) { index, row in
                    let nome = [row["Nome"], row["Cognome"]]
                        .compactMap { testoRipulitoPerUI($0 ?? "").isEmpty ? nil : testoRipulitoPerUI($0 ?? "") }
                        .joined(separator: " ")
                    let codice = testoRipulitoPerUI(row["CodMec"] ?? "")
                    let sezione = testoRipulitoPerUI(row["Sezione"] ?? "")
                    let ruolo = testoRipulitoPerUI(row["Ruolo"] ?? "")
                    let recapito = testoRipulitoPerUI(row["Recapito"] ?? "")

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(nome.isEmpty ? "Ufficiale \(index + 1)" : nome)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)

                                if !codice.isEmpty {
                                    Text("Codice meccanografico \(codice)")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.62))
                                }
                            }

                            Spacer(minLength: 10)

                            if !ruolo.isEmpty {
                                Text(ruolo)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(Color(hex: 0x225EAE).opacity(0.72))
                                    )
                            }
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            if !sezione.isEmpty {
                                RefertoCampoDettaglioView(titolo: "Sezione", valore: sezione)
                            }
                            if !recapito.isEmpty {
                                RefertoCampoDettaglioView(titolo: "Recapito", valore: recapito)
                            }
                        }
                    }
                    .padding(18)
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
        }
    }
}

private struct RefertoCampoDettaglioView: View {
    let titolo: String
    let valore: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titolo.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.50))

            Text(valore)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private enum DettaglioGaraPalette {
    static let surface = Color.white.opacity(0.045)
    static let surfaceSoft = Color.white.opacity(0.05)
    static let inlineSurface = Color.white.opacity(0.08)
    static let border = Color.white.opacity(0.10)
    static let borderSoft = Color.white.opacity(0.08)
    static let textMuted = Color.white.opacity(0.66)
    static let textSoft = Color.white.opacity(0.50)
    static let accent = Color(hex: 0x89B9FF)
    static let accentSoft = Color(hex: 0x76AEFF).opacity(0.16)
}

private struct TestataDettaglioGaraView: View {
    let match: MatchAssignmentDTO
    let classifica: ClassificaGaraDTO?

    private var resolvedRows: (home: RigaClassificaDTO?, away: RigaClassificaDTO?) {
        guard let classifica else {
            return (nil, nil)
        }
        return classifica.uiResolvedRows(
            homeTeam: match.homeTeam,
            awayTeam: match.awayTeam
        )
    }

    private var factItems: [DettaglioGaraFactItem] {
        var items = [
            DettaglioGaraFactItem(title: "Ruolo", value: ruoloCompatto(match.activity)),
            DettaglioGaraFactItem(title: "Numero gara", value: match.idGara)
        ]

        if !testoRipulitoPerUI(match.giornata).isEmpty {
            items.append(
                DettaglioGaraFactItem(
                    title: "Giornata",
                    value: testoRipulitoPerUI(match.giornata)
                )
            )
        }

        return items
    }

    private var referenceItems: [DettaglioGaraFactItem] {
        [
            DettaglioGaraFactItem(
                title: "Categoria",
                value: categoriaCompleta(match.category)
            ),
            DettaglioGaraFactItem(
                title: "Girone",
                value: testoRipulitoPerUI(match.group)
            )
        ]
        .filter { !$0.value.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dettaglio gara")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Designazione, programma e riferimenti principali.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DettaglioGaraPalette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                StatoGaraBadgeView(
                    title: statoLabel,
                    accentColor: statoColor
                )
            }

            DettaglioGaraTeamsBoardView(
                homeTeam: match.homeTeam,
                awayTeam: match.awayTeam,
                date: match.date,
                time: match.time,
                homeLogoURL: teamLogoURL(for: resolvedRows.home, fallbackTeamName: match.homeTeam),
                awayLogoURL: teamLogoURL(for: resolvedRows.away, fallbackTeamName: match.awayTeam)
            )

            ViewThatFits(in: .vertical) {
                HStack(spacing: 10) {
                    ForEach(factItems) { item in
                        DettaglioGaraFactPillView(item: item)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(factItems) { item in
                        DettaglioGaraFactPillView(item: item)
                    }
                }
            }

            if !referenceItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Riferimenti gara")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DettaglioGaraPalette.textSoft)

                    ViewThatFits(in: .vertical) {
                        HStack(spacing: 10) {
                            ForEach(referenceItems) { item in
                                DettaglioGaraReferenceCardView(item: item)
                            }
                        }

                        VStack(spacing: 10) {
                            ForEach(referenceItems) { item in
                                DettaglioGaraReferenceCardView(item: item)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(DettaglioGaraPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(DettaglioGaraPalette.border, lineWidth: 1)
        )
    }

    private var statoLabel: String {
        let value = match.status.lowercased()
        if value == "accepted" { return "Accettata" }
        if value == "rejected" { return "Rifiutata" }
        if value == "expired" { return "Scaduta" }
        return match.statusLabel.isEmpty ? "In attesa" : match.statusLabel
    }

    private var statoColor: Color {
        let value = match.status.lowercased()
        if value == "accepted" { return Color(hex: 0x54D38A) }
        if value == "rejected" { return Color(hex: 0xFF6A6A) }
        if value == "expired" { return Color(hex: 0x8A93A8) }
        return Color(hex: 0xFFB24A)
    }

    private func teamLogoURL(for row: RigaClassificaDTO?, fallbackTeamName: String) -> URL? {
        TuttocampoTeamLogoStore.logoURL(
            for: row,
            fallbackTeamName: fallbackTeamName,
            size: 40
        )
    }
}

private struct DettaglioGaraFactItem: Identifiable {
    let title: String
    let value: String

    var id: String { "\(title)|\(value)" }
}

private struct DettaglioGaraReferenceCardView: View {
    let item: DettaglioGaraFactItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DettaglioGaraPalette.textSoft)

            Text(testoRipulitoPerUI(item.value))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DettaglioGaraPalette.accentSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct DettaglioGaraTeamsBoardView: View {
    let homeTeam: String
    let awayTeam: String
    let date: String
    let time: String
    let homeLogoURL: URL?
    let awayLogoURL: URL?

    var body: some View {
        VStack(spacing: 12) {
            DettaglioGaraTeamRowView(
                teamName: homeTeam,
                logoURL: homeLogoURL
            )

            DettaglioGaraProgrammaStripView(
                date: date,
                time: time
            )

            DettaglioGaraTeamRowView(
                teamName: awayTeam,
                logoURL: awayLogoURL
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DettaglioGaraPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct DettaglioGaraTeamRowView: View {
    let teamName: String
    let logoURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            DettaglioGaraTeamLogoView(
                teamName: teamName,
                logoURL: logoURL,
                size: 38
            )

            Text(testoRipulitoPerUI(teamName))
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DettaglioGaraPalette.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct DettaglioGaraTeamLogoView: View {
    let teamName: String
    let logoURL: URL?
    let size: CGFloat
    @State private var renderedImage: UIImage?

    private var initials: String {
        let tokens = testoRipulitoPerUI(teamName)
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }

        let joined = tokens.joined()
        return joined.isEmpty ? "?" : joined
    }

    private var displayedImage: UIImage? {
        renderedImage ?? TuttocampoTeamLogoStore.cachedImage(for: logoURL)
    }

    var body: some View {
        Group {
            if let displayedImage {
                Image(uiImage: displayedImage)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            } else if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DettaglioGaraPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
        .task(id: logoURL?.absoluteString ?? teamName) {
            guard let logoURL else {
                renderedImage = nil
                return
            }

            if let cached = TuttocampoTeamLogoStore.cachedImage(for: logoURL) {
                renderedImage = cached
                return
            }

            renderedImage = await TuttocampoTeamLogoStore.loadImage(from: logoURL)
        }
    }

    private var placeholder: some View {
        Text(initials)
            .font(.system(size: max(11, size * 0.34), weight: .bold, design: .rounded))
            .foregroundStyle(DettaglioGaraPalette.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
    }
}

private struct DettaglioGaraProgrammaStripView: View {
    let date: String
    let time: String

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DettaglioGaraPalette.accent)

                    Text(testoRipulitoPerUI(date))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 0)

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 6, height: 6)

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DettaglioGaraPalette.accent)

                    Text(testoRipulitoPerUI(time))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DettaglioGaraPalette.accent)

                    Text(testoRipulitoPerUI(date))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DettaglioGaraPalette.accent)

                    Text(testoRipulitoPerUI(time))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct DettaglioGaraFactPillView: View {
    let item: DettaglioGaraFactItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DettaglioGaraPalette.textSoft)

            Text(testoRipulitoPerUI(item.value))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DettaglioGaraPalette.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct SchedaPanoramicaDettaglioGaraView: View {
    let dettaglio: DettaglioGaraDTO

    private var programmazioneEntry: QuadroUfficialeEntry? {
        let value = dettaglio.detailFields.whenLine.isEmpty
            ? "\(dettaglio.match.date) · \(dettaglio.match.time)"
            : dettaglio.detailFields.whenLine
        let cleaned = testoRipulitoPerUI(value)
        guard !cleaned.isEmpty else { return nil }
        return QuadroUfficialeEntry(icon: "calendar.badge.clock", title: "Programmazione", value: cleaned)
    }

    private var luogoEntry: QuadroUfficialeEntry? {
        let cleaned = testoRipulitoPerUI(dettaglio.detailFields.whereLine)
        guard !cleaned.isEmpty else { return nil }
        return QuadroUfficialeEntry(icon: "mappin.and.ellipse", title: "Luogo gara", value: cleaned)
    }

    private var supportEntries: [QuadroUfficialeEntry] {
        [
            QuadroUfficialeEntry(
                icon: "eurosign.circle.fill",
                title: "Rimborso",
                value: testoRipulitoPerUI(dettaglio.detailFields.rimborso)
            ),
            QuadroUfficialeEntry(
                icon: "road.lanes",
                title: "Distanza",
                value: testoRipulitoPerUI(dettaglio.detailFields.distance)
            )
        ]
        .filter { !$0.value.isEmpty }
    }

    private var mapsURL: URL? {
        let query = dettaglio.mapsQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(encoded)")
    }

    private var hasContent: Bool {
        programmazioneEntry != nil || luogoEntry != nil || !supportEntries.isEmpty || mapsURL != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Quadro ufficiale")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Dati operativi da controllare prima di partire per la gara.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DettaglioGaraPalette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !hasContent {
                Text("Nessun dato ufficiale disponibile.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DettaglioGaraPalette.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(DettaglioGaraPalette.surfaceSoft)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
                    )
            } else {
                if let programmazioneEntry {
                    QuadroUfficialeFocusCardView(item: programmazioneEntry)
                }

                if let luogoEntry {
                    QuadroUfficialeWideCardView(item: luogoEntry)
                }

                if !supportEntries.isEmpty || mapsURL != nil {
                    QuadroUfficialeSupportPanelView(
                        items: supportEntries,
                        mapsURL: mapsURL
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DettaglioGaraPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DettaglioGaraPalette.border, lineWidth: 1)
        )
    }
}

private struct QuadroUfficialeEntry: Identifiable {
    let icon: String
    let title: String
    let value: String

    var id: String { title }
}

private struct QuadroUfficialeSupportPanelView: View {
    let items: [QuadroUfficialeEntry]
    let mapsURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DettaglioGaraPalette.accentSoft)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "car.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DettaglioGaraPalette.accent)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Trasferta")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Riepilogo rapido di rimborso, distanza e navigazione.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DettaglioGaraPalette.textMuted)
                }
            }

            if !items.isEmpty {
                ViewThatFits(in: .vertical) {
                    HStack(spacing: 12) {
                        ForEach(items) { item in
                            QuadroUfficialeCompactCardView(item: item)
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(items) { item in
                            QuadroUfficialeCompactCardView(item: item)
                        }
                    }
                }
            }

            if let mapsURL {
                Link(destination: mapsURL) {
                    QuadroUfficialeMapsButtonView()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DettaglioGaraPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct QuadroUfficialeFocusCardView: View {
    let item: QuadroUfficialeEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DettaglioGaraPalette.accentSoft)
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DettaglioGaraPalette.accent)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DettaglioGaraPalette.textSoft)

                Text(item.value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DettaglioGaraPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct QuadroUfficialeWideCardView: View {
    let item: QuadroUfficialeEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DettaglioGaraPalette.accent)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DettaglioGaraPalette.textSoft)

                Text(item.value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DettaglioGaraPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct QuadroUfficialeCompactCardView: View {
    let item: QuadroUfficialeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DettaglioGaraPalette.accent)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DettaglioGaraPalette.textSoft)

                    Text("Dato ufficiale")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DettaglioGaraPalette.textMuted)
                }
            }

            Text(item.value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct QuadroUfficialeMapsButtonView: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "map.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("Apri posizione in Google Maps")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Avvia subito la navigazione verso il campo.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DettaglioGaraPalette.accentSoft.opacity(1.15),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct SchedaCollaboratoriGaraView: View {
    let match: MatchAssignmentDTO
    let collaborators: [CollaboratoreGaraDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Squadra arbitrale")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Composizione del gruppo arbitrale e contatti rapidi essenziali.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DettaglioGaraPalette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text("\(collaborators.count) \(collaborators.count == 1 ? "ufficiale" : "ufficiali")")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DettaglioGaraPalette.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DettaglioGaraPalette.inlineSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
                    )
            }

            LazyVStack(spacing: 12) {
                ForEach(collaborators) { item in
                    CollaboratoreGaraCardView(match: match, item: item)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DettaglioGaraPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DettaglioGaraPalette.border, lineWidth: 1)
        )
    }
}

private struct CollaboratoreGaraCardView: View {
    let match: MatchAssignmentDTO
    let item: CollaboratoreGaraDTO

    private var displayName: String {
        extractedIdentity.name
    }

    private var sectionValue: String? {
        extractedIdentity.section
    }

    private var roleValue: String? {
        let compact = testoRipulitoPerUI(ruoloCompatto(item.role))
        if !compact.isEmpty {
            return compact
        }
        let readable = testoRipulitoPerUI(ruoloDescrittivo(item.role))
        return readable.isEmpty ? nil : readable
    }

    private var emailValue: String? {
        let cleaned = testoRipulitoPerUI(item.email)
            .replacingOccurrences(of: #"^\((.*)\)$"#, with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private var roleIcon: String {
        let role = item.role.lowercased()
        if role.contains("assist") {
            return "flag.pattern.checkered"
        }
        if role.contains("osserv") {
            return "eye.fill"
        }
        if role.contains("var") {
            return "dot.radiowaves.left.and.right"
        }
        return "person.crop.circle.badge.checkmark"
    }

    private var extractedIdentity: (name: String, section: String?) {
        let rawName = testoRipulitoPerUI(item.name)
        let explicitSection = testoRipulitoPerUI(item.section ?? "")

        guard
            let matchRange = rawName.range(
                of: #"\s*\((SEZ(?:IONE)?\.?\s*[^)]*)\)\s*$"#,
                options: [.regularExpression, .caseInsensitive]
            )
        else {
            return (
                name: rawName,
                section: explicitSection.isEmpty ? nil : explicitSection
            )
        }

        let extractedName = testoRipulitoPerUI(String(rawName[..<matchRange.lowerBound]))
        let extractedSection = testoRipulitoPerUI(
            String(rawName[matchRange])
                .replacingOccurrences(of: #"^\s*\("#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\)\s*$"#, with: "", options: .regularExpression)
        )

        return (
            name: extractedName.isEmpty ? rawName : extractedName,
            section: explicitSection.isEmpty ? (extractedSection.isEmpty ? nil : extractedSection) : explicitSection
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DettaglioGaraPalette.inlineSurface)
                        .frame(width: 50, height: 50)

                    Image(systemName: roleIcon)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(DettaglioGaraPalette.accent)
                }

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)

                        if let sectionValue {
                            Text("(\(sectionValue))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DettaglioGaraPalette.textMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if let roleValue {
                            CollaboratoreMetaRowView(
                                label: "Ruolo",
                                value: roleValue
                            )
                        }

                        if let emailValue {
                            CollaboratoreMetaRowView(
                                label: "Email",
                                value: emailValue
                            )
                        }
                    }
                }

                Spacer(minLength: 10)
            }

            if !item.cell.isEmpty {
                Divider()
                    .overlay(Color.white.opacity(0.08))
            }

            if !item.cell.isEmpty {
                ContattiRapidiUfficialeView(
                    name: displayName,
                    role: roleValue ?? item.role,
                    phone: item.cell,
                    match: match
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DettaglioGaraPalette.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct CollaboratoreMetaRowView: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DettaglioGaraPalette.textSoft)
                .frame(width: 46, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct ContattiRapidiUfficialeView: View {
    let name: String
    let role: String
    let phone: String
    let match: MatchAssignmentDTO

    private var cleanedPhone: String {
        numeroTelefonicoPulito(phone)
    }

    private var callURL: URL? {
        guard !cleanedPhone.isEmpty else { return nil }
        return URL(string: "tel://\(cleanedPhone)")
    }

    private var whatsappURL: URL? {
        guard let recipient = numeroWhatsApp(phone) else { return nil }
        let message = messaggioWhatsApp(
            name: name,
            role: role,
            match: match
        )
        guard let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return URL(string: "https://wa.me/\(recipient)")
        }
        return URL(string: "https://wa.me/\(recipient)?text=\(encoded)")
    }

    var body: some View {
        HStack(spacing: 10) {
            if let callURL {
                Link(destination: callURL) {
                    DettaglioAzioneView(
                        title: "Chiama",
                        icon: "phone.fill",
                        isPrimary: true
                    )
                }
                .buttonStyle(.plain)
            }

            if let whatsappURL {
                Link(destination: whatsappURL) {
                    DettaglioAzioneView(
                        title: "Messaggio",
                        icon: "message.fill",
                        isPrimary: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    private func messaggioWhatsApp(
        name: String,
        role: String,
        match: MatchAssignmentDTO
    ) -> String {
        let nomePulito = testoRipulitoPerUI(name)
        let ruoloPulito = ruoloDescrittivo(role)
        let squadre = "\(testoRipulitoPerUI(match.homeTeam)) - \(testoRipulitoPerUI(match.awayTeam))"
        let dataOra = "\(testoRipulitoPerUI(match.date)) alle \(testoRipulitoPerUI(match.time))"
        return "Ciao \(nomePulito), ti contatto per la gara \(squadre) del \(dataOra). Ruolo: \(ruoloPulito)."
    }
}

private struct DettaglioAzioneView: View {
    let title: String
    let icon: String
    let isPrimary: Bool

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isPrimary ? DettaglioGaraPalette.accentSoft : DettaglioGaraPalette.inlineSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isPrimary ? DettaglioGaraPalette.accent.opacity(0.34) : DettaglioGaraPalette.borderSoft,
                        lineWidth: 1
                    )
            )
    }
}

private func numeroTelefonicoPulito(_ raw: String) -> String {
    let allowed = Set("+0123456789")
    let compact = raw.filter { allowed.contains($0) }
    if compact.hasPrefix("+") {
        return compact
    }
    return compact
}

private func numeroWhatsApp(_ raw: String) -> String? {
    let digits = raw.filter(\.isNumber)
    guard !digits.isEmpty else { return nil }

    if digits.hasPrefix("39") {
        return digits
    }

    if digits.count == 10 {
        return "39" + digits
    }

    return digits
}

private struct SchedaClassificaGaraView: View {
    let classifica: ClassificaGaraDTO
    let homeTeam: String
    let awayTeam: String

    private var resolvedRows: (home: RigaClassificaDTO?, away: RigaClassificaDTO?) {
        classifica.uiResolvedRows(
            homeTeam: homeTeam,
            awayTeam: awayTeam
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Classifica gara")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            ClassificaConfrontoEssenzialeView(
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                homeRow: resolvedRows.home,
                awayRow: resolvedRows.away
            )

            if !classifica.rows.isEmpty {
                ClassificaTabellaEssenzialeView(
                    rows: classifica.rows,
                    homeRow: resolvedRows.home,
                    awayRow: resolvedRows.away
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DettaglioGaraPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DettaglioGaraPalette.border, lineWidth: 1)
        )
    }
}

private extension ClassificaGaraDTO {
    func uiResolvedRows(homeTeam: String, awayTeam: String) -> (home: RigaClassificaDTO?, away: RigaClassificaDTO?) {
        var usedRowKeys = Set<String>()

        let resolvedHome = Self.uiResolveRow(
            expectedTeamName: homeTeam,
            preferredRow: homeRow,
            candidates: rows,
            usedRowKeys: &usedRowKeys
        )
        let resolvedAway = Self.uiResolveRow(
            expectedTeamName: awayTeam,
            preferredRow: awayRow,
            candidates: rows,
            usedRowKeys: &usedRowKeys
        )

        return (resolvedHome, resolvedAway)
    }

    private static func uiResolveRow(
        expectedTeamName: String,
        preferredRow: RigaClassificaDTO?,
        candidates: [RigaClassificaDTO],
        usedRowKeys: inout Set<String>
    ) -> RigaClassificaDTO? {
        guard !candidates.isEmpty else { return preferredRow }

        let expectedCanonical = uiCanonicalTeamName(expectedTeamName)
        let expectedLoose = uiLooseNormalizedTeamName(expectedTeamName)

        let scoredCandidates = candidates
            .filter { !usedRowKeys.contains(uiRowKey(for: $0)) }
            .map { row -> (row: RigaClassificaDTO, score: Double) in
                var score = uiTeamMatchScore(
                    expectedCanonical: expectedCanonical,
                    expectedLoose: expectedLoose,
                    candidateTeamName: row.team
                )

                if let preferredRow {
                    if !preferredRow.teamId.isEmpty, preferredRow.teamId == row.teamId {
                        score = max(score, 0.995)
                    } else {
                        score += uiTeamMatchScore(
                            expectedCanonical: uiCanonicalTeamName(preferredRow.team),
                            expectedLoose: uiLooseNormalizedTeamName(preferredRow.team),
                            candidateTeamName: row.team
                        ) * 0.08
                    }
                }

                return (row, min(score, 1))
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.row.position < rhs.row.position
                }
                return lhs.score > rhs.score
            }

        guard let bestMatch = scoredCandidates.first else {
            return preferredRow
        }

        let minimumScore = expectedCanonical.isEmpty ? 0.70 : 0.48
        guard bestMatch.score >= minimumScore else {
            return preferredRow
        }

        usedRowKeys.insert(uiRowKey(for: bestMatch.row))
        return bestMatch.row
    }

    private static func uiTeamMatchScore(
        expectedCanonical: String,
        expectedLoose: String,
        candidateTeamName: String
    ) -> Double {
        let candidateCanonical = uiCanonicalTeamName(candidateTeamName)
        let candidateLoose = uiLooseNormalizedTeamName(candidateTeamName)

        let canonicalScore = uiSimilarityScore(expectedCanonical, candidateCanonical)
        let looseScore = uiSimilarityScore(expectedLoose, candidateLoose)
        return max(canonicalScore, looseScore)
    }

    private static func uiSimilarityScore(_ lhs: String, _ rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        if lhs == rhs { return 1 }
        if lhs.contains(rhs) || rhs.contains(lhs) { return 0.95 }

        let lhsTokens = Set(lhs.split(separator: " ").map(String.init))
        let rhsTokens = Set(rhs.split(separator: " ").map(String.init))
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else { return 0 }

        let intersectionScore = Double(lhsTokens.intersection(rhsTokens).count) / Double(max(lhsTokens.count, rhsTokens.count))
        let union = lhsTokens.union(rhsTokens)
        let jaccardScore = union.isEmpty ? 0 : Double(lhsTokens.intersection(rhsTokens).count) / Double(union.count)
        return max(intersectionScore, jaccardScore)
    }

    private static func uiLooseNormalizedTeamName(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT"))
            .replacingOccurrences(of: #"\bdilettantistica\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bresponsabilita\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\blimitata\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bsrls?\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\barl\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func uiCanonicalTeamName(_ value: String) -> String {
        let scrubbed = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT"))
            .replacingOccurrences(of: #"\bunder[\s\-]?1[56789]\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bu[\s\-]?1[56789]\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bjuniores?\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\ballievi\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bgiovanissimi\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\belite\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bprovinciali?\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bregionali?\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bdilettantistica\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bresponsabilita\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\blimitata\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\bsrls?\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\barl\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)

        let stopwords: Set<String> = [
            "a", "s", "d", "asd", "ssd", "societa", "sportiva", "sporting",
            "polisportiva", "polis", "club", "team", "fc", "fcd", "ac", "sc",
            "us", "usd", "u", "calcio"
        ]

        let tokens = scrubbed
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                let isNumeric = token.allSatisfy { $0.isNumber }
                guard !token.isEmpty else { return false }
                if stopwords.contains(token) {
                    return false
                }
                if token.count == 1 && !isNumeric {
                    return false
                }
                return true
            }

        return tokens.joined(separator: " ")
    }

    private static func uiRowKey(for row: RigaClassificaDTO) -> String {
        row.teamId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? row.id
            : row.teamId.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ClassificaConfrontoEssenzialeView: View {
    let homeTeam: String
    let awayTeam: String
    let homeRow: RigaClassificaDTO?
    let awayRow: RigaClassificaDTO?

    private var confrontoLabel: String {
        guard let homeRow, let awayRow else {
            return "Confronto ufficiale del girone"
        }

        if homeRow.points == awayRow.points {
            let posDiff = abs(homeRow.position - awayRow.position)
            if posDiff == 0 {
                return "Le due squadre sono appaiate in classifica"
            }
            return "Pari punti con \(posDiff) \(posDiff == 1 ? "posizione" : "posizioni") di distanza"
        }

        let diff = abs(homeRow.points - awayRow.points)
        let leader = homeRow.points > awayRow.points ? "Casa" : "Ospite"
        return "\(leader) avanti di \(diff) \(diff == 1 ? "punto" : "punti")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Confronto diretto")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(confrontoLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DettaglioGaraPalette.accent)
            }

            ViewThatFits(in: .vertical) {
                HStack(spacing: 12) {
                    ClassificaConfrontoHeaderView(
                        teamName: homeTeam,
                        row: homeRow,
                        alignTrailing: false
                    )

                    ClassificaConfrontoHeaderView(
                        teamName: awayTeam,
                        row: awayRow,
                        alignTrailing: true
                    )
                }

                VStack(spacing: 12) {
                    ClassificaConfrontoHeaderView(
                        teamName: homeTeam,
                        row: homeRow,
                        alignTrailing: false
                    )

                    ClassificaConfrontoHeaderView(
                        teamName: awayTeam,
                        row: awayRow,
                        alignTrailing: true
                    )
                }
            }

            if let homeRow, let awayRow {
                ClassificaMetricheConfrontoView(
                    homeRow: homeRow,
                    awayRow: awayRow
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DettaglioGaraPalette.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct ClassificaConfrontoHeaderView: View {
    let teamName: String
    let row: RigaClassificaDTO?
    let alignTrailing: Bool

    private var officialName: String {
        let fallback = testoRipulitoPerUI(teamName)
        guard let row else { return fallback }
        let resolved = testoRipulitoPerUI(row.team)
        return resolved.isEmpty ? fallback : resolved
    }

    private var logoURL: URL? {
        TuttocampoTeamLogoStore.logoURL(
            for: row,
            fallbackTeamName: teamName,
            size: 40
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            if alignTrailing {
                Spacer(minLength: 0)
            }

            if !alignTrailing {
                DettaglioGaraTeamLogoView(
                    teamName: officialName,
                    logoURL: logoURL,
                    size: 28
                )
            }

            Text(officialName)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(alignTrailing ? .trailing : .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            if alignTrailing {
                DettaglioGaraTeamLogoView(
                    teamName: officialName,
                    logoURL: logoURL,
                    size: 28
                )
            }

            if !alignTrailing {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: alignTrailing ? .trailing : .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DettaglioGaraPalette.inlineSurface)
        )
    }
}

private struct ClassificaTabellaEssenzialeView: View {
    let rows: [RigaClassificaDTO]
    let homeRow: RigaClassificaDTO?
    let awayRow: RigaClassificaDTO?
    @State private var selectedRowID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Classifica")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Tocca una squadra per aprire la scheda completa.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DettaglioGaraPalette.textMuted)
            }

            VStack(alignment: .leading, spacing: 8) {
                RigaHeaderClassificaEssenzialeView()
                    .padding(.top, 4)

                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        RigaClassificaEssenzialeView(
                            row: row,
                            isHighlighted: row.id == homeRow?.id || row.id == awayRow?.id,
                            isSelected: row.id == selectedRowID,
                            onTap: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                    if selectedRowID == row.id {
                                        selectedRowID = nil
                                    } else {
                                        selectedRowID = row.id
                                    }
                                }
                            }
                        )

                        if selectedRowID == row.id {
                            ClassificaSquadraDettaglioCardView(
                                row: row,
                                isHighlighted: row.id == homeRow?.id || row.id == awayRow?.id
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RigaHeaderClassificaEssenzialeView: View {
    var body: some View {
        HStack(spacing: 6) {
            header("Pos", width: 28, alignment: .center)
            header("Squadra", width: nil, alignment: .leading)
            header("Pt", width: 28, alignment: .trailing)
            header("G", width: 22, alignment: .trailing)
            header("V", width: 22, alignment: .trailing)
            header("N", width: 22, alignment: .trailing)
            header("P", width: 22, alignment: .trailing)
            header("DR", width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 12)
    }

    private func header(_ text: String, width: CGFloat?, alignment: Alignment) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(DettaglioGaraPalette.textSoft)
            .frame(maxWidth: width == nil ? .infinity : width, alignment: alignment)
            .frame(width: width, alignment: alignment)
    }
}

private struct RigaClassificaEssenzialeView: View {
    let row: RigaClassificaDTO
    let isHighlighted: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private var logoURL: URL? {
        TuttocampoTeamLogoStore.logoURL(
            for: row,
            fallbackTeamName: row.team,
            size: 40
        )
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("\(row.position)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isHighlighted ? .white : Color.white.opacity(0.82))
                .monospacedDigit()
                .frame(width: 28, alignment: .center)

            HStack(spacing: 10) {
                DettaglioGaraTeamLogoView(
                    teamName: row.team,
                    logoURL: logoURL,
                    size: 22
                )

                Text(row.team)
                    .font(.system(size: 12, weight: isHighlighted ? .bold : .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            value("\(row.points)", width: 28)
            value("\(row.played)", width: 22)
            value("\(row.won)", width: 22)
            value("\(row.draw)", width: 22)
            value("\(row.lost)", width: 22)
            value(segnoDifferenza(row.goalDiff), width: 30)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    isSelected
                    ? Color.white.opacity(0.085)
                    : (isHighlighted ? DettaglioGaraPalette.accentSoft : Color.white.opacity(0.035))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected
                    ? Color.white.opacity(0.18)
                    : (isHighlighted ? DettaglioGaraPalette.accent.opacity(0.26) : Color.white.opacity(0.05)),
                    lineWidth: 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onTap)
    }

    private func value(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.88))
            .monospacedDigit()
            .frame(width: width, alignment: .trailing)
    }
}

private struct ClassificaSquadraDettaglioCardView: View {
    let row: RigaClassificaDTO
    let isHighlighted: Bool

    private var logoURL: URL? {
        TuttocampoTeamLogoStore.logoURL(
            for: row,
            fallbackTeamName: row.team,
            size: 40
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                DettaglioGaraTeamLogoView(
                    teamName: row.team,
                    logoURL: logoURL,
                    size: 38
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(row.team)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Dati squadra")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DettaglioGaraPalette.textMuted)
                }

                Spacer(minLength: 0)

                Text("#\(row.position)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isHighlighted ? DettaglioGaraPalette.accentSoft : Color.white.opacity(0.06))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                isHighlighted ? DettaglioGaraPalette.accent.opacity(0.18) : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            }

            HStack(spacing: 8) {
                ClassificaSquadraDettaglioCompactStatView(title: "Pt", value: "\(row.points)")
                ClassificaSquadraDettaglioCompactStatView(title: "G", value: "\(row.played)")
                ClassificaSquadraDettaglioCompactStatView(title: "V", value: "\(row.won)")
                ClassificaSquadraDettaglioCompactStatView(title: "N", value: "\(row.draw)")
            }

            HStack(spacing: 8) {
                ClassificaSquadraDettaglioCompactStatView(title: "P", value: "\(row.lost)")
                ClassificaSquadraDettaglioCompactStatView(title: "DR", value: segnoDifferenza(row.goalDiff))
                ClassificaSquadraDettaglioCompactStatView(title: "GF", value: "\(row.goalsFor)")
                ClassificaSquadraDettaglioCompactStatView(title: "GS", value: "\(row.goalsAgainst)")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DettaglioGaraPalette.surface)
        )
        .background(
            LinearGradient(
                colors: [
                    isHighlighted ? DettaglioGaraPalette.accent.opacity(0.14) : Color.white.opacity(0.06),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isHighlighted ? DettaglioGaraPalette.accent.opacity(0.22) : DettaglioGaraPalette.borderSoft,
                    lineWidth: 1
                )
        )
    }
}

private struct ClassificaSquadraDettaglioCompactStatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DettaglioGaraPalette.textSoft)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct ClassificaContestoCardView: View {
    let classifica: ClassificaGaraDTO

    private var competitionText: String {
        let raw = classifica.competitionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "Girone ufficiale" : raw
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(competitionText)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                ClassificaContestoBadgeView(
                    icon: "checkmark.seal.fill",
                    value: "Tuttocampo"
                )
            }

            ViewThatFits(in: .vertical) {
                HStack(spacing: 10) {
                    if !classifica.areaLabel.isEmpty {
                        ClassificaContestoBadgeView(
                            icon: "mappin.and.ellipse",
                            value: classifica.areaLabel
                        )
                    }

                    ClassificaContestoBadgeView(
                        icon: "list.number",
                        value: "\(classifica.rows.count) squadre"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    if !classifica.areaLabel.isEmpty {
                        ClassificaContestoBadgeView(
                            icon: "mappin.and.ellipse",
                            value: classifica.areaLabel
                        )
                    }

                    ClassificaContestoBadgeView(
                        icon: "list.number",
                        value: "\(classifica.rows.count) squadre"
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DettaglioGaraPalette.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct ClassificaContestoBadgeView: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DettaglioGaraPalette.accent)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.84)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DettaglioGaraPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct ClassificaConfrontoBoardView: View {
    let homeTeam: String
    let awayTeam: String
    let homeRow: RigaClassificaDTO?
    let awayRow: RigaClassificaDTO?

    private var confrontoLabel: String {
        guard let homeRow, let awayRow else {
            return "Confronto ufficiale del girone"
        }

        if homeRow.points == awayRow.points {
            let posDiff = abs(homeRow.position - awayRow.position)
            if posDiff == 0 {
                return "Le due squadre sono appaiate in classifica"
            }
            return "Pari punti con \(posDiff) \(posDiff == 1 ? "posizione" : "posizioni") di distanza"
        }

        let diff = abs(homeRow.points - awayRow.points)
        let leader = homeRow.points > awayRow.points ? "Casa" : "Ospite"
        return "\(leader) avanti di \(diff) \(diff == 1 ? "punto" : "punti")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(confrontoLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DettaglioGaraPalette.accent)

            ViewThatFits(in: .vertical) {
                HStack(spacing: 12) {
                    ClassificaGaraSquadraRowView(
                        roleTitle: "Casa",
                        expectedName: homeTeam,
                        row: homeRow
                    )

                    ClassificaGaraSquadraRowView(
                        roleTitle: "Ospite",
                        expectedName: awayTeam,
                        row: awayRow
                    )
                }

                VStack(spacing: 12) {
                    ClassificaGaraSquadraRowView(
                        roleTitle: "Casa",
                        expectedName: homeTeam,
                        row: homeRow
                    )

                    ClassificaGaraSquadraRowView(
                        roleTitle: "Ospite",
                        expectedName: awayTeam,
                        row: awayRow
                    )
                }
            }

            if let homeRow, let awayRow {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Confronto diretto")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DettaglioGaraPalette.textSoft)

                    ClassificaMetricheConfrontoView(
                        homeRow: homeRow,
                        awayRow: awayRow
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DettaglioGaraPalette.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct ClassificaGaraSquadraRowView: View {
    let roleTitle: String
    let expectedName: String
    let row: RigaClassificaDTO?

    private var teamName: String {
        let officialName = row?.team ?? ""
        return officialName.isEmpty ? testoRipulitoPerUI(expectedName) : testoRipulitoPerUI(officialName)
    }

    private var fallbackName: String? {
        guard let row else { return nil }
        let official = testoRipulitoPerUI(row.team).lowercased()
        let expected = testoRipulitoPerUI(expectedName).lowercased()
        guard !official.isEmpty, official != expected else { return nil }
        return testoRipulitoPerUI(expectedName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(roleTitle.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DettaglioGaraPalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(DettaglioGaraPalette.accentSoft)
                    )

                Spacer(minLength: 8)

                if let row {
                    Text("#\(row.position)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(DettaglioGaraPalette.inlineSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(teamName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if let fallbackName {
                    Text(fallbackName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DettaglioGaraPalette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                ClassificaSquadraInfoChipView(
                    title: "Pt",
                    value: row.map { "\($0.points)" } ?? "-"
                )
                ClassificaSquadraInfoChipView(
                    title: "G",
                    value: row.map { "\($0.played)" } ?? "-"
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DettaglioGaraPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct ClassificaSquadraInfoChipView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DettaglioGaraPalette.textSoft)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DettaglioGaraPalette.surfaceSoft)
        )
    }
}

private struct ClassificaMetricheConfrontoView: View {
    let homeRow: RigaClassificaDTO
    let awayRow: RigaClassificaDTO

    var body: some View {
        VStack(spacing: 10) {
            ClassificaConfrontoRigaView(
                title: "Posizione",
                homeValue: "#\(homeRow.position)",
                awayValue: "#\(awayRow.position)"
            )
            ClassificaConfrontoRigaView(
                title: "Punti",
                homeValue: "\(homeRow.points)",
                awayValue: "\(awayRow.points)"
            )
            ClassificaConfrontoRigaView(
                title: "Partite",
                homeValue: "\(homeRow.played)",
                awayValue: "\(awayRow.played)"
            )
            ClassificaConfrontoRigaView(
                title: "Vittorie",
                homeValue: "\(homeRow.won)",
                awayValue: "\(awayRow.won)"
            )
            ClassificaConfrontoRigaView(
                title: "Pareggi",
                homeValue: "\(homeRow.draw)",
                awayValue: "\(awayRow.draw)"
            )
            ClassificaConfrontoRigaView(
                title: "Sconfitte",
                homeValue: "\(homeRow.lost)",
                awayValue: "\(awayRow.lost)"
            )
            ClassificaConfrontoRigaView(
                title: "Diff. reti",
                homeValue: segnoDifferenza(homeRow.goalDiff),
                awayValue: segnoDifferenza(awayRow.goalDiff)
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DettaglioGaraPalette.inlineSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct ClassificaConfrontoRigaView: View {
    let title: String
    let homeValue: String
    let awayValue: String

    var body: some View {
        HStack(spacing: 12) {
            Text(homeValue)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DettaglioGaraPalette.textSoft)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(awayValue)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct AnteprimaClassificaGironeView: View {
    let rows: [RigaClassificaDTO]
    let homeRow: RigaClassificaDTO?
    let awayRow: RigaClassificaDTO?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Panoramica girone")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Estratto ufficiale del girone con focus sulle due squadre della gara.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DettaglioGaraPalette.textMuted)
            }

            if homeRow != nil || awayRow != nil {
                PanoramicaGironeSintesiBoardView(
                    homeRow: homeRow,
                    awayRow: awayRow
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    RigaHeaderClassificaView()
                        .padding(.top, 4)

                    ForEach(rows) { row in
                        RigaClassificaView(
                            row: row,
                            isHighlighted: row.id == homeRow?.id || row.id == awayRow?.id
                        )
                    }
                }
                .padding(12)
                .frame(minWidth: 580, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(DettaglioGaraPalette.inlineSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
                )
            }

            if homeRow != nil || awayRow != nil {
                Text("Casa e ospite restano evidenziate nella tabella del girone.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.54))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DettaglioGaraPalette.surfaceSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct PanoramicaGironeSintesiBoardView: View {
    let homeRow: RigaClassificaDTO?
    let awayRow: RigaClassificaDTO?

    private var gapText: String? {
        guard let homeRow, let awayRow else { return nil }
        let pointsDiff = abs(homeRow.points - awayRow.points)
        if pointsDiff == 0 {
            return "Stessi punti"
        }
        return "\(pointsDiff) \(pointsDiff == 1 ? "punto" : "punti") di distanza"
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: 0) {
                if let homeRow {
                    PanoramicaGironeSintesiColonnaView(
                        title: "Casa",
                        row: homeRow
                    )
                }

                if homeRow != nil && awayRow != nil {
                    Divider()
                        .overlay(DettaglioGaraPalette.borderSoft)
                        .padding(.vertical, 6)
                }

                if let gapText {
                    PanoramicaGironeSintesiDeltaView(text: gapText)
                }

                if homeRow != nil && awayRow != nil {
                    Divider()
                        .overlay(DettaglioGaraPalette.borderSoft)
                        .padding(.vertical, 6)
                }

                if let awayRow {
                    PanoramicaGironeSintesiColonnaView(
                        title: "Ospite",
                        row: awayRow
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DettaglioGaraPalette.inlineSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
            )

            VStack(spacing: 10) {
                if let homeRow {
                    PanoramicaGironeSintesiColonnaView(
                        title: "Casa",
                        row: homeRow
                    )
                }

                if let gapText {
                    PanoramicaGironeSintesiDeltaView(text: gapText)
                }

                if let awayRow {
                    PanoramicaGironeSintesiColonnaView(
                        title: "Ospite",
                        row: awayRow
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DettaglioGaraPalette.inlineSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DettaglioGaraPalette.borderSoft, lineWidth: 1)
            )
        }
    }
}

private struct PanoramicaGironeSintesiColonnaView: View {
    let title: String
    let row: RigaClassificaDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DettaglioGaraPalette.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(testoRipulitoPerUI(row.team))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    PanoramicaGironeStatPillView(
                        title: "Pos",
                        value: "#\(row.position)"
                    )
                    PanoramicaGironeStatPillView(
                        title: "Pt",
                        value: "\(row.points)"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PanoramicaGironeStatPillView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DettaglioGaraPalette.textSoft)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DettaglioGaraPalette.surfaceSoft)
        )
    }
}

private struct PanoramicaGironeSintesiDeltaView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(DettaglioGaraPalette.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 110)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
    }
}

private struct SchedaClassificaLoadingView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Color(hex: 0x9DCAFF))

            VStack(alignment: .leading, spacing: 4) {
                Text("Classifica gara")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Sto leggendo la classifica ufficiale del girone.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DettaglioGaraPalette.textMuted)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DettaglioGaraPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DettaglioGaraPalette.border, lineWidth: 1)
        )
    }
}

private struct RigaHeaderClassificaView: View {
    var body: some View {
        HStack(spacing: 8) {
            header("Pos", width: 34, alignment: .center)
            header("Squadra", width: nil, alignment: .leading)
            header("Pt", width: 34, alignment: .trailing)
            header("G", width: 28, alignment: .trailing)
            header("V", width: 28, alignment: .trailing)
            header("N", width: 28, alignment: .trailing)
            header("P", width: 28, alignment: .trailing)
            header("GF", width: 34, alignment: .trailing)
            header("GS", width: 34, alignment: .trailing)
            header("DR", width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 12)
    }

    private func header(_ text: String, width: CGFloat?, alignment: Alignment) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(DettaglioGaraPalette.textSoft)
            .frame(maxWidth: width == nil ? .infinity : width, alignment: alignment)
            .frame(width: width, alignment: alignment)
    }
}

private struct RigaClassificaView: View {
    let row: RigaClassificaDTO
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("\(row.position)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isHighlighted ? .white : Color.white.opacity(0.82))
                .monospacedDigit()
                .frame(width: 34, alignment: .center)

            Text(row.team)
                .font(.system(size: 13, weight: isHighlighted ? .bold : .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)

            value("\(row.points)", width: 34)
            value("\(row.played)", width: 28)
            value("\(row.won)", width: 28)
            value("\(row.draw)", width: 28)
            value("\(row.lost)", width: 28)
            value("\(row.goalsFor)", width: 34)
            value("\(row.goalsAgainst)", width: 34)
            value(segnoDifferenza(row.goalDiff), width: 38)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isHighlighted ? DettaglioGaraPalette.accentSoft : Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isHighlighted ? DettaglioGaraPalette.accent.opacity(0.26) : Color.white.opacity(0.05),
                    lineWidth: 1
                )
        )
    }

    private func value(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.88))
            .monospacedDigit()
            .frame(width: width, alignment: .trailing)
    }
}

private struct SchedaClassificaNonDisponibileView: View {
    let messaggio: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Classifica gara")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(messaggio)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.68))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DettaglioGaraPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DettaglioGaraPalette.border, lineWidth: 1)
        )
    }
}

private func segnoDifferenza(_ value: Int) -> String {
    value > 0 ? "+\(value)" : "\(value)"
}

private struct SchedaRepartoView: View {
    let modulo: RepartoSintesiDTO

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: modulo.systemIcon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(hex: 0x8DBDFF))
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(modulo.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(modulo.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.42))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
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

private struct CardHighlightView: View {
    let highlight: HighlightModuloDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(highlight.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.58))

            Text(highlight.value.isEmpty ? "-" : highlight.value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct CardOpzioniView: View {
    let gruppo: GruppoOpzioniModuloDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(gruppo.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(gruppo.options) { option in
                    Text(option.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xD6E7FF))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
            }
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

private struct RigaModuloCardView: View {
    let token: String
    let row: RigaModuloDTO

    private let apiClient = APIClient.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title.isEmpty ? "-" : row.title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if !row.subtitle.isEmpty {
                        Text(row.subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.64))
                    }
                }

                Spacer()

                if !row.status.isEmpty {
                    Text(row.status)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(hex: 0x225EAE).opacity(0.65))
                        )
                }
            }

            if !row.fields.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(row.fields) { field in
                        if !field.value.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(field.label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.55))
                                Text(field.value)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            if !row.attachments.isEmpty {
                HStack(spacing: 10) {
                    ForEach(row.attachments) { attachment in
                        TicketedDownloadLink {
                            await urlAllegato(attachment)
                        } label: {
                            Label(attachment.label, systemImage: "paperclip")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color(hex: 0x1C4C89).opacity(0.72))
                                )
                        }
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
