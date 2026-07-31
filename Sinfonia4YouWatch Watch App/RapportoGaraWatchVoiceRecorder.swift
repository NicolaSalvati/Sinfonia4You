import AVFoundation
import Foundation

enum RapportoGaraWatchVoiceRecorderError: LocalizedError {
    case permessoNegato
    case registrazioneNonDisponibile
    case audioVuoto

    var errorDescription: String? {
        switch self {
        case .permessoNegato:
            return "Permesso microfono non concesso su Apple Watch."
        case .registrazioneNonDisponibile:
            return "Registrazione audio non disponibile."
        case .audioVuoto:
            return "Nessun audio registrato."
        }
    }
}

@MainActor
final class RapportoGaraWatchVoiceRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var fileURL: URL?
    private var completion: ((Result<Data, Error>) -> Void)?
    private var haRilevatoVoce = false
    private var avviataIl: Date?
    private var ultimaVoceIl: Date?

    private let durataMassima: TimeInterval = 3.6
    private let timeoutSilenzio: TimeInterval = 0.45
    private let sogliaVoceDB: Float = -33

    func start(completion: @escaping (Result<Data, Error>) -> Void) {
        guard recorder == nil else { return }
        self.completion = completion

        requestRecordPermission { [weak self] granted in
            guard let self else { return }
            Task { @MainActor in
                guard granted else {
                    self.finish(with: .failure(RapportoGaraWatchVoiceRecorderError.permessoNegato))
                    return
                }

                do {
                    try self.startRecording()
                } catch {
                    self.finish(with: .failure(error))
                }
            }
        }
    }

    func stop() {
        guard recorder != nil else { return }
        finalizeRecording()
    }

    func cancel() {
        recorder?.stop()
        cleanup()
    }

    private func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 24_000
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true

        guard recorder.prepareToRecord(), recorder.record() else {
            throw RapportoGaraWatchVoiceRecorderError.registrazioneNonDisponibile
        }

        self.recorder = recorder
        self.fileURL = url
        self.avviataIl = Date()
        self.ultimaVoceIl = nil
        self.haRilevatoVoce = false

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleMeterTick()
            }
        }
    }

    private func handleMeterTick() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()

        let now = Date()
        let level = recorder.averagePower(forChannel: 0)
        if level > sogliaVoceDB {
            haRilevatoVoce = true
            ultimaVoceIl = now
        }

        if let avviataIl, now.timeIntervalSince(avviataIl) >= durataMassima {
            finalizeRecording()
            return
        }

        if haRilevatoVoce, let ultimaVoceIl, now.timeIntervalSince(ultimaVoceIl) >= timeoutSilenzio {
            finalizeRecording()
        }
    }

    private func finalizeRecording() {
        recorder?.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            // Ignore session teardown errors; they are non-blocking for the flow.
        }

        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              !data.isEmpty else {
            finish(with: .failure(RapportoGaraWatchVoiceRecorderError.audioVuoto))
            return
        }

        finish(with: .success(data))
    }

    private func finish(with result: Result<Data, Error>) {
        let completion = self.completion
        cleanup()
        completion?(result)
    }

    private func cleanup() {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder = nil
        avviataIl = nil
        ultimaVoceIl = nil
        haRilevatoVoce = false
        completion = nil

        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        fileURL = nil
    }

    private func requestRecordPermission(_ completion: @escaping (Bool) -> Void) {
        if #available(watchOS 10.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                completion(granted)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                completion(granted)
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.finish(with: .failure(error ?? RapportoGaraWatchVoiceRecorderError.registrazioneNonDisponibile))
        }
    }
}
