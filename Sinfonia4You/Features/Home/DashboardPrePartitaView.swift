import Combine
import Foundation
import MapKit
import SwiftUI

struct DashboardPrePartitaHomeView: View {
    let token: String
    let gara: GaraHomeDTO
    let onApriGara: (GaraHomeDTO) -> Void

    @StateObject private var viewModel: DashboardPrePartitaViewModel

    init(
        token: String,
        gara: GaraHomeDTO,
        onApriGara: @escaping (GaraHomeDTO) -> Void
    ) {
        self.token = token
        self.gara = gara
        self.onApriGara = onApriGara
        _viewModel = StateObject(
            wrappedValue: DashboardPrePartitaViewModel(apiClient: .shared)
        )
    }

    var body: some View {
        VStack {
            if let payload = viewModel.payload {
                PrePartitaCardView(
                    payload: payload,
                    onOpenDetails: { onApriGara(gara) }
                )
            } else {
                PrePartitaLoadingCard()
            }
        }
        .task(id: gara.idDesignazione + "|" + gara.scheduleLabel) {
            await viewModel.load(token: token, gara: gara)
        }
    }
}

@MainActor
final class DashboardPrePartitaViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var payload: DashboardPrePartitaPayload?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func load(token: String, gara: GaraHomeDTO) async {
        let kickoff = Self.resolveKickoff(for: gara)
        let countdownLabel = kickoff.map(Self.countdownLabel(until:)) ?? "Gara in programma oggi"
        let kickoffLabel = kickoff.map(Self.timeLabel(from:)) ?? Self.fallbackTimeLabel(from: gara)

        isLoading = true

        do {
            let detail = try await apiClient.dettaglioGara(token: token, designazioneId: gara.idDesignazione)
            let locationInfo = Self.parseLocation(
                whereLine: detail.detailFields.whereLine,
                mapsQuery: detail.mapsQuery
            )
            let weather: DashboardMeteoSnapshot?
            if let kickoff {
                weather = await loadWeather(
                    addressQuery: locationInfo.mapsQuery,
                    kickoff: kickoff
                )
            } else {
                weather = nil
            }

            payload = DashboardPrePartitaPayload(
                teams: detail.detailFields.teams.isEmpty ? gara.title : detail.detailFields.teams,
                competition: detail.detailFields.competition.isEmpty ? gara.competitionLabel : detail.detailFields.competition,
                countdownLabel: countdownLabel,
                kickoffLabel: kickoffLabel,
                fieldName: locationInfo.fieldName,
                addressLine: locationInfo.addressLine,
                mapsURL: locationInfo.mapsURL,
                weather: weather
            )
        } catch {
            payload = DashboardPrePartitaPayload(
                teams: gara.title,
                competition: gara.competitionLabel,
                countdownLabel: countdownLabel,
                kickoffLabel: kickoffLabel,
                fieldName: "Dettaglio campo in aggiornamento",
                addressLine: "Apri la scheda gara per vedere il luogo completo della partita.",
                mapsURL: nil,
                weather: nil
            )
        }

        isLoading = false
    }

    private func loadWeather(addressQuery: String, kickoff: Date) async -> DashboardMeteoSnapshot? {
        let query = addressQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        do {
            guard let coordinate = try await searchCoordinate(for: query) else {
                return nil
            }
            return try await fetchWeather(latitude: coordinate.latitude, longitude: coordinate.longitude, kickoff: kickoff)
        } catch {
            return nil
        }
    }

    private func searchCoordinate(for address: String) async throws -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        let response = try await MKLocalSearch(request: request).start()
        if #available(iOS 26.0, *) {
            return response.mapItems.first?.location.coordinate
        }
        return nil
    }

    private func fetchWeather(latitude: Double, longitude: Double, kickoff: Date) async throws -> DashboardMeteoSnapshot? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,weather_code"),
            URLQueryItem(name: "timezone", value: "Europe/Rome"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]

        guard let url = components?.url else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: data)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")

        let targetHour = Calendar(identifier: .gregorian).dateInterval(of: .hour, for: kickoff)?.start ?? kickoff

        var bestIndex: Int?
        var bestDistance: TimeInterval = .greatestFiniteMagnitude

        for (index, timeValue) in response.hourly.time.enumerated() {
            guard let date = formatter.date(from: timeValue) ?? Self.openMeteoFormatter.date(from: timeValue) else {
                continue
            }
            let distance = abs(date.timeIntervalSince(targetHour))
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }

        guard let index = bestIndex,
              index < response.hourly.temperature2m.count,
              index < response.hourly.weatherCode.count else {
            return nil
        }

        let temperature = Int(response.hourly.temperature2m[index].rounded())
        let probability = index < response.hourly.precipitationProbability.count
            ? response.hourly.precipitationProbability[index]
            : nil
        let condition = Self.weatherCondition(for: response.hourly.weatherCode[index])

        return DashboardMeteoSnapshot(
            temperatureLabel: "\(temperature)°",
            summary: probability.map { "\(condition.label) · Pioggia \($0)%" } ?? condition.label,
            symbolName: condition.symbol
        )
    }

    private static func resolveKickoff(for gara: GaraHomeDTO) -> Date? {
        if let dateValue = gara.dateValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !dateValue.isEmpty {
            let timeValue = gara.timeValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "00:00"
            if let date = DateFormatter.prePartitaDateTime.date(from: "\(dateValue) \(timeValue)") {
                return date
            }
        }

        let cleaned = gara.scheduleLabel.replacingOccurrences(of: "·", with: " ")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"

        let regex = try? NSRegularExpression(pattern: #"(\d{2}/\d{2}/\d{4}).*?(\d{1,2}:\d{2})"#)
        let nsRange = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
        if let match = regex?.firstMatch(in: cleaned, options: [], range: nsRange),
           let dateRange = Range(match.range(at: 1), in: cleaned),
           let timeRange = Range(match.range(at: 2), in: cleaned) {
            return formatter.date(from: "\(cleaned[dateRange]) \(cleaned[timeRange])")
        }
        return nil
    }

    private static func fallbackTimeLabel(from gara: GaraHomeDTO) -> String {
        let explicit = gara.timeValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !explicit.isEmpty {
            return explicit
        }

        let cleaned = gara.scheduleLabel.replacingOccurrences(of: "·", with: " ")
        let regex = try? NSRegularExpression(pattern: #"(\d{1,2}:\d{2})"#)
        let nsRange = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
        if let match = regex?.firstMatch(in: cleaned, options: [], range: nsRange),
           let timeRange = Range(match.range(at: 1), in: cleaned) {
            return String(cleaned[timeRange])
        }
        return "In aggiornamento"
    }

    private static func countdownLabel(until kickoff: Date) -> String {
        let now = Date()
        if kickoff <= now {
            return "In programma oggi"
        }

        let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: now, to: kickoff)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0

        if hours <= 0 {
            return "Mancano \(max(minutes, 1)) minuti"
        }
        if minutes <= 0 {
            return "Mancano \(hours) ore"
        }
        return "Mancano \(hours)h \(minutes)m"
    }

    private static func timeLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func parseLocation(whereLine: String, mapsQuery: String) -> DashboardLocationInfo {
        let line = whereLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackQuery = mapsQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !line.isEmpty else {
            let url = googleMapsURL(for: fallbackQuery)
            return DashboardLocationInfo(
                fieldName: "Luogo gara",
                addressLine: fallbackQuery.isEmpty ? "Dettaglio indirizzo non disponibile." : fallbackQuery,
                mapsQuery: fallbackQuery,
                mapsURL: url
            )
        }

        let normalized = line.replacingOccurrences(of: "  ", with: " ")
        let lower = normalized.lowercased()

        var field = "Impianto di gara"
        var address = normalized

        if let range = lower.range(of: "sull'impianto") {
            let suffix = normalized[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if let addressRange = suffix.lowercased().range(of: "sito in") {
                field = suffix[..<addressRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                address = suffix[addressRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                field = String(suffix)
                address = fallbackQuery.isEmpty ? normalized : fallbackQuery
            }
        } else if let range = lower.range(of: "impianto") {
            let suffix = normalized[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            field = suffix.isEmpty ? field : suffix
            address = fallbackQuery.isEmpty ? normalized : fallbackQuery
        } else if !fallbackQuery.isEmpty {
            address = fallbackQuery
        }

        field = field.trimmingCharacters(in: CharacterSet(charactersIn: ":- "))
        if field.isEmpty { field = "Impianto di gara" }
        if address.isEmpty { address = normalized }

        let query = fallbackQuery.isEmpty ? normalized : fallbackQuery
        return DashboardLocationInfo(
            fieldName: field,
            addressLine: address,
            mapsQuery: query,
            mapsURL: googleMapsURL(for: query)
        )
    }

    private static func googleMapsURL(for query: String) -> URL? {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(encoded)")
    }

    private static func weatherCondition(for code: Int) -> (label: String, symbol: String) {
        switch code {
        case 0:
            return ("Sereno", "sun.max.fill")
        case 1, 2:
            return ("Parzialmente nuvoloso", "cloud.sun.fill")
        case 3:
            return ("Nuvoloso", "cloud.fill")
        case 45, 48:
            return ("Nebbia", "cloud.fog.fill")
        case 51, 53, 55, 56, 57:
            return ("Pioviggine", "cloud.drizzle.fill")
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return ("Pioggia", "cloud.rain.fill")
        case 71, 73, 75, 77, 85, 86:
            return ("Neve", "snow")
        case 95, 96, 99:
            return ("Temporali", "cloud.bolt.rain.fill")
        default:
            return ("Meteo variabile", "cloud.sun.fill")
        }
    }

    private static let openMeteoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()
}

private extension DateFormatter {
    static let prePartitaDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()
}

private struct PrePartitaCardView: View {
    let payload: DashboardPrePartitaPayload
    let onOpenDetails: () -> Void

    private let accentColor = Color(hex: 0x4EA0FF)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dashboard intelligente")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(accentColor)

                    Text(payload.teams)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }

            Text(payload.competition)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                PrePartitaRow(
                    icon: "clock.badge.checkmark",
                    text: "\(payload.countdownLabel) · Ore \(payload.kickoffLabel)",
                    accentColor: accentColor
                )
                PrePartitaRow(
                    icon: "mappin.and.ellipse",
                    text: payload.fieldName,
                    accentColor: accentColor
                )
                PrePartitaRow(
                    icon: "road.lanes",
                    text: payload.addressLine,
                    accentColor: accentColor
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                PrePartitaBadge(
                    icon: "calendar.badge.clock",
                    title: payload.countdownLabel,
                    accent: accentColor
                )

                if let weather = payload.weather {
                    PrePartitaBadge(
                        icon: weather.symbolName,
                        title: "\(weather.temperatureLabel) · \(weather.summary)",
                        accent: accentColor
                    )
                } else {
                    PrePartitaBadge(
                        icon: "cloud.sun.fill",
                        title: "Meteo in aggiornamento",
                        accent: accentColor
                    )
                }
            }

            HStack {
                Text("Apri dettagli gara")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accentColor)

                Spacer(minLength: 0)

                if let mapsURL = payload.mapsURL {
                    Link(destination: mapsURL) {
                        HStack(spacing: 6) {
                            Text("Maps")
                                .font(.system(size: 14, weight: .bold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accentColor)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accentColor.opacity(0.24), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: onOpenDetails)
    }
}

private struct PrePartitaLoadingCard: View {
    private let accentColor = Color(hex: 0x4EA0FF)

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(accentColor)

            VStack(alignment: .leading, spacing: 6) {
                Text("Dashboard intelligente")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundStyle(accentColor)

                Text("Sto preparando il quadro pre-partita della gara di oggi.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accentColor.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct PrePartitaRow: View {
    let icon: String
    let text: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 18)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

private struct PrePartitaBadge: View {
    let icon: String
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct PrePartitaTeamsHeadlineView: View {
    let teams: String

    private var parts: [String] {
        teams
            .components(separatedBy: " - ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        if parts.count == 2 {
            VStack(alignment: .leading, spacing: 6) {
                Text(parts[0])
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("vs")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.white.opacity(0.50))

                Text(parts[1])
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(teams)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DashboardPrePartitaPayload {
    let teams: String
    let competition: String
    let countdownLabel: String
    let kickoffLabel: String
    let fieldName: String
    let addressLine: String
    let mapsURL: URL?
    let weather: DashboardMeteoSnapshot?
}

private struct DashboardLocationInfo {
    let fieldName: String
    let addressLine: String
    let mapsQuery: String
    let mapsURL: URL?
}

struct DashboardMeteoSnapshot {
    let temperatureLabel: String
    let summary: String
    let symbolName: String
}

private struct OpenMeteoForecastResponse: Decodable {
    let hourly: OpenMeteoHourlyData
}

private struct OpenMeteoHourlyData: Decodable {
    let time: [String]
    let temperature2m: [Double]
    let precipitationProbability: [Int]
    let weatherCode: [Int]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case precipitationProbability = "precipitation_probability"
        case weatherCode = "weather_code"
    }
}
