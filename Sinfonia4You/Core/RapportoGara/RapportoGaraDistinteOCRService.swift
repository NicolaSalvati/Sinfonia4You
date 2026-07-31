import Foundation
import UIKit
@preconcurrency import Vision
import ImageIO
import CoreImage
import CoreImage.CIFilterBuiltins

enum RapportoGaraDistinteOCRService {
    private struct OCRCropDescriptor {
        var image: UIImage
        var offsetX: Double
        var scaleX: Double
        var offsetY: Double
        var scaleY: Double
    }

    static func processa(
        image: UIImage,
        lato: LatoSquadraRapportoGara,
        expectedTeamName: String? = nil
    ) async throws -> RapportoGaraDistintaParsingResult {
        let normalized = normalizzaImmagine(image)
        let rows = try await estraiRighe(from: normalized)
        return RapportoGaraDistinteParser.parse(
            rows: rows,
            lato: lato,
            expectedTeamName: expectedTeamName
        )
    }

    static func normalizzaImmagine(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: image.size)).fill()
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    static func jpegData(from image: UIImage, compression: CGFloat = 0.88) -> Data? {
        normalizzaImmagine(image).jpegData(compressionQuality: compression)
    }

    private static func estraiRighe(from image: UIImage) async throws -> [RapportoGaraDistintaOCRRow] {
        guard let cgImage = image.cgImage else {
            throw DistinteOCRError.invalidImage
        }

        let orientation = cgImageOrientation(from: image.imageOrientation)

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["it-IT", "en-US"]
        request.minimumTextHeight = 0.012

        let observations = try await riconosciTesto(
            cgImage: cgImage,
            orientation: orientation,
            request: request
        )

        var fragments = makeFragments(from: observations)

        let preliminaryRows = raggruppaPerRiga(fragments: fragments)
        let shirtFragments = try await makeDedicatedShirtFragments(
            from: image,
            basedOn: preliminaryRows
        )
        if shirtFragments.isEmpty == false {
            fragments = mergePrimaryFragments(fragments, with: shirtFragments)
        }

        let rows = raggruppaPerRiga(fragments: fragments)
        guard !rows.isEmpty else {
            throw DistinteOCRError.noRecognizedText
        }
        return rows
    }

    private static func makeFragments(
        from observations: [VNRecognizedTextObservation],
        offsetX: Double = 0,
        scaleX: Double = 1,
        offsetY: Double = 0,
        scaleY: Double = 1
    ) -> [RapportoGaraDistintaOCRFragment] {
        var fragments: [RapportoGaraDistintaOCRFragment] = []
        fragments.reserveCapacity(observations.count)

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            fragments.append(
                RapportoGaraDistintaOCRFragment(
                    text: candidate.string,
                    minX: offsetX + (observation.boundingBox.minX * scaleX),
                    maxX: offsetX + (observation.boundingBox.maxX * scaleX),
                    midY: offsetY + (observation.boundingBox.midY * scaleY)
                )
            )
        }

        return fragments
    }

    private static func mergePrimaryFragments(
        _ primary: [RapportoGaraDistintaOCRFragment],
        with secondary: [RapportoGaraDistintaOCRFragment]
    ) -> [RapportoGaraDistintaOCRFragment] {
        var merged = primary

        for candidate in secondary {
            let alreadyCovered = merged.contains { existing in
                abs(existing.midY - candidate.midY) <= 0.011 &&
                abs(existing.minX - candidate.minX) <= 0.03 &&
                normalizeFragmentText(existing.text) == normalizeFragmentText(candidate.text)
            }

            if !alreadyCovered {
                merged.append(candidate)
            }
        }

        return merged
    }

    private static func makeDedicatedShirtFragments(
        from image: UIImage,
        basedOn preliminaryRows: [RapportoGaraDistintaOCRRow]
    ) async throws -> [RapportoGaraDistintaOCRFragment] {
        let candidateRows = candidatePlayerRows(in: preliminaryRows)
        guard candidateRows.isEmpty == false else { return [] }

        var dedicatedFragments: [RapportoGaraDistintaOCRFragment] = []
        dedicatedFragments.reserveCapacity(candidateRows.count)

        let rowBandHeight = estimatedPlayerRowHeight(for: candidateRows)

        for row in candidateRows {
            guard let crop = makeShirtCrop(
                from: image,
                around: row,
                estimatedBandHeight: rowBandHeight
            ), let cropCGImage = crop.image.cgImage else {
                continue
            }

            let shirtRequest = VNRecognizeTextRequest()
            shirtRequest.recognitionLevel = .accurate
            shirtRequest.usesLanguageCorrection = false
            shirtRequest.recognitionLanguages = ["en-US", "it-IT"]
            shirtRequest.minimumTextHeight = 0.01

            let observations = try await riconosciTesto(
                cgImage: cropCGImage,
                orientation: .up,
                request: shirtRequest
            )

            let mapped = makeFragments(
                from: observations,
                offsetX: crop.offsetX,
                scaleX: crop.scaleX,
                offsetY: crop.offsetY,
                scaleY: crop.scaleY
            )
            .filter { fragment in
                fragment.text.rangeOfCharacter(from: .decimalDigits) != nil
            }

            dedicatedFragments.append(contentsOf: mapped)
        }

        return dedicatedFragments
    }

    private static func makeShirtCrop(
        from image: UIImage,
        around row: RapportoGaraDistintaOCRRow,
        estimatedBandHeight: Double
    ) -> OCRCropDescriptor? {
        let normalized = normalizzaImmagine(image)
        let fullSize = normalized.size
        guard fullSize.width > 0, fullSize.height > 0 else { return nil }

        let rowCenter = row.fragments.map(\.midY).reduce(0, +) / Double(max(row.fragments.count, 1))
        let bandHeight = max(0.018, min(estimatedBandHeight * 1.75, 0.05))
        let lowerY = max(0.0, rowCenter - (bandHeight / 2))
        let upperY = min(1.0, rowCenter + (bandHeight / 2))
        let cropWidthRatio = 0.084
        let cropRect = CGRect(
            x: 0,
            y: fullSize.height * (1 - upperY),
            width: fullSize.width * cropWidthRatio,
            height: fullSize.height * (upperY - lowerY)
        ).integral

        guard let sourceCGImage = normalized.cgImage,
              let cropped = sourceCGImage.cropping(to: cropRect) else {
            return nil
        }

        let croppedImage = UIImage(cgImage: cropped)
        return OCRCropDescriptor(
            image: enhanceForShirtNumbersOCR(croppedImage),
            offsetX: 0,
            scaleX: cropWidthRatio,
            offsetY: lowerY,
            scaleY: upperY - lowerY
        )
    }

    private static func enhanceForShirtNumbersOCR(_ image: UIImage) -> UIImage {
        guard let input = CIImage(image: image) else { return image }

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = input
        colorControls.saturation = 0
        colorControls.contrast = 2.1
        colorControls.brightness = 0.04

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = colorControls.outputImage
        sharpen.sharpness = 0.8

        let output = sharpen.outputImage ?? colorControls.outputImage ?? input
        let context = CIContext(options: nil)

        guard let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }

    private static func candidatePlayerRows(
        in rows: [RapportoGaraDistintaOCRRow]
    ) -> [RapportoGaraDistintaOCRRow] {
        let staffStart = rows.firstIndex(where: { isLikelyStaffRow($0.text) }) ?? rows.count
        let tableRows = Array(rows.prefix(staffStart))
        let headerIndex = tableRows.firstIndex(where: { isLikelyPlayerHeaderRow($0.text) })
        let dataRows = headerIndex.map { Array(tableRows.dropFirst($0 + 1)) } ?? tableRows

        return dataRows.filter { row in
            let normalized = normalizeToken(row.text)
            guard normalized.isEmpty == false else { return false }
            guard isLikelyPlayerHeaderRow(row.text) == false else { return false }
            guard isLikelyFooterRow(row.text) == false else { return false }
            let hasDigits = row.text.rangeOfCharacter(from: .decimalDigits) != nil
            let hasLetters = row.text.rangeOfCharacter(from: .letters) != nil
            return hasDigits && hasLetters
        }
    }

    private static func estimatedPlayerRowHeight(
        for rows: [RapportoGaraDistintaOCRRow]
    ) -> Double {
        let centers = rows
            .compactMap { row -> Double? in
                guard row.fragments.isEmpty == false else { return nil }
                return row.fragments.map(\.midY).reduce(0, +) / Double(row.fragments.count)
            }
            .sorted(by: >)

        let deltas = zip(centers, centers.dropFirst())
            .map { abs($0 - $1) }
            .filter { $0 > 0.0015 }

        guard deltas.isEmpty == false else { return 0.020 }
        let sorted = deltas.sorted()
        return sorted[sorted.count / 2]
    }

    private static func isLikelyPlayerHeaderRow(_ text: String) -> Bool {
        let normalized = normalizeToken(text)
        if normalized.isEmpty {
            return true
        }

        if normalized.contains("DATANASCITA")
            || normalized.contains("COGNOMEENOME")
            || normalized.contains("DOCUMENTODIIDENTIFICAZIONE")
            || normalized.contains("NRMAGLIA")
            || normalized.contains("MATRICOLAFIGC")
            || normalized.contains("CALCIATORE")
            || normalized.contains("ESPULSI")
            || normalized.contains("AMMONITI") {
            return true
        }

        let tokens = tokenize(text).map { normalizeToken($0) }
        let matches = tokens.filter(playerHeaderTokens.contains).count
        return matches >= 3
    }

    private static func isLikelyStaffRow(_ text: String) -> Bool {
        let normalized = normalizeToken(text)
        return staffRolePrefixes.contains { normalized.hasPrefix($0) }
    }

    private static func isLikelyFooterRow(_ text: String) -> Bool {
        let normalized = normalizeToken(text)
        return footerNoiseTokens.contains { normalized.contains($0) }
    }

    private static func normalizeFragmentText(_ text: String) -> String {
        text
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
    }

    private static func normalizeWhitespace(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeToken(_ token: String) -> String {
        normalizeWhitespace(token)
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
    }

    private static func tokenize(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: ";", with: " ")
            .split(separator: " ")
            .map(String.init)
    }

    private static let playerHeaderTokens: Set<String> = [
        "G",
        "M",
        "A",
        "CAP",
        "CAPVCAP",
        "COGNOME",
        "NOME",
        "COGNOMEE",
        "COGNOMEENOME",
        "DATANASCITA",
        "MATRICOLA",
        "FIGC",
        "DOCUMENTO",
        "TIPO",
        "NUMERO",
        "RILASCIATO",
        "AMMONITI",
        "ESPULSI"
    ]

    private static let footerNoiseTokens: [String] = [
        "FIRMA",
        "ILSOTTOSCRITTO",
        "NOTE",
        "SCANNED",
        "CAMSCANNER"
    ]

    private static let staffRolePrefixes: [String] = [
        "DIRIGENTEACCOMPAGNATOREUFFICIALEDELLASQUADRA",
        "DIRIGENTEACCOMPAGNATOREUFFICIALE",
        "DIRIGENTEACCOMPAGNATORE",
        "DIRIGENTEADDETTOUFFICIALEGARA",
        "DIRIGENTEADDETTOARBITRO",
        "DIRIGENTEADDETTOUFFICIALE",
        "DIRIGENTEADDETTOUFFICIALEDIGARA",
        "MEDICOSOCIALE",
        "ALLENATOREINII",
        "ALLENATOREII",
        "ALLENATOREIN2",
        "ALLENATORE2",
        "ALLENATOREINI I",
        "ALLENATOREI I",
        "ALLENATOREINSECONDA",
        "ALLENATORESECONDA",
        "SECONDOALLENATORE",
        "ALLENATORE",
        "MASSAGGIATORE",
        "PREPARATOREATLETICO",
        "PREPATLETICO",
        "PREPARATOREPORTIERI",
        "PREPPORTIERI",
        "PREPPORTIERE"
    ]

    private static func riconosciTesto(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        request: VNRecognizeTextRequest
    ) async throws -> [VNRecognizedTextObservation] {
        try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    continuation.resume(returning: observations)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func raggruppaPerRiga(
        fragments: [RapportoGaraDistintaOCRFragment]
    ) -> [RapportoGaraDistintaOCRRow] {
        let sorted = fragments.sorted { left, right in
            if abs(left.midY - right.midY) < 0.006 {
                return left.minX < right.minX
            }
            return left.midY > right.midY
        }

        struct RowCluster {
            var fragments: [RapportoGaraDistintaOCRFragment]
            var averageY: Double
        }

        let tolerance: Double = 0.0105
        var clusters: [RowCluster] = []

        for fragment in sorted {
            let bestIndex = clusters.enumerated()
                .filter { abs($0.element.averageY - fragment.midY) <= tolerance }
                .min { left, right in
                    abs(left.element.averageY - fragment.midY) < abs(right.element.averageY - fragment.midY)
                }?
                .offset

            if let bestIndex {
                var cluster = clusters[bestIndex]
                cluster.fragments.append(fragment)
                let count = Double(cluster.fragments.count)
                cluster.averageY = ((cluster.averageY * (count - 1)) + fragment.midY) / count
                clusters[bestIndex] = cluster
            } else {
                clusters.append(
                    RowCluster(
                        fragments: [fragment],
                        averageY: fragment.midY
                    )
                )
            }
        }

        return clusters
            .sorted { left, right in
                if abs(left.averageY - right.averageY) < 0.006 {
                    let leftMinX = left.fragments.map(\.minX).min() ?? 0
                    let rightMinX = right.fragments.map(\.minX).min() ?? 0
                    return leftMinX < rightMinX
                }
                return left.averageY > right.averageY
            }
            .enumerated()
            .compactMap { index, cluster in
            let sortedGroup = cluster.fragments.sorted { left, right in
                if abs(left.midY - right.midY) < 0.006 {
                    return left.minX < right.minX
                }
                return left.midY > right.midY
            }
            let text = sortedGroup
                .map(\.text)
                .joined(separator: " ")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { return nil }
            return RapportoGaraDistintaOCRRow(
                text: text,
                fragments: sortedGroup,
                order: index
            )
        }
    }

    private static func cgImageOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up:
            return .up
        case .upMirrored:
            return .upMirrored
        case .down:
            return .down
        case .downMirrored:
            return .downMirrored
        case .left:
            return .left
        case .leftMirrored:
            return .leftMirrored
        case .right:
            return .right
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}

enum DistinteOCRError: LocalizedError {
    case invalidImage
    case noRecognizedText

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "L'immagine selezionata non e valida per l'OCR."
        case .noRecognizedText:
            return "Non sono riuscito a leggere testo utile dalla distinta."
        }
    }
}
