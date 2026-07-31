import SwiftUI

// Io ho isolato qui la lista referti con tutti i componenti UI collegati.
// In questo modo quando devo rifinire il menu referti non tocco le altre aree dei reparti.
struct VistaListaReferti: View {
    let token: String
    let snapshot: SnapshotModuloDTO
    let inAggiornamento: Bool
    let onAggiornaPeriodo: (_ dateFrom: String, _ dateTo: String) async -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var periodoDaSelezionato = Date()
    @State private var periodoASelezionato = Date()
    @State private var chiavePeriodoCorrente = ""

    private var rows: [RigaModuloDTO] { snapshot.rows }

    private var periodoDa: String {
        valoreHighlight("periodo da")
    }

    private var periodoA: String {
        valoreHighlight("periodo a")
    }

    private var daCompilare: Int {
        rows.filter { ($0.actionKind ?? "").lowercased() == "compile" }.count
    }

    private var inviati: Int {
        rows.filter { ($0.actionKind ?? "").lowercased() == "review" }.count
    }

    private var periodoValido: Bool {
        periodoDaSelezionato <= periodoASelezionato
    }

    private var avvisoPortale: String {
        testoRipulitoPerUI(snapshot.introText)
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardTitoloView(
                titolo: "Gestione Referti",
                sottotitolo: "Consulta, compila o modifica i referti del periodo selezionato."
            )

            RefertiPanoramicaCardView(
                totale: rows.count,
                daCompilare: daCompilare,
                inviati: inviati,
                periodoLabel: "\(periodoDa) - \(periodoA)",
                avvisoPortale: avvisoPortale
            )

            RefertiSectionCard(
                titolo: "Filtro periodo",
                sottotitolo: "Scegli il periodo e aggiorna l'elenco."
            ) {
                filtroPeriodo
            }

            if rows.isEmpty {
                StatoVuotoView(
                    titolo: "Nessun referto nel periodo",
                    messaggio: "L'elenco mostra il mese mobile corrente. Quando avrai gare da compilare o referti già inviati, li vedrai qui con tutti i dettagli utili."
                )
            } else {
                RefertiSectionCard(
                    titolo: "Referti del periodo",
                    sottotitolo: "\(rows.count) gare nel periodo selezionato"
                ) {
                    LazyVStack(spacing: 10) {
                        ForEach(rows) { row in
                            NavigationLink {
                                VistaDettaglioReferto(
                                    token: token,
                                    designazioneId: row.id,
                                    titolo: row.title,
                                    onAssistantFlowCompleted: {
                                        Task {
                                            await onAggiornaPeriodo(
                                                Self.formattedPortalDate(periodoDaSelezionato),
                                                Self.formattedPortalDate(periodoASelezionato)
                                            )
                                        }
                                    }
                                )
                            } label: {
                                RigaRefertoCardView(row: row)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear {
            sincronizzaPeriodoConSnapshot()
        }
        .onChange(of: chiavePeriodoSnapshot) {
            sincronizzaPeriodoConSnapshot()
        }
    }

    private func valoreHighlight(_ label: String) -> String {
        snapshot.highlights.first { $0.label.lowercased().contains(label) }?.value ?? "—"
    }

    private var filtroPeriodo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Intervallo attivo")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.56))

            Text(periodoSelezionatoLabel)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: quickRangeColumns, spacing: 8) {
                RefertiQuickRangeButtonView(
                    titolo: "Periodo portale",
                    icona: "sparkles.rectangle.stack",
                    prominent: false
                ) {
                    sincronizzaPeriodoPredefinito()
                }
                RefertiQuickRangeButtonView(
                    titolo: "Ultimi 7 giorni",
                    icona: "calendar",
                    prominent: false
                ) {
                    applicaIntervalloRapido(giorni: 7)
                }
                RefertiQuickRangeButtonView(
                    titolo: "Ultimi 30 giorni",
                    icona: "calendar.badge.clock",
                    prominent: false
                ) {
                    applicaIntervalloRapido(giorni: 30)
                }
                RefertiQuickRangeButtonView(
                    titolo: "Oggi",
                    icona: "sun.max.fill",
                    prominent: false
                ) {
                    applicaIntervalloRapido(giorni: 1)
                }
            }

            Group {
                if isCompactLayout {
                    VStack(spacing: 10) {
                        RefertiDatePickerCardView(
                            titolo: "Periodo da",
                            icona: "calendar.badge.minus",
                            selection: $periodoDaSelezionato
                        )
                        RefertiDatePickerCardView(
                            titolo: "Periodo a",
                            icona: "calendar.badge.plus",
                            selection: $periodoASelezionato
                        )
                    }
                } else {
                    HStack(spacing: 10) {
                        RefertiDatePickerCardView(
                            titolo: "Periodo da",
                            icona: "calendar.badge.minus",
                            selection: $periodoDaSelezionato
                        )
                        RefertiDatePickerCardView(
                            titolo: "Periodo a",
                            icona: "calendar.badge.plus",
                            selection: $periodoASelezionato
                        )
                    }
                }
            }

            if isCompactLayout {
                VStack(spacing: 10) {
                    pulsanteAggiorna
                    pulsanteRipristina
                }
            } else {
                HStack(spacing: 10) {
                    pulsanteAggiorna
                    pulsanteRipristina
                }
            }

            if !periodoValido {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Il periodo non è valido: la data iniziale deve essere precedente o uguale alla data finale.")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .foregroundStyle(Color(hex: 0xFFB4B4))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: 0x57212A).opacity(0.55))
                )
            }
        }
    }

    private var chiavePeriodoSnapshot: String {
        "\(periodoDa)|\(periodoA)"
    }

    private var quickRangeColumns: [GridItem] {
        if isCompactLayout {
            return [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]
        }
        return [GridItem(.adaptive(minimum: 150), spacing: 8)]
    }

    private var periodoSelezionatoLabel: String {
        "\(Self.formattedPortalDate(periodoDaSelezionato)) - \(Self.formattedPortalDate(periodoASelezionato))"
    }

    private func sincronizzaPeriodoConSnapshot() {
        guard chiavePeriodoCorrente != chiavePeriodoSnapshot else { return }
        periodoDaSelezionato = Self.parsedPortalDate(periodoDa) ?? Self.defaultStartDate()
        periodoASelezionato = Self.parsedPortalDate(periodoA) ?? Date()
        chiavePeriodoCorrente = chiavePeriodoSnapshot
    }

    private func sincronizzaPeriodoPredefinito() {
        periodoDaSelezionato = Self.parsedPortalDate(periodoDa) ?? Self.defaultStartDate()
        periodoASelezionato = Self.parsedPortalDate(periodoA) ?? Date()
    }

    private func applicaIntervalloRapido(giorni: Int) {
        let intervallo = max(1, giorni)
        let calendar = Calendar(identifier: .gregorian)
        let fine = Date()
        let inizio = calendar.date(byAdding: .day, value: -(intervallo - 1), to: fine) ?? fine
        periodoDaSelezionato = inizio
        periodoASelezionato = fine
    }

    private static func parsedPortalDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.date(from: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func formattedPortalDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    private static func defaultStartDate() -> Date {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    }

    private var pulsanteRipristina: some View {
        Button {
            sincronizzaPeriodoPredefinito()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .bold))
                Text("Ripristina")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var pulsanteAggiorna: some View {
        Button {
            Task {
                await onAggiornaPeriodo(
                    Self.formattedPortalDate(periodoDaSelezionato),
                    Self.formattedPortalDate(periodoASelezionato)
                )
            }
        } label: {
            HStack(spacing: 8) {
                if inAggiornamento {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                }

                Text(inAggiornamento ? "Aggiornamento..." : "Aggiorna referti")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x3F9BFF), Color(hex: 0x195BBC)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!periodoValido || inAggiornamento)
        .opacity((!periodoValido || inAggiornamento) ? 0.55 : 1)
    }
}

private struct RefertiDatePickerCardView: View {
    let titolo: String
    let icona: String
    @Binding var selection: Date

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: icona)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0x9BC7FF))
                Text(titolo)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            DatePicker(
                "",
                selection: $selection,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(.white)
            .colorScheme(.dark)
            .environment(\.locale, Locale(identifier: "it_IT"))
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        )
    }
}

private struct RefertiQuickRangeButtonView: View {
    let titolo: String
    let icona: String
    let prominent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icona)
                    .font(.system(size: 11, weight: .bold))
                Text(titolo)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(prominent ? Color.white : Color.white.opacity(0.88))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        prominent
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [Color(hex: 0x3F9BFF), Color(hex: 0x195BBC)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        : AnyShapeStyle(Color.white.opacity(0.08))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RefertiSectionCard<Content: View>: View {
    let titolo: String
    let sottotitolo: String
    let content: Content

    init(
        titolo: String,
        sottotitolo: String,
        @ViewBuilder content: () -> Content
    ) {
        self.titolo = titolo
        self.sottotitolo = sottotitolo
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titolo)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if !sottotitolo.isEmpty {
                    Text(sottotitolo)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x143C78).opacity(0.88),
                            Color(hex: 0x0E284E).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct RefertiPanoramicaCardView: View {
    let totale: Int
    let daCompilare: Int
    let inviati: Int
    let periodoLabel: String
    let avvisoPortale: String

    var body: some View {
        RefertiSectionCard(
            titolo: "Panoramica",
            sottotitolo: "Stato reale dei referti nel periodo mostrato dal portale."
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                RefertiOverviewMetricView(
                    label: "Da compilare",
                    value: "\(daCompilare)",
                    icon: "square.and.pencil",
                    tint: Color(hex: 0x35C877)
                )
                RefertiOverviewMetricView(
                    label: "Inviati",
                    value: "\(inviati)",
                    icon: "checkmark.seal.fill",
                    tint: Color(hex: 0x4AA6FF)
                )
                RefertiOverviewMetricView(
                    label: "Totali",
                    value: "\(totale)",
                    icon: "number.square",
                    tint: Color(hex: 0xB7DEFF)
                )
                RefertiOverviewMetricView(
                    label: "Periodo",
                    value: periodoLabel,
                    icon: "calendar.badge.clock",
                    tint: Color(hex: 0x9BC7FF),
                    compactValue: true
                )
            }

            if !avvisoPortale.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFFD37A))
                        .padding(.top, 1)

                    Text(avvisoPortale)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(hex: 0x4D3A17).opacity(0.46))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(hex: 0xFFD37A).opacity(0.28), lineWidth: 1)
                )
            }
        }
    }
}

private struct RefertiOverviewMetricView: View {
    let label: String
    let value: String
    let icon: String
    let tint: Color
    var compactValue = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.56))
            }

            Text(value)
                .font(.system(size: compactValue ? 14 : 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct RigaRefertoCardView: View {
    let row: RigaModuloDTO

    private var actionKind: String {
        testoRipulitoPerUI(row.actionKind ?? "").lowercased()
    }

    private var roleKind: String {
        testoRipulitoPerUI(row.roleKind ?? "").lowercased()
    }

    private var roleLabel: String {
        let candidate = testoRipulitoPerUI(row.roleLabel ?? "")
        if !candidate.isEmpty {
            return candidate
        }
        return valoreCampo(matching: ["ruolo"])
    }

    private var category: String {
        valoreCampo(matching: ["categoria"])
    }

    private var group: String {
        valoreCampo(matching: ["girone"])
    }

    private var giornata: String {
        valoreCampo(matching: ["giornata"])
    }

    private var matchNumber: String {
        valoreCampo(matching: ["numero"])
    }

    private var actionLabel: String {
        let candidate = testoRipulitoPerUI(row.actionLabel ?? "")
        if !candidate.isEmpty {
            return candidate
        }
        switch actionKind {
        case "resume":
            return "Modifica referto"
        case "compile":
            return "Compila referto"
        default:
            return "Consulta referto"
        }
    }

    private var competitionLine: String {
        [category, group, giornata]
            .map { testoRipulitoPerUI($0) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var dataOraLine: String {
        testoRipulitoPerUI(row.subtitle)
    }

    private var stateText: String {
        if !row.status.isEmpty {
            return row.status
        }
        switch actionKind {
        case "resume":
            return "Bozza salvata"
        case "compile":
            return "Da compilare"
        default:
            return "Già compilato"
        }
    }

    private var actionIcon: String {
        switch actionKind {
        case "resume":
            return "pencil.circle.fill"
        case "compile":
            return "plus.circle.fill"
        case "review":
            return "info.circle.fill"
        default:
            return "doc.text"
        }
    }

    private var actionButtonColor: Color {
        switch actionKind {
        case "resume":
            return Color(hex: 0x2E7BE0)
        case "compile":
            return Color(hex: 0x2A8E63)
        case "review":
            return Color(hex: 0x2D6CC4)
        default:
            return Color.white.opacity(0.18)
        }
    }

    private var stateTint: Color {
        switch actionKind {
        case "resume":
            return Color(hex: 0x7FB9FF)
        case "compile":
            return Color(hex: 0x63D9A6)
        case "review":
            return Color(hex: 0x7FB9FF)
        default:
            return Color.white.opacity(0.74)
        }
    }

    private var tipoRefertoLabel: String {
        roleKind == "assistant" ? "Rapporto Assistente" : "Referto Direttore di Gara"
    }

    private var infoItems: [(String, String)] {
        var items: [(String, String)] = []

        if !roleLabel.isEmpty {
            items.append(("Ruolo", roleLabel))
        }
        if !matchNumber.isEmpty {
            items.append(("Gara", "#\(matchNumber)"))
        }
        if !giornata.isEmpty {
            items.append(("Giornata", giornata))
        }
        if !dataOraLine.isEmpty {
            items.append(("Data e ora", dataOraLine))
        }

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tipoRefertoLabel.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.56))
                    Text(row.title.isEmpty ? "-" : row.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if !competitionLine.isEmpty {
                        Text(competitionLine)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                Text(stateText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(stateTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(stateTint.opacity(0.18))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(stateTint.opacity(0.45), lineWidth: 1)
                    )
            }

            if !infoItems.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(infoItems.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.0.uppercased())
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.50))
                            Text(item.1)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: actionIcon)
                    .font(.system(size: 13, weight: .bold))
                Text(actionLabel)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(actionButtonColor)
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x12345F).opacity(0.95), Color(hex: 0x10264A).opacity(0.96)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 5)
    }

    private func valoreCampo(matching labels: [String]) -> String {
        row.fields.first { field in
            let label = testoRipulitoPerUI(field.label).lowercased()
            return labels.contains { label.contains($0) }
        }
        .map { testoRipulitoPerUI($0.value) } ?? ""
    }
}
