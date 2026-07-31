import Foundation
import Speech

enum RapportoGaraSpeechTranscriberError: LocalizedError {
    case autorizzazioneNegata
    case recognizerNonDisponibile
    case trascrizioneVuota

    var errorDescription: String? {
        switch self {
        case .autorizzazioneNegata:
            return "Autorizzazione al riconoscimento vocale non concessa su iPhone."
        case .recognizerNonDisponibile:
            return "Riconoscimento vocale italiano non disponibile su iPhone."
        case .trascrizioneVuota:
            return "Nessun testo riconosciuto."
        }
    }
}

enum RapportoGaraSpeechTranscriber {
    private static let fileTemporaneoPrefix = "sinfonia4you-trascrizione-"
    private static let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "it-IT"))
    private static let contestoArbitrale = [
        "numero",
        "maglia",
        "casa",
        "locale",
        "ospiti",
        "ospite",
        "trasferta",
        "ammonito",
        "ammonita",
        "ammonizione",
        "cartellino giallo",
        "espulso",
        "espulsa",
        "espulsione",
        "cartellino rosso",
        "rosso diretto",
        "rosso",
        "giallo",
        "doppio giallo rosso",
        "seconda ammonizione",
        "doppia ammonizione",
        "secondo giallo",
        "gol",
        "goal",
        "rete",
        "ha segnato",
        "sostituzione",
        "cambio",
        "entra",
        "esce",
        "subentra",
        "motivo",
        "motivazione",
        "proteste",
        "dissenso",
        "simulazione",
        "ritardo",
        "fallo di mano",
        "gioco scorretto",
        "comportamento antisportivo"
    ]

    static func trascrivi(audioData: Data) async throws -> String {
        try await ensureAuthorization()

        guard let recognizer = recognizer,
              recognizer.isAvailable else {
            throw RapportoGaraSpeechTranscriberError.recognizerNonDisponibile
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileTemporaneoPrefix)\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        try audioData.write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.contextualStrings = contestoArbitrale
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.addsPunctuation = false

        let testo: String = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            var didResume = false
            var task: SFSpeechRecognitionTask?

            task = recognizer.recognitionTask(with: request) { result, error in
                if let error, !didResume {
                    didResume = true
                    task?.cancel()
                    continuation.resume(throwing: error)
                    return
                }

                guard let result, !didResume else { return }
                let testo = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !testo.isEmpty else { return }
                guard result.isFinal || trascrizioneProntaRapidamente(testo) else { return }

                didResume = true
                task?.cancel()
                continuation.resume(returning: testo)
            }
        }

        let clean = testo.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !clean.isEmpty else {
            throw RapportoGaraSpeechTranscriberError.trascrizioneVuota
        }

        return clean
    }

    private static func trascrizioneProntaRapidamente(_ testo: String) -> Bool {
        let normalizzato = testoNormalizzato(testo)
        let haEvento = contestoEventoRapido.contains { normalizzato.contains($0) }
        guard haEvento else { return false }

        let haNumero = normalizzato.contains(where: \.isNumber)
            || paroleNumeroRapide.contains { parola in
                normalizzato.split(separator: " ").contains(Substring(parola))
            }
        let haSquadra = ["casa", "locale", "locali", "interni", "ospiti", "ospite", "trasferta", "esterni", "avversari"]
            .contains { normalizzato.contains($0) }
        let haMotivazione = normalizzato.contains(" per ")

        return haNumero || haSquadra || haMotivazione
    }

    private static func testoNormalizzato(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func ripulisciFileTemporaneiResidui() {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory

        guard let urls = try? fileManager.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        for url in urls where url.lastPathComponent.hasPrefix(fileTemporaneoPrefix) {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func ensureAuthorization() async throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return
        case .notDetermined:
            let status = await requestSpeechAuthorization()
            guard status == .authorized else {
                throw RapportoGaraSpeechTranscriberError.autorizzazioneNegata
            }
        case .denied, .restricted:
            throw RapportoGaraSpeechTranscriberError.autorizzazioneNegata
        @unknown default:
            throw RapportoGaraSpeechTranscriberError.autorizzazioneNegata
        }
    }

    nonisolated private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { result in
                continuation.resume(returning: result)
            }
        }
    }

    private static let contestoEventoRapido = [
        "ammonit",
        "ammonizione",
        "giallo",
        "espuls",
        "espulso",
        "espulsione",
        "rosso",
        "seconda ammonizione",
        "doppia ammonizione",
        "doppio giallo",
        "gol",
        "goal",
        "rete",
        "sostituzione",
        "cambio",
        "entra",
        "esce"
    ]

    private static let paroleNumeroRapide = [
        "uno",
        "una",
        "due",
        "tre",
        "quattro",
        "cinque",
        "sei",
        "sette",
        "otto",
        "nove",
        "dieci",
        "undici",
        "dodici",
        "tredici",
        "quattordici",
        "quindici",
        "sedici",
        "diciassette",
        "diciotto",
        "diciannove",
        "venti",
        "trenta",
        "quaranta",
        "cinquanta",
        "sessanta",
        "settanta",
        "ottanta",
        "novanta"
    ]
}
