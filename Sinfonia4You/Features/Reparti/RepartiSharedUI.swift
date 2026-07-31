import SwiftUI

// Io tengo qui le viste base condivise del reparto:
// quando aggiorno il look generale, cambio una sola volta e riduco regressioni.
struct BloccoTestoView: View {
    let titolo: String
    let testo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titolo)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text(testo)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.76))
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

// Io uso questa card come testata standard delle schermate.
struct CardTitoloView: View {
    let titolo: String
    let sottotitolo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titolo)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if !sottotitolo.isEmpty {
                Text(sottotitolo)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.66))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x0D4C8D), Color(hex: 0x111B36)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// Io mostro sempre questo stato quando il backend non porta contenuti.
struct StatoVuotoView: View {
    let titolo: String
    let messaggio: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color(hex: 0x89B9FF))

            Text(titolo)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text(messaggio)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.68))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

// Io centralizzo il background per mantenere una palette coerente in tutte le viste reparto.
struct SfondoDettaglioRepartoView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x0A1E4D),
                    Color(hex: 0x0C2A63),
                    Color(hex: 0x081735)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(hex: 0x2E7BE0).opacity(0.32),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 440
            )

            RadialGradient(
                colors: [
                    Color(hex: 0x1A94FF).opacity(0.16),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 24,
                endRadius: 360
            )
        }
    }
}

// Io ripulisco qui il testo portale così evito di duplicare normalizzazioni in ogni vista.
func testoRipulitoPerUI(_ raw: String) -> String {
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

// Io trasformo il ruolo in forma leggibile completa per i dettagli.
func ruoloDescrittivo(_ raw: String) -> String {
    var cleaned = testoRipulitoPerUI(raw)
    guard !cleaned.isEmpty else { return "" }

    cleaned = cleaned.replacingOccurrences(
        of: "(?i)\\bn\\s*[°º]\\s*(\\d+)\\b",
        with: "n. $1",
        options: .regularExpression
    )
    cleaned = cleaned.replacingOccurrences(
        of: "(?i)\\bn\\s*\\.\\s*(\\d+)\\b",
        with: "n. $1",
        options: .regularExpression
    )
    cleaned = cleaned.replacingOccurrences(
        of: "(?i)^assistente\\s+dell['’]arbitro",
        with: "Assistente dell'arbitro",
        options: .regularExpression
    )

    return cleaned
}

// Io uso questa versione corta nei badge e nelle card compatte.
func ruoloCompatto(_ raw: String) -> String {
    let shortCode = testoRipulitoPerUI(raw).uppercased()

    switch shortCode {
    case "AA1":
        return "Assistente 1"
    case "AA2":
        return "Assistente 2"
    case "AE", "AR", "ARB":
        return "Arbitro"
    case "OA", "OSS":
        return "Osservatore"
    default:
        break
    }

    let readable = ruoloDescrittivo(raw)
    let lowered = readable.lowercased()

    if lowered.contains("assistente dell'arbitro") {
        let number = readable.replacingOccurrences(
            of: ".*\\bn\\.\\s*(\\d+).*",
            with: "$1",
            options: .regularExpression
        )
        if number != readable {
            return "Assistente \(number)"
        }
        return "Assistente"
    }

    return readable
}

// Io centralizzo qui il mapping categoria per mantenere coerenza tra liste, dettaglio e card.
func categoriaCompleta(_ rawValue: String) -> String {
    let clean = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return clean }

    let upper = clean.uppercased()
    let mapping: [(String, String)] = [
        ("ECC", "Eccellenza"),
        ("PRO", "Promozione"),
        ("PRI", "Prima Categoria"),
        ("SEC", "Seconda Categoria"),
        ("TER", "Terza Categoria"),
        ("JUN", "Juniores"),
        ("ALL", "Allievi"),
        ("GIO", "Giovanissimi"),
        ("CZ3", "Campionato Primavera 3"),
        ("CZ4", "Campionato Primavera 4"),
    ]

    for (code, label) in mapping {
        if upper == code {
            return label
        }
        if upper.hasPrefix(code + " ") {
            let suffix = clean.dropFirst(code.count).trimmingCharacters(in: .whitespaces)
            return suffix.isEmpty ? label : "\(label) \(suffix)"
        }
    }

    return clean
}
