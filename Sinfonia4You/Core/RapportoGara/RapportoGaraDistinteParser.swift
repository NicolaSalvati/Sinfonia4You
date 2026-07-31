import Foundation

enum RapportoGaraDistinteParser {
    private struct PlayerPrefixExtraction {
        var isStarter: Bool
        var shirtNumber: String
        var tokensConsumed: Int
    }

    private struct PlayerColumnLayout {
        var shirt: ClosedRange<Double>
        var birth: ClosedRange<Double>
        var name: ClosedRange<Double>
        var captain: ClosedRange<Double>
        var matricola: ClosedRange<Double>
        var documentType: ClosedRange<Double>
        var documentNumber: ClosedRange<Double>
        var documentReleasedBy: ClosedRange<Double>
    }

    private struct VisualBirthSequence {
        var birthDate: String
        var startIndex: Int
        var tokenCount: Int
    }

    nonisolated static func parse(
        rows: [RapportoGaraDistintaOCRRow],
        lato: LatoSquadraRapportoGara,
        expectedTeamName: String? = nil
    ) -> RapportoGaraDistintaParsingResult {
        _ = lato
        _ = expectedTeamName
        let normalizedRows = rows
            .map { row in
                RapportoGaraDistintaOCRRow(
                    text: normalizeWhitespace(row.text),
                    fragments: row.fragments,
                    order: row.order
                )
            }
            .flatMap(refineOCRRows(from:))
            .filter { !$0.text.isEmpty }

        guard !normalizedRows.isEmpty else {
            return RapportoGaraDistintaParsingResult(
                teamLabelOCR: "",
                players: [],
                staff: [],
                issues: [
                    DistintaIssueRapportoGara(
                        severity: .error,
                        message: "Nessun testo riconosciuto nella distinta.",
                        section: "ocr"
                    )
                ],
                processingState: .error,
                errorMessage: "Nessun testo riconosciuto nella distinta."
            )
        }

        var issues: [DistintaIssueRapportoGara] = []
        let teamLabelOCR = ""

        let staffStartIndex = normalizedRows.firstIndex { row in
            detectStaffRole(in: row.text) != nil
        } ?? normalizedRows.count

        let playerRows = normalizedRows[..<staffStartIndex].filter(isCandidatePlayerRow(_:))
        let playerParsing = parsePlayers(from: Array(playerRows))
        issues.append(contentsOf: playerParsing.issues)

        let staffRows = normalizedRows[staffStartIndex...].filter { !isFooterRow($0.text) }
        let staffParsing = parseStaff(from: Array(staffRows))
        issues.append(contentsOf: staffParsing.issues)

        if staffParsing.duplicateRoleWarnings.isEmpty == false {
            issues.append(contentsOf: staffParsing.duplicateRoleWarnings)
        }

        let processingState: DistintaProcessingStateRapportoGara
        let errorMessage: String

        if playerParsing.players.isEmpty && staffParsing.staff.isEmpty {
            processingState = .error
            errorMessage = "Non sono riuscito a estrarre giocatori o staff dalla distinta."
            issues.append(
                DistintaIssueRapportoGara(
                    severity: .error,
                    message: errorMessage,
                    section: "ocr"
                )
            )
        } else if issues.isEmpty {
            processingState = .ready
            errorMessage = ""
        } else {
            processingState = .needsReview
            errorMessage = ""
        }

        return RapportoGaraDistintaParsingResult(
            teamLabelOCR: teamLabelOCR,
            players: playerParsing.players,
            staff: staffParsing.staff,
            issues: issues.sorted { left, right in
                if left.severity == right.severity {
                    return left.message < right.message
                }
                return left.severity == .error
            },
            processingState: processingState,
            errorMessage: errorMessage
        )
    }

    nonisolated static func makeRows(from lines: [String]) -> [RapportoGaraDistintaOCRRow] {
        lines.enumerated().map { index, line in
            RapportoGaraDistintaOCRRow(
                text: line,
                fragments: [],
                order: index
            )
        }
    }

    nonisolated private static func refineOCRRows(from row: RapportoGaraDistintaOCRRow) -> [RapportoGaraDistintaOCRRow] {
        guard row.fragments.count > 1 else {
            return [row]
        }

        struct FragmentBand {
            var fragments: [RapportoGaraDistintaOCRFragment]
            var averageY: Double
        }

        let sorted = row.fragments.sorted { left, right in
            if abs(left.midY - right.midY) < 0.006 {
                return left.minX < right.minX
            }
            return left.midY > right.midY
        }

        let tolerance = 0.0075
        var bands: [FragmentBand] = []

        for fragment in sorted {
            let bandIndex = bands.enumerated()
                .filter { abs($0.element.averageY - fragment.midY) <= tolerance }
                .min { left, right in
                    abs(left.element.averageY - fragment.midY) < abs(right.element.averageY - fragment.midY)
                }?
                .offset

            if let bandIndex {
                var band = bands[bandIndex]
                band.fragments.append(fragment)
                let count = Double(band.fragments.count)
                band.averageY = ((band.averageY * (count - 1)) + fragment.midY) / count
                bands[bandIndex] = band
            } else {
                bands.append(
                    FragmentBand(
                        fragments: [fragment],
                        averageY: fragment.midY
                    )
                )
            }
        }

        guard bands.count > 1 else {
            return [row]
        }

        return bands
            .sorted { $0.averageY > $1.averageY }
            .enumerated()
            .compactMap { index, band in
                let fragments = band.fragments.sorted { $0.minX < $1.minX }
                let text = fragments
                    .map(\.text)
                    .joined(separator: " ")
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !text.isEmpty else { return nil }
                return RapportoGaraDistintaOCRRow(
                    text: text,
                    fragments: fragments,
                    order: (row.order * 10) + index
                )
            }
    }

    nonisolated private static func parsePlayers(from rows: [RapportoGaraDistintaOCRRow]) -> (players: [DistintaGiocatoreRapportoGara], issues: [DistintaIssueRapportoGara]) {
        var players: [DistintaGiocatoreRapportoGara] = []
        var issues: [DistintaIssueRapportoGara] = []
        var explicitStarterCount = 0
        var nextOrder = 1
        let headerIndex = rows.firstIndex { isLikelyPlayerHeaderRow($0.text) }
        let layout = makePlayerColumnLayout(
            headerRow: headerIndex.flatMap { rows.indices.contains($0) ? rows[$0] : nil },
            candidateRows: rows
        )
        let dataRows: ArraySlice<RapportoGaraDistintaOCRRow> = if let headerIndex {
            rows.suffix(from: rows.index(after: headerIndex))
        } else {
            ArraySlice(rows)
        }

        for row in dataRows {
            guard !isLikelyPlayerHeaderRow(row.text) else { continue }

            let segments: [RapportoGaraDistintaOCRRow]
            if layout != nil, row.fragments.isEmpty == false {
                segments = [row]
            } else {
                segments = splitPlayerSegments(from: row)
            }
            guard !segments.isEmpty else { continue }

            for segment in segments {
                let visualPlayer = layout.flatMap { parsePlayerVisualRow(segment, fallbackOrder: nextOrder, layout: $0) }
                let tokenPlayer = parsePlayerRow(segment, fallbackOrder: nextOrder)
                guard var player = visualPlayer ?? tokenPlayer else { continue }
                if let tokenPlayer {
                    player = mergeVisualAndTokenPlayer(primary: player, fallback: tokenPlayer)
                }
                if player.isStarter {
                    explicitStarterCount += 1
                }
                if player.shirtNumber.isEmpty {
                    let playerLabel = player.fullName.isEmpty ? "un giocatore della distinta" : player.fullName
                    issues.append(
                        DistintaIssueRapportoGara(
                            severity: .warning,
                            message: "Numero maglia non riconosciuto per \(playerLabel). Inseriscilo manualmente.",
                            section: "giocatori",
                            rawValue: segment.text
                        )
                    )
                }
                if player.fullName.isEmpty {
                    issues.append(
                        DistintaIssueRapportoGara(
                            severity: .warning,
                            message: "Una riga giocatore e stata letta solo parzialmente.",
                            section: "giocatori",
                            rawValue: segment.text
                        )
                    )
                }
                if player.documentTypeRaw.isEmpty && !player.documentNumber.isEmpty {
                    issues.append(
                        DistintaIssueRapportoGara(
                            severity: .warning,
                            message: "Documento presente ma tipo documento non riconosciuto per il giocatore \(player.fullName).",
                            section: "giocatori",
                            rawValue: segment.text
                        )
                    )
                }
                players.append(player)
                nextOrder += 1
            }
        }

        players.sort { $0.order < $1.order }

        if explicitStarterCount == 0 {
            if players.count <= 11 {
                for index in players.indices {
                    players[index].isStarter = true
                }
            } else {
                for index in players.indices {
                    players[index].isStarter = index < 11
                }
                issues.append(
                    DistintaIssueRapportoGara(
                        severity: .warning,
                        message: "Nessun marcatore titolari rilevato: applicata la regola dei primi 11 dall'alto.",
                        section: "giocatori"
                    )
                )
            }
        } else if explicitStarterCount != 11 {
            issues.append(
                DistintaIssueRapportoGara(
                    severity: .warning,
                    message: "Marcatori titolari rilevati in modo non coerente (\(explicitStarterCount) invece di 11). Verifica manuale richiesta.",
                    section: "giocatori"
                )
            )
        }

        return (players, issues)
    }

    nonisolated private static func parsePlayerVisualRow(
        _ row: RapportoGaraDistintaOCRRow,
        fallbackOrder: Int,
        layout: PlayerColumnLayout
    ) -> DistintaGiocatoreRapportoGara? {
        guard row.fragments.isEmpty == false else { return nil }
        guard isLikelyPlayerHeaderRow(row.text) == false else { return nil }

        let shirtFragments = fragments(in: layout.shirt, from: row.fragments)
        let birthFragments = fragments(in: layout.birth, from: row.fragments)
        let nameFragments = fragments(in: layout.name, from: row.fragments)
        let captainFragments = fragments(in: layout.captain, from: row.fragments)
        let matricolaFragments = fragments(in: layout.matricola, from: row.fragments)
        let documentTypeFragments = fragments(in: layout.documentType, from: row.fragments)
        let documentNumberFragments = fragments(in: layout.documentNumber, from: row.fragments)
        let documentReleasedByFragments = fragments(in: layout.documentReleasedBy, from: row.fragments)

        let visualPrefix = extractVisualPrefixData(from: row.fragments)
        let shirtData = parseShirtColumn(
            from: shirtFragments,
            visualOverride: visualPrefix
        )
        let birthDate = {
            if let visualPrefix, !visualPrefix.birthDate.isEmpty {
                return visualPrefix.birthDate
            }
            return extractBirthDate(from: birthFragments.map(\.text)).birthDate
        }()

        let nameTokens = sanitizePlayerNameTokens(nameFragments.map(\.text))
        let nameComponents = splitSurnameAndName(from: nameTokens)

        let captainCode = parseCaptainCode(from: captainFragments.map(\.text))
        let matricola = parseMatricola(from: matricolaFragments.map(\.text))

        let documentTypeTokens = documentTypeFragments.map(\.text)
        let documentNumberTokens = documentNumberFragments.map(\.text)
        let documentReleasedTokens = documentReleasedByFragments.map(\.text)

        let docTypeToken = parseDocumentTypeToken(
            primary: documentTypeTokens,
            secondary: documentNumberTokens + documentReleasedTokens
        )
        let documentKind = docTypeToken.map { detectDocumentKind(from: normalizeToken($0)) } ?? nil
        let documentNumber = parseDocumentNumber(
            primary: documentNumberTokens,
            secondary: documentTypeTokens + documentReleasedTokens
        )
        let documentReleasedBy = parseReleasedBy(
            primary: documentReleasedTokens,
            secondary: documentNumberTokens
        )

        guard shirtData.number.isEmpty == false
            || birthDate.isEmpty == false
            || nameComponents.lastName.isEmpty == false
            || nameComponents.firstName.isEmpty == false else {
            return nil
        }

        return DistintaGiocatoreRapportoGara(
            order: fallbackOrder,
            shirtNumber: shirtData.number,
            firstName: nameComponents.firstName,
            lastName: nameComponents.lastName,
            birthDate: birthDate,
            isStarter: shirtData.isStarter,
            captainCode: captainCode,
            matricola: matricola,
            documentKind: documentKind ?? .altro,
            documentTypeRaw: docTypeToken ?? "",
            documentNumber: documentNumber,
            documentReleasedBy: documentReleasedBy,
            rawLine: row.text
        )
    }

    nonisolated private static func mergeVisualAndTokenPlayer(
        primary: DistintaGiocatoreRapportoGara,
        fallback: DistintaGiocatoreRapportoGara
    ) -> DistintaGiocatoreRapportoGara {
        var merged = primary
        if merged.shirtNumber.isEmpty { merged.shirtNumber = fallback.shirtNumber }
        if merged.firstName.isEmpty { merged.firstName = fallback.firstName }
        if merged.lastName.isEmpty { merged.lastName = fallback.lastName }
        if merged.birthDate.isEmpty { merged.birthDate = fallback.birthDate }
        if merged.captainCode.isEmpty { merged.captainCode = fallback.captainCode }
        if merged.matricola.isEmpty { merged.matricola = fallback.matricola }
        if merged.documentTypeRaw.isEmpty { merged.documentTypeRaw = fallback.documentTypeRaw }
        if merged.documentNumber.isEmpty { merged.documentNumber = fallback.documentNumber }
        if merged.documentReleasedBy.isEmpty { merged.documentReleasedBy = fallback.documentReleasedBy }
        if merged.documentKind == .altro, fallback.documentKind != .altro { merged.documentKind = fallback.documentKind }
        if merged.isStarter == false { merged.isStarter = fallback.isStarter }
        return merged
    }

    nonisolated private static func parsePlayerRow(
        _ row: RapportoGaraDistintaOCRRow,
        fallbackOrder: Int
    ) -> DistintaGiocatoreRapportoGara? {
        if isLikelyPlayerHeaderRow(row.text) {
            return nil
        }

        let rawTokens = tokenize(row.text)
        guard rawTokens.contains(where: { $0.rangeOfCharacter(from: .decimalDigits) != nil }),
              rawTokens.contains(where: { $0.rangeOfCharacter(from: .letters) != nil }) else {
            return nil
        }

        guard let extraction = extractPlayerPrefix(tokens: rawTokens) else {
            return nil
        }

        let explicitStarter = extraction.isStarter
        let shirtNumber = extraction.shirtNumber
        let tokens = Array(rawTokens.dropFirst(extraction.tokensConsumed))

        let birthExtraction = extractBirthDate(from: tokens)
        let birthDate = birthExtraction.birthDate
        let tokensAfterBirth = birthExtraction.tokensConsumed > 0
            ? Array(tokens.dropFirst(birthExtraction.tokensConsumed))
            : tokens
        let cleanedTokensAfterBirth = trimLeadingNumericNoise(tokensAfterBirth)

        var tokenInfos = cleanedTokensAfterBirth.map { token -> (raw: String, normalized: String) in
            (raw: token, normalized: normalizeToken(token))
        }
        tokenInfos = truncateBeforeEmbeddedPlayerStart(tokenInfos)
        guard !tokenInfos.isEmpty else { return nil }

        let fieldStartIndex = tokenInfos.firstIndex { info in
            isCaptainToken(info.normalized)
                || detectDocumentKind(from: info.normalized) != nil
                || looksLikeMatricola(info.normalized)
                || looksLikeDocumentMeta(info.normalized)
        } ?? tokenInfos.count

        let nameTokens = sanitizePlayerNameTokens(tokenInfos[..<fieldStartIndex].map(\.raw))
        guard !nameTokens.isEmpty else { return nil }
        let nameComponents = splitSurnameAndName(from: nameTokens)

        var captainCode = ""
        var matricola = ""
        var documentKind: DistintaDocumentKindRapportoGara = .altro
        var documentTypeRaw = ""
        var documentNumber = ""
        var documentReleasedBy = ""

        if fieldStartIndex < tokenInfos.count {
            let fieldTokens = truncateBeforeEmbeddedPlayerStart(Array(tokenInfos[fieldStartIndex...]))

            if let captainToken = fieldTokens.first(where: { isCaptainToken($0.normalized) }) {
                captainCode = normalizedCaptainCode(captainToken.normalized)
            }

            if let docIndex = fieldTokens.firstIndex(where: {
                detectDocumentKind(from: $0.normalized) != nil || looksLikeDocumentMeta($0.normalized)
            }) {
                let tokensBeforeDoc = truncateBeforeEmbeddedPlayerStart(Array(fieldTokens[..<docIndex]))
                if let matricolaToken = tokensBeforeDoc.reversed().first(where: { looksLikeMatricola($0.normalized) }) {
                    matricola = matricolaToken.raw
                }

                let docTypeSource = fieldTokens[docIndex]
                let detectedKind = detectDocumentKind(from: docTypeSource.normalized)
                documentKind = detectedKind ?? .altro
                documentTypeRaw = rawDocumentLabel(from: fieldTokens, startIndex: docIndex)

                let remainingAfterDoc = Array(fieldTokens.dropFirst(docIndex + 1)).drop(while: { isDocumentStopword($0.normalized) })
                let truncatedAfterDoc = truncateBeforeEmbeddedPlayerStart(Array(remainingAfterDoc))

                if let firstDocNumber = truncatedAfterDoc.first(where: { looksLikeDocumentNumber($0.normalized) }) {
                    documentNumber = firstDocNumber.raw

                    if let firstDocNumberIndex = truncatedAfterDoc.firstIndex(where: { $0.raw == firstDocNumber.raw }) {
                        let issuedTokens = truncatedAfterDoc.dropFirst(firstDocNumberIndex + 1)
                            .map(\.raw)
                            .filter { !isLikelyDisciplinaryToken($0) }
                        documentReleasedBy = issuedTokens.joined(separator: " ")
                    }
                }
            } else if let matricolaToken = fieldTokens.first(where: { looksLikeMatricola($0.normalized) }) {
                matricola = matricolaToken.raw
            }
        }

        let normalizedRow = row.text.uppercased()
        if birthDate.isEmpty && normalizedRow.contains("DATA NASCITA") {
            return nil
        }

        let player = DistintaGiocatoreRapportoGara(
            order: fallbackOrder,
            shirtNumber: shirtNumber,
            firstName: nameComponents.firstName,
            lastName: nameComponents.lastName,
            birthDate: birthDate,
            isStarter: explicitStarter,
            captainCode: captainCode,
            matricola: matricola,
            documentKind: documentKind,
            documentTypeRaw: documentTypeRaw,
            documentNumber: documentNumber,
            documentReleasedBy: documentReleasedBy,
            rawLine: row.text
        )

        guard !player.shirtNumber.isEmpty || !player.fullName.isEmpty else {
            return nil
        }

        return player
    }

    nonisolated private static func makePlayerColumnLayout(
        headerRow: RapportoGaraDistintaOCRRow?,
        candidateRows: [RapportoGaraDistintaOCRRow]
    ) -> PlayerColumnLayout? {
        let hasFragments = candidateRows.contains { $0.fragments.isEmpty == false } || (headerRow?.fragments.isEmpty == false)
        guard hasFragments else { return nil }

        let headerFragments = headerRow?.fragments ?? []

        func boundary(_ aliases: [String], default value: Double) -> Double {
            let matched = headerFragments
                .filter { fragment in
                    let normalized = normalizeToken(fragment.text)
                    return aliases.contains { alias in normalized.contains(alias) || alias.contains(normalized) }
                }
                .map(\.minX)
                .min()
            return matched ?? value
        }

        var birthStart = boundary(["DATANASCITA", "DATA", "G"], default: 0.075)
        var nameStart = boundary(["COGNOMEENOME", "COGNOME", "NOME"], default: 0.18)
        var captainStart = boundary(["CAPVCAP", "CAP"], default: 0.45)
        var matricolaStart = boundary(["MATRICOLA", "FIGC", "MATRICOLAFIGC"], default: 0.52)
        var documentTypeStart = boundary(["TIPO", "DOCUMENTO"], default: 0.60)
        var documentNumberStart = boundary(["NUMERO"], default: 0.69)
        var documentReleasedStart = boundary(["RILASCIATO"], default: 0.80)

        birthStart = max(0.05, min(birthStart, 0.12))
        nameStart = max(birthStart + 0.06, min(nameStart, 0.35))
        captainStart = max(nameStart + 0.10, min(captainStart, 0.50))
        matricolaStart = max(captainStart + 0.03, min(matricolaStart, 0.62))
        documentTypeStart = max(matricolaStart + 0.03, min(documentTypeStart, 0.70))
        documentNumberStart = max(documentTypeStart + 0.03, min(documentNumberStart, 0.82))
        documentReleasedStart = max(documentNumberStart + 0.03, min(documentReleasedStart, 0.92))

        return PlayerColumnLayout(
            shirt: 0...max(0.06, birthStart - 0.006),
            birth: birthStart...max(birthStart + 0.02, nameStart - 0.008),
            name: nameStart...max(nameStart + 0.12, captainStart - 0.006),
            captain: captainStart...max(captainStart + 0.02, matricolaStart - 0.006),
            matricola: matricolaStart...max(matricolaStart + 0.03, documentTypeStart - 0.006),
            documentType: documentTypeStart...max(documentTypeStart + 0.02, documentNumberStart - 0.006),
            documentNumber: documentNumberStart...max(documentNumberStart + 0.03, documentReleasedStart - 0.006),
            documentReleasedBy: documentReleasedStart...1
        )
    }

    nonisolated private static func fragments(
        in range: ClosedRange<Double>,
        from fragments: [RapportoGaraDistintaOCRFragment]
    ) -> [RapportoGaraDistintaOCRFragment] {
        fragments
            .filter { fragment in
                let center = (fragment.minX + fragment.maxX) / 2
                return range.contains(center)
            }
            .sorted { $0.minX < $1.minX }
    }

    nonisolated private static func parseShirtColumn(
        from fragments: [RapportoGaraDistintaOCRFragment],
        visualOverride: VisualBirthSequence?
    ) -> (number: String, isStarter: Bool) {
        let rawTokens = fragments.map(\.text)
        let isStarter = rawTokens.contains { token in
            let normalized = normalizeWhitespace(token)
            if isStarterMarkerToken(normalized) {
                return true
            }
            return normalized.contains("T") || normalized.contains(".") || normalized.contains("•") || normalized.contains("*")
        }

        let candidates = fragments.compactMap { fragment -> (value: String, minX: Double)? in
            let digits = fragment.text.onlyDigits
            guard let value = Int(digits), (1...99).contains(value) else { return nil }
            return (digits, fragment.minX)
        }

        let orderedCandidates = candidates.sorted { left, right in
            if abs(left.minX - right.minX) < 0.002 {
                return left.value.count < right.value.count
            }
            return left.minX < right.minX
        }

        let resolvedNumber = visualOverride?.startIndex != nil
            ? visualOverride.flatMap { extractShirtNumberBeforeBirth(from: fragments, birthData: $0) }
            : nil

        return (resolvedNumber ?? orderedCandidates.first?.value ?? "", isStarter || (visualOverride.map { starterMarkerExists(before: $0, in: fragments) } ?? false))
    }

    nonisolated private static func extractVisualPrefixData(
        from fragments: [RapportoGaraDistintaOCRFragment]
    ) -> VisualBirthSequence? {
        let ordered = fragments.sorted { $0.minX < $1.minX }
        guard ordered.isEmpty == false else { return nil }

        for index in ordered.indices {
            if let date = normalizeDateToken(ordered[index].text) {
                return VisualBirthSequence(
                    birthDate: date,
                    startIndex: index,
                    tokenCount: 1
                )
            }

            guard index + 2 < ordered.count else { continue }
            let day = ordered[index].text.onlyDigits
            let month = ordered[index + 1].text.onlyDigits
            let year = ordered[index + 2].text.onlyDigits
            guard let date = normalizeDate(day: day, month: month, year: year) else { continue }

            return VisualBirthSequence(
                birthDate: date,
                startIndex: index,
                tokenCount: 3
            )
        }

        return nil
    }

    nonisolated private static func extractShirtNumberBeforeBirth(
        from fragments: [RapportoGaraDistintaOCRFragment],
        birthData: VisualBirthSequence
    ) -> String {
        let ordered = fragments.sorted { $0.minX < $1.minX }
        guard birthData.startIndex > 0, ordered.indices.contains(birthData.startIndex) else { return "" }

        let prefix = ordered[..<birthData.startIndex]
        let candidates = prefix.compactMap { fragment -> (value: String, minX: Double)? in
            let normalized = normalizeWhitespace(fragment.text)
            let digits = normalized.replacingOccurrences(of: "T", with: "", options: .caseInsensitive).onlyDigits
            guard let value = Int(digits), (1...99).contains(value) else { return nil }
            return (digits, fragment.minX)
        }
        .sorted { left, right in
            if abs(left.minX - right.minX) < 0.002 {
                return left.value.count < right.value.count
            }
            return left.minX < right.minX
        }

        return candidates.first?.value ?? ""
    }

    nonisolated private static func starterMarkerExists(
        before birthData: VisualBirthSequence,
        in fragments: [RapportoGaraDistintaOCRFragment]
    ) -> Bool {
        let ordered = fragments.sorted { $0.minX < $1.minX }
        guard birthData.startIndex > 0 else { return false }
        let prefix = ordered[..<birthData.startIndex]
        return prefix.contains { fragment in
            let normalized = normalizeWhitespace(fragment.text)
            if isStarterMarkerToken(normalized) {
                return true
            }
            return normalized.contains("T") || normalized.contains(".") || normalized.contains("•") || normalized.contains("*")
        }
    }

    nonisolated private static func parseCaptainCode(from tokens: [String]) -> String {
        let normalizedTokens = tokens.map(normalizeToken)

        for index in normalizedTokens.indices {
            if let role = captainRole(from: normalizedTokens[index]) {
                return role
            }

            if index + 1 < normalizedTokens.count {
                let merged = normalizedTokens[index] + normalizedTokens[index + 1]
                if let role = captainRole(from: merged) {
                    return role
                }
            }
        }

        return ""
    }

    nonisolated private static func parseMatricola(from tokens: [String]) -> String {
        tokens.first { looksLikeMatricola(normalizeToken($0)) } ?? ""
    }

    nonisolated private static func parseDocumentTypeToken(primary: [String], secondary: [String]) -> String? {
        (primary + secondary).first { detectDocumentKind(from: normalizeToken($0)) != nil }
    }

    nonisolated private static func parseDocumentNumber(primary: [String], secondary: [String]) -> String {
        (primary + secondary).first {
            let normalized = normalizeToken($0)
            return looksLikeDocumentNumber(normalized) || looksLikeMatricola(normalized)
        } ?? ""
    }

    nonisolated private static func parseReleasedBy(primary: [String], secondary: [String]) -> String {
        let tokens = (primary + secondary).map(normalizeWhitespace).filter { !$0.isEmpty }
        guard tokens.isEmpty == false else { return "" }
        return tokens
            .filter { !looksLikeDocumentNumber(normalizeToken($0)) }
            .joined(separator: " ")
    }

    nonisolated private static func truncateBeforeEmbeddedPlayerStart(
        _ tokens: [(raw: String, normalized: String)]
    ) -> [(raw: String, normalized: String)] {
        let rawTokens = tokens.map(\.raw)
        let embeddedStart = candidatePlayerStartIndexes(in: rawTokens)
            .filter { $0 > 0 }
            .min()

        guard let embeddedStart, embeddedStart < tokens.count else {
            return tokens
        }
        return Array(tokens[..<embeddedStart])
    }

    nonisolated private static func sanitizePlayerNameTokens(_ rawTokens: [String]) -> [String] {
        rawTokens.compactMap { token in
            let normalized = normalizeToken(token)
            guard !normalized.isEmpty else { return nil }
            guard normalized.rangeOfCharacter(from: .letters) != nil else { return nil }
            guard !playerNameNoiseTokens.contains(normalized) else { return nil }
            guard captainRole(from: normalized) == nil else { return nil }
            guard detectDocumentKind(from: normalized) == nil else { return nil }
            guard !looksLikeDocumentMeta(normalized) else { return nil }
            guard !looksLikeMatricola(normalized) else { return nil }
            return token
        }
    }

    nonisolated private static func splitPlayerSegments(from row: RapportoGaraDistintaOCRRow) -> [RapportoGaraDistintaOCRRow] {
        if isLikelyPlayerHeaderRow(row.text) {
            return []
        }

        let tokens = tokenize(row.text)
        guard !tokens.isEmpty else { return [] }

        let startIndexes = candidatePlayerStartIndexes(in: tokens)
        guard !startIndexes.isEmpty else { return [] }
        guard startIndexes.count > 1 else {
            let cleaned = normalizeWhitespace(tokens[startIndexes[0]...].joined(separator: " "))
            return cleaned.isEmpty ? [] : [RapportoGaraDistintaOCRRow(text: cleaned, fragments: row.fragments, order: row.order)]
        }

        var rows: [RapportoGaraDistintaOCRRow] = []
        for (index, startIndex) in startIndexes.enumerated() {
            let endIndex = index + 1 < startIndexes.count ? startIndexes[index + 1] : tokens.count
            guard startIndex < endIndex else { continue }
            let segmentTokens = Array(tokens[startIndex..<endIndex])
            let segmentText = normalizeWhitespace(segmentTokens.joined(separator: " "))
            guard !segmentText.isEmpty else { continue }
            rows.append(
                RapportoGaraDistintaOCRRow(
                    text: segmentText,
                    fragments: row.fragments,
                    order: row.order + index
                )
            )
        }
        return rows
    }

    nonisolated private static func candidatePlayerStartIndexes(in tokens: [String]) -> [Int] {
        var indices: [Int] = []

        for index in tokens.indices {
            let suffix = Array(tokens[index...])
            guard let extraction = extractPlayerPrefix(tokens: suffix) else { continue }

            let afterPrefix = Array(suffix.dropFirst(extraction.tokensConsumed))
            let birth = extractBirthDate(from: afterPrefix)
            let afterBirth = birth.tokensConsumed > 0
                ? Array(afterPrefix.dropFirst(birth.tokensConsumed))
                : afterPrefix
            let cleanedNameTokens = sanitizePlayerNameTokens(trimLeadingNumericNoise(afterBirth))
            guard !cleanedNameTokens.isEmpty else { continue }

            if let lastIndex = indices.last, index - lastIndex < 5 {
                continue
            }

            indices.append(index)
        }

        return indices
    }

    nonisolated private static func isLikelyPlayerHeaderRow(_ text: String) -> Bool {
        let normalized = normalizeToken(text)
        if normalized.isEmpty {
            return true
        }
        if normalized.contains("DATANASCITA")
            || normalized.contains("COGNOMEENOME")
            || normalized.contains("DOCUMENTODIIDENTIFICAZIONE")
            || normalized.contains("NRMAGLIA")
            || normalized.contains("MATRICOLAFIGC")
            || normalized.contains("MATRFIGC")
            || normalized.contains("CALCIATORE")
            || normalized.contains("COGNOME")
            || normalized.contains("NOME")
            || normalized.contains("ESPULSI")
            || normalized.contains("AMMONITI") {
            return true
        }

        let tokens = tokenize(text).map(normalizeToken)
        let headerMatches = tokens.filter { playerHeaderTokens.contains($0) }.count
        return headerMatches >= 3
    }

    nonisolated private static func parseStaff(from rows: [RapportoGaraDistintaOCRRow]) -> (staff: [DistintaStaffRapportoGara], issues: [DistintaIssueRapportoGara], duplicateRoleWarnings: [DistintaIssueRapportoGara]) {
        var blocks: [(order: Int, text: String)] = []
        var currentBlock: (order: Int, text: String)?

        for row in rows {
            let text = normalizeWhitespace(row.text)
            guard !text.isEmpty else { continue }

            if detectStaffRole(in: text) != nil {
                if let currentBlock {
                    blocks.append(currentBlock)
                }
                currentBlock = (order: row.order, text: text)
            } else if var block = currentBlock {
                block.text += " " + text
                currentBlock = block
            }
        }

        if let currentBlock {
            blocks.append(currentBlock)
        }

        var staff: [DistintaStaffRapportoGara] = []
        var issues: [DistintaIssueRapportoGara] = []

        for (index, block) in blocks.enumerated() {
            guard let item = parseStaffBlock(block.text, order: index + 1) else { continue }
            if item.fullName.isEmpty {
                issues.append(
                    DistintaIssueRapportoGara(
                        severity: .warning,
                        message: "Uno staff e stato riconosciuto senza nome completo.",
                        section: "staff",
                        rawValue: block.text
                    )
                )
            }
            staff.append(item)
        }

        let duplicateWarnings = Dictionary(grouping: staff, by: \.roleKind)
            .compactMap { role, items -> DistintaIssueRapportoGara? in
                guard items.count > 1 else { return nil }
                return DistintaIssueRapportoGara(
                    severity: .warning,
                    message: "Sono state rilevate \(items.count) persone per il ruolo \(role.titolo).",
                    section: "staff"
                )
            }

        return (
            staff.sorted { $0.order < $1.order },
            issues,
            duplicateWarnings.sorted { $0.message < $1.message }
        )
    }

    nonisolated private static func parseStaffBlock(_ text: String, order: Int) -> DistintaStaffRapportoGara? {
        guard let roleDetection = detectStaffRole(in: text) else { return nil }

        let rolePrefix = text.prefix(roleDetection.matchLength)
        let remainder = normalizeWhitespace(
            String(text.dropFirst(roleDetection.matchLength))
                .trimmingCharacters(in: CharacterSet(charactersIn: ":.- \t"))
        )

        let rawTokens = tokenize(remainder)
        let tokenInfos = rawTokens.map { token -> (raw: String, normalized: String) in
            (raw: token, normalized: normalizeToken(token))
        }

        let docIndex = tokenInfos.firstIndex(where: {
            detectDocumentKind(from: $0.normalized) != nil || looksLikeDocumentMeta($0.normalized)
        })

        let nameTokens = docIndex.map { Array(tokenInfos[..<$0].map(\.raw)) } ?? rawTokens
        let nameComponents = splitSurnameAndName(from: nameTokens)

        var documentKind: DistintaDocumentKindRapportoGara = .altro
        var documentTypeRaw = ""
        var documentNumber = ""
        var documentReleasedBy = ""

        if let docIndex {
            let fieldTokens = Array(tokenInfos[docIndex...])
            let docTypeSource = fieldTokens.first!
            documentKind = detectDocumentKind(from: docTypeSource.normalized) ?? .altro
            documentTypeRaw = rawDocumentLabel(from: fieldTokens, startIndex: 0)
            let afterDoc = fieldTokens.dropFirst().drop(while: { isDocumentStopword($0.normalized) })
            if let docNumberToken = afterDoc.first(where: { looksLikeDocumentNumber($0.normalized) || looksLikeMatricola($0.normalized) }) {
                documentNumber = docNumberToken.raw
                if let docIndex = afterDoc.firstIndex(where: { $0.raw == docNumberToken.raw }) {
                    documentReleasedBy = afterDoc.dropFirst(docIndex + 1).map(\.raw).joined(separator: " ")
                }
            }
        }

        return DistintaStaffRapportoGara(
            order: order,
            roleKind: roleDetection.kind,
            roleRaw: String(rolePrefix).trimmingCharacters(in: .whitespacesAndNewlines),
            firstName: nameComponents.firstName,
            lastName: nameComponents.lastName,
            documentKind: documentKind,
            documentTypeRaw: documentTypeRaw,
            documentNumber: documentNumber,
            documentReleasedBy: documentReleasedBy,
            rawLine: text
        )
    }

    nonisolated private static func isCandidatePlayerRow(_ row: RapportoGaraDistintaOCRRow) -> Bool {
        let line = normalizeToken(row.text)
        guard !line.isEmpty else { return false }
        if headerNoiseTokens.contains(where: { line.contains($0) }) {
            return false
        }
        let tokens = tokenize(row.text)
        let hasDigit = tokens.contains(where: { $0.rangeOfCharacter(from: .decimalDigits) != nil })
        let hasLetter = tokens.contains(where: { $0.rangeOfCharacter(from: .letters) != nil })
        let earlyNumber = tokens.prefix(4).contains(where: looksLikeShirtNumberToken(_:))
        return hasDigit && hasLetter && earlyNumber
    }

    nonisolated private static func isFooterRow(_ text: String) -> Bool {
        let normalized = normalizeToken(text)
        return footerNoiseTokens.contains(where: { normalized.contains($0) })
    }

    nonisolated private static func extractPlayerPrefix(tokens: [String]) -> PlayerPrefixExtraction? {
        guard !tokens.isEmpty else { return nil }

        var cursor = 0
        var explicitStarter = false

        while cursor < min(tokens.count, 3), isStarterMarkerToken(tokens[cursor]) {
            explicitStarter = true
            cursor += 1
        }

        guard cursor < tokens.count else { return nil }

        let combinedToken = normalizeToken(tokens[cursor])
        let combinedDigits = combinedToken.replacingOccurrences(of: "T", with: "", options: .caseInsensitive).onlyDigits
        if normalizeDateToken(tokens[cursor]) != nil {
            return PlayerPrefixExtraction(
                isStarter: explicitStarter,
                shirtNumber: "",
                tokensConsumed: cursor
            )
        }
        if combinedToken.hasPrefix("T"),
           let value = Int(combinedDigits),
           (1...99).contains(value) {
            return PlayerPrefixExtraction(
                isStarter: true,
                shirtNumber: combinedDigits,
                tokensConsumed: cursor + 1
            )
        }

        if combinedToken.rangeOfCharacter(from: .letters) != nil {
            return nil
        }

        let leadingNumericTokens = Array(tokens[cursor...].prefix { token in
            normalizeToken(token).rangeOfCharacter(from: .letters) == nil
        })
        let leadingNumericValues = leadingNumericTokens.map(normalizeNumericToken)

        if leadingNumericValues.count >= 5,
           looksLikeShirtNumberToken(leadingNumericTokens[1]),
           normalizeDate(
                day: leadingNumericValues[2],
                month: leadingNumericValues[3],
                year: leadingNumericValues[4]
           ) != nil {
            return PlayerPrefixExtraction(
                isStarter: explicitStarter,
                shirtNumber: leadingNumericValues[1],
                tokensConsumed: cursor + 2
            )
        }

        if leadingNumericValues.count >= 4,
           looksLikeShirtNumberToken(leadingNumericTokens[0]),
           normalizeDate(
                day: leadingNumericValues[1],
                month: leadingNumericValues[2],
                year: leadingNumericValues[3]
           ) != nil {
            return PlayerPrefixExtraction(
                isStarter: explicitStarter,
                shirtNumber: leadingNumericValues[0],
                tokensConsumed: cursor + 1
            )
        }

        if leadingNumericValues.count == 3,
           normalizeDate(
                day: leadingNumericValues[0],
                month: leadingNumericValues[1],
                year: leadingNumericValues[2]
           ) != nil {
            return PlayerPrefixExtraction(
                isStarter: explicitStarter,
                shirtNumber: "",
                tokensConsumed: cursor
            )
        }

        let searchEnd = min(tokens.count, cursor + 3)
        let numericCandidates = tokens[cursor..<searchEnd].enumerated().compactMap { offset, token -> (offset: Int, number: String)? in
            let normalized = normalizeNumericToken(token)
            guard let value = Int(normalized), (1...99).contains(value) else { return nil }
            return (offset, normalized)
        }

        guard let firstCandidate = numericCandidates.first else { return nil }

        var selected = firstCandidate
        if numericCandidates.count > 1 {
            let alternative = numericCandidates[1]
            let afterFirst = Array(tokens.dropFirst(cursor + firstCandidate.offset + 1))
            let afterAlternative = Array(tokens.dropFirst(cursor + alternative.offset + 1))

            let firstLooksLikeBirth = startsWithBirthDate(afterFirst)
            let alternativeLooksLikeBirth = startsWithBirthDate(afterAlternative)

            if alternativeLooksLikeBirth && !firstLooksLikeBirth {
                selected = alternative
            }
        }

        return PlayerPrefixExtraction(
            isStarter: explicitStarter,
            shirtNumber: selected.number,
            tokensConsumed: cursor + selected.offset + 1
        )
    }

    nonisolated private static func extractBirthDate(from tokens: [String]) -> (birthDate: String, tokensConsumed: Int) {
        guard let first = tokens.first else { return ("", 0) }

        if let date = normalizeDateToken(first) {
            return (date, 1)
        }

        guard tokens.count >= 3 else { return ("", 0) }
        let maybeDay = normalizeNumericToken(tokens[0])
        let maybeMonth = normalizeNumericToken(tokens[1])
        let maybeYear = normalizeNumericToken(tokens[2])
        guard let date = normalizeDate(day: maybeDay, month: maybeMonth, year: maybeYear) else {
            return ("", 0)
        }
        return (date, 3)
    }

    nonisolated private static func startsWithBirthDate(_ tokens: [String]) -> Bool {
        let extraction = extractBirthDate(from: tokens)
        return !extraction.birthDate.isEmpty
    }

    nonisolated private static func trimLeadingNumericNoise(_ tokens: [String]) -> [String] {
        var cleaned = tokens

        while let first = cleaned.first {
            let normalized = normalizeToken(first)
            if normalized.isEmpty {
                cleaned.removeFirst()
                continue
            }
            if normalized.rangeOfCharacter(from: .letters) != nil {
                break
            }
            cleaned.removeFirst()
        }

        return cleaned
    }

    nonisolated private static func splitSurnameAndName(from rawTokens: [String]) -> (lastName: String, firstName: String) {
        let tokens = rawTokens
            .map { normalizeNameComponent($0) }
            .filter { !$0.isEmpty }

        guard let first = tokens.first else { return ("", "") }
        guard tokens.count > 1 else { return (first, "") }
        if tokens.count == 2 {
            return (tokens[0], tokens[1])
        }

        if surnameParticles.contains(tokens[0]) {
            return (
                tokens.prefix(2).joined(separator: " "),
                tokens.dropFirst(2).joined(separator: " ")
            )
        }

        return (
            tokens.prefix(1).joined(separator: " "),
            tokens.dropFirst().joined(separator: " ")
        )
    }

    nonisolated private static func detectStaffRole(in text: String) -> (kind: DistintaRoleKindRapportoGara, matchLength: Int)? {
        let normalized = normalizeToken(text)
        for role in roleAliases {
            if normalized.hasPrefix(normalizeToken(role.alias)) {
                return (role.kind, role.originalPrefixLength(in: text))
            }
        }
        return nil
    }

    nonisolated private static func detectDocumentKind(from normalizedToken: String) -> DistintaDocumentKindRapportoGara? {
        if ["PAT", "PATENTE"].contains(normalizedToken) {
            return .patente
        }
        if ["CI", "CARTAIDENTITA", "CARTAIDENTITA", "CARTAIDENTITA"].contains(normalizedToken) {
            return .cartaIdentita
        }
        if normalizedToken.contains("TESS")
            || normalizedToken.contains("FIGC")
            || normalizedToken.contains("MATRSETTTEC")
            || normalizedToken == "MATR" {
            return .tesseraFigc
        }
        return nil
    }

    nonisolated private static func rawDocumentLabel(from tokens: [(raw: String, normalized: String)], startIndex: Int) -> String {
        guard tokens.indices.contains(startIndex) else { return "" }
        let current = tokens[startIndex]
        if current.normalized == "DOCUMENTO", tokens.indices.contains(startIndex + 1) {
            let next = tokens[startIndex + 1]
            if let _ = detectDocumentKind(from: next.normalized) {
                return next.raw
            }
        }
        return current.raw
    }

    nonisolated private static func looksLikeDocumentMeta(_ normalizedToken: String) -> Bool {
        ["DOCUMENTO", "TESSERA", "FIGC", "MATR", "MATRSETTTEC"].contains(normalizedToken)
    }

    nonisolated private static func looksLikeDocumentNumber(_ normalizedToken: String) -> Bool {
        let digits = normalizedToken.onlyDigits
        let hasLetters = normalizedToken.rangeOfCharacter(from: .letters) != nil
        return digits.count >= 4 && (hasLetters || digits.count >= 5)
    }

    nonisolated private static func looksLikeMatricola(_ normalizedToken: String) -> Bool {
        normalizedToken.onlyDigits.count >= 5 && normalizedToken.rangeOfCharacter(from: .letters) == nil
    }

    nonisolated private static func isCaptainToken(_ normalizedToken: String) -> Bool {
        captainRole(from: normalizedToken) != nil
    }

    nonisolated private static func normalizedCaptainCode(_ normalizedToken: String) -> String {
        captainRole(from: normalizedToken) ?? ""
    }

    nonisolated private static func captainRole(from normalizedToken: String) -> String? {
        let token = normalizedToken
            .replacingOccurrences(of: "CAPITANO", with: "CAP")
            .replacingOccurrences(of: "VICE", with: "V")

        switch token {
        case "C", "K", "CAP":
            return "C"
        case "V", "VK", "VC", "VCAP":
            return "V"
        default:
            break
        }

        if token == "CAPVCAP" || token == "CAPVC" || token == "CAPV" {
            return nil
        }

        if token.hasPrefix("V"), token.hasSuffix("CAP") {
            return "V"
        }

        if token.hasSuffix("CAP"), token.count <= 4 {
            return "C"
        }

        return nil
    }

    nonisolated private static func isStarterMarkerToken(_ token: String) -> Bool {
        let normalized = normalizeToken(token)
        return ["T", ".", "•", "*", "+", "✓"].contains(normalized)
    }

    nonisolated private static func looksLikeShirtNumberToken(_ token: String) -> Bool {
        let digits = normalizeNumericToken(token)
        guard let value = Int(digits), (1...99).contains(value) else { return false }
        return digits.count <= 2
    }

    nonisolated private static func normalizeNumericToken(_ token: String) -> String {
        token.onlyDigits
    }

    nonisolated private static func normalizeDateToken(_ token: String) -> String? {
        let cleaned = token.replacingOccurrences(of: "-", with: "/")
        let components = cleaned.split(separator: "/").map(String.init)
        guard components.count == 3 else { return nil }
        return normalizeDate(day: components[0].onlyDigits, month: components[1].onlyDigits, year: components[2].onlyDigits)
    }

    nonisolated private static func normalizeDate(day: String, month: String, year: String) -> String? {
        guard let dayValue = Int(day), (1...31).contains(dayValue),
              let monthValue = Int(month), (1...12).contains(monthValue) else {
            return nil
        }

        let normalizedYear: Int
        if year.count == 2, let shortYear = Int(year) {
            let currentYear = Calendar.current.component(.year, from: Date()) % 100
            normalizedYear = shortYear > currentYear ? 1900 + shortYear : 2000 + shortYear
        } else if let fullYear = Int(year), year.count == 4 {
            normalizedYear = fullYear
        } else {
            return nil
        }

        return String(format: "%02d/%02d/%04d", dayValue, monthValue, normalizedYear)
    }

    nonisolated private static func normalizeWhitespace(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func normalizeToken(_ token: String) -> String {
        normalizeWhitespace(token)
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
    }

    nonisolated private static func normalizeNameComponent(_ token: String) -> String {
        normalizeWhitespace(token)
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
    }

    nonisolated private static func tokenize(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: ";", with: " ")
            .split(separator: " ")
            .map(String.init)
    }

    nonisolated private static func isDocumentStopword(_ normalizedToken: String) -> Bool {
        ["N", "NO", "NRO", "NR", "NUMERO", "E", "O"].contains(normalizedToken)
    }

    nonisolated private static func isLikelyDisciplinaryToken(_ token: String) -> Bool {
        let normalized = normalizeToken(token)
        return ["ESPULSI", "AMMONITI", "AMMONIZIONI"].contains(normalized)
    }

    nonisolated private static let headerNoiseTokens: [String] = [
        "DISTINTA",
        "DATA NASCITA",
        "COGNOME E NOME",
        "DOCUMENTO DI IDENTIFICAZIONE",
        "G M A",
        "NR DELLE",
        "CAMPIONATO",
        "PARTECIPANTI ALLA GARA",
        "DA DISPUTARE IL",
        "PRESSO"
    ]

    nonisolated private static let footerNoiseTokens: [String] = [
        "FIRMA",
        "IL SOTTOSCRITTO",
        "NOTE",
        "SCANNED",
        "CAMSCANNER"
    ]

    nonisolated private static let playerHeaderTokens: Set<String> = [
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

    nonisolated private static let playerNameNoiseTokens: Set<String> = [
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
        "MATRICOLAFIGC",
        "FIGC",
        "DOCUMENTO",
        "IDENTIFICAZIONE",
        "TIPO",
        "NUMERO",
        "RILASCIATO",
        "ESPULSI",
        "AMMONITI",
        "NRMAGLIA",
        "NRDELLE"
    ]

    nonisolated private static let surnameParticles: Set<String> = [
        "DI",
        "DE",
        "DEL",
        "DELLA",
        "DALLA",
        "DA",
        "VAN",
        "VON",
        "SAN",
        "SANTA",
        "LO",
        "LA"
    ]

    private struct StaffRoleAlias {
        let alias: String
        let kind: DistintaRoleKindRapportoGara

        nonisolated func originalPrefixLength(in text: String) -> Int {
            let normalizedOriginal = text.folding(options: .diacriticInsensitive, locale: .current).uppercased()
            guard let range = normalizedOriginal.range(of: alias) else {
                return alias.count
            }
            return normalizedOriginal.distance(from: normalizedOriginal.startIndex, to: range.upperBound)
        }
    }

    nonisolated private static let roleAliases: [StaffRoleAlias] = [
        StaffRoleAlias(alias: "DIRIGENTE ACCOMPAGNATORE UFFICIALE DELLA SQUADRA", kind: .dirigenteAccompagnatoreUfficiale),
        StaffRoleAlias(alias: "DIRIGENTE ACCOMPAGNATORE UFFICIALE", kind: .dirigenteAccompagnatoreUfficiale),
        StaffRoleAlias(alias: "DIRIGENTE ACCOMPAGNATORE", kind: .dirigenteAccompagnatoreUfficiale),
        StaffRoleAlias(alias: "DIRIGENTE ADDETTO UFFICIALE GARA", kind: .dirigenteAddettoUfficialeGara),
        StaffRoleAlias(alias: "DIRIGENTE ADDETTO ARBITRO", kind: .dirigenteAddettoUfficialeGara),
        StaffRoleAlias(alias: "DIRIGENTE ADDETTO UFFICIALE", kind: .dirigenteAddettoUfficialeGara),
        StaffRoleAlias(alias: "DIRIGENTE ADDETTO UFFICIALE DI GARA", kind: .dirigenteAddettoUfficialeGara),
        StaffRoleAlias(alias: "MEDICO SOCIALE", kind: .medicoSociale),
        StaffRoleAlias(alias: "ALLENATORE IN II", kind: .allenatoreInSeconda),
        StaffRoleAlias(alias: "ALLENATORE II", kind: .allenatoreInSeconda),
        StaffRoleAlias(alias: "ALLENATORE IN 2", kind: .allenatoreInSeconda),
        StaffRoleAlias(alias: "ALLENATORE 2", kind: .allenatoreInSeconda),
        StaffRoleAlias(alias: "ALLENATORE IN I I", kind: .allenatoreInSeconda),
        StaffRoleAlias(alias: "ALLENATORE I I", kind: .allenatoreInSeconda),
        StaffRoleAlias(alias: "ALLENATORE IN SECONDA", kind: .allenatoreInSeconda),
        StaffRoleAlias(alias: "ALLENATORE SECONDA", kind: .allenatoreInSeconda),
        StaffRoleAlias(alias: "SECONDO ALLENATORE", kind: .allenatoreInSeconda),
        StaffRoleAlias(alias: "ALLENATORE", kind: .allenatore),
        StaffRoleAlias(alias: "MASSAGGIATORE", kind: .massaggiatore),
        StaffRoleAlias(alias: "PREPARATORE ATLETICO", kind: .preparatoreAtletico),
        StaffRoleAlias(alias: "PREP ATLETICO", kind: .preparatoreAtletico),
        StaffRoleAlias(alias: "PREPARATORE PORTIERI", kind: .preparatorePortieri),
        StaffRoleAlias(alias: "PREP PORTIERI", kind: .preparatorePortieri),
        StaffRoleAlias(alias: "PREP PORTIERE", kind: .preparatorePortieri),
        StaffRoleAlias(alias: "PREP. PORTIERE", kind: .preparatorePortieri),
    ].sorted { $0.alias.count > $1.alias.count }
}

private extension String {
    nonisolated var onlyDigits: String {
        filter(\.isNumber)
    }
}
