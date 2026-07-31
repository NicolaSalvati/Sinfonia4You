import Testing
@testable import Sinfonia4You

struct RapportoGaraDistinteParserTests {

    @Test func parseGiocatoreConDataCompletaCapitanoEDocumento() {
        let rows = RapportoGaraDistinteParser.makeRows(from: [
            "DISTINTA ELENCO GIOCATORI",
            "ASD CASA VS ASD OSPITI",
            "T 10 30/05/1989 TEDESCO GIANMARCO K 4394816 C.I. CA63570KF MIN.INTERNO",
            "Dirigente accompagnatore ufficiale della squadra Fusco Paolo C.I. CA17947IG Comune Agropoli"
        ])

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .casa, expectedTeamName: "ASD CASA")
        let player = result.players.first

        #expect(result.processingState == .needsReview)
        #expect(player?.shirtNumber == "10")
        #expect(player?.birthDate == "30/05/1989")
        #expect(player?.lastName == "TEDESCO")
        #expect(player?.firstName == "GIANMARCO")
        #expect(player?.captainCode == "C")
        #expect(player?.matricola == "4394816")
        #expect(player?.documentKind == .cartaIdentita)
        #expect(player?.documentNumber == "CA63570KF")
        #expect(player?.documentReleasedBy == "MIN.INTERNO")
    }

    @Test func parseDataGMAViceCapitanoEDocumentiDiversi() {
        let rows = RapportoGaraDistinteParser.makeRows(from: [
            "DISTINTA GIOCATORI PARTECIPANTI ALLA GARA ASD CASA VS ASD OSPITI",
            "1 07 05 08 LESTA OSCAR GIONA VK PAT U1U177941X MIT-UCO",
            "2 28 06 07 DI FLORA DAVIDE TESS 1234567 FIGC"
        ])

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .casa)

        #expect(result.players.count == 2)
        #expect(result.players[0].birthDate == "07/05/2008")
        #expect(result.players[0].captainCode == "V")
        #expect(result.players[0].documentKind == .patente)
        #expect(result.players[0].documentNumber == "U1U177941X")
        #expect(result.players[1].documentKind == .tesseraFigc)
        #expect(result.players[1].documentNumber == "1234567")
    }

    @Test func normalizzaAliasCapitanoEViceCapitano() {
        let rows = RapportoGaraDistinteParser.makeRows(from: [
            "1 07 05 08 ALFA MARIO CAP C.I. AA111111 COMUNE UNO",
            "2 28 06 07 BETA LUCA VC C.I. BB222222 COMUNE DUE",
            "3 15 09 06 GAMMA PAOLO V-CAP C.I. CC333333 COMUNE TRE",
            "4 13 07 00 DELTA GIUSEPPE K C.I. DD444444 COMUNE QUATTRO"
        ])

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .casa)

        #expect(result.players.count == 4)
        #expect(result.players[0].captainCode == "C")
        #expect(result.players[1].captainCode == "V")
        #expect(result.players[2].captainCode == "V")
        #expect(result.players[3].captainCode == "C")
    }

    @Test func fallbackPrimiUndiciTitolariQuandoMancanoMarcatori() {
        let lines = (1...13).map { index in
            "\(index) 01/01/2000 ROSSI MARIO C.I. CA\(1000 + index) COMUNE"
        }

        let result = RapportoGaraDistinteParser.parse(
            rows: RapportoGaraDistinteParser.makeRows(from: lines),
            lato: .casa
        )

        #expect(result.players.count == 13)
        #expect(result.players.prefix(11).filter { $0.isStarter }.count == 11)
        #expect(result.players.suffix(2).filter { !$0.isStarter }.count == 2)
        #expect(result.issues.contains(where: { $0.message.contains("primi 11") }))
    }

    @Test func segnalaMarcatoriTitolariNonCoerenti() {
        let rows = RapportoGaraDistinteParser.makeRows(from: [
            "T 1 01/01/2000 ROSSI MARIO C.I. CA1111 COMUNE",
            "T 2 01/01/2000 BIANCHI LUCA C.I. CA2222 COMUNE",
            "3 01/01/2000 VERDI PAOLO C.I. CA3333 COMUNE"
        ])

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .casa)

        #expect(result.processingState == .needsReview)
        #expect(result.issues.contains(where: { $0.message.contains("Marcatori titolari") }))
    }

    @Test func preservaRuoliStaffDuplicatiEAbbreviazioni() {
        let rows = RapportoGaraDistinteParser.makeRows(from: [
            "Dirigente accompagnatore ufficiale della squadra Fusco Paolo C.I. CA17947IG Comune Agropoli",
            "Allenatore Squillante Luigi Tess. 43762 LND",
            "Allenatore in II Liguori Alfonso Tess. 108952 FIGC",
            "Massaggiatore Moscariello Francesco C.I. CA58962SF Eboli",
            "Massaggiatore Secondo Operatore PAT AB12345 Comune Salerno",
            "Prep. Portiere De Rosa Gianluigi Tess. 181373 FIGC"
        ])

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .ospiti)

        #expect(result.staff.count == 6)
        #expect(result.staff.contains(where: { $0.roleKind == .allenatoreInSeconda && $0.fullName == "LIGUORI ALFONSO" }))
        #expect(result.staff.filter { $0.roleKind == .massaggiatore }.count == 2)
        #expect(result.issues.contains(where: { $0.message.contains("2 persone per il ruolo Massaggiatore") }))
    }

    @Test func ignoraHeaderOCRNellaListaGiocatori() {
        let rows = RapportoGaraDistinteParser.makeRows(from: [
            "Nr.Maglia G M A Cognome e Nome Cap/V. Cap. Matricola F.I.G.C. Documento di identificazione Tipo Numero Rilasciato",
            "1 07 05 08 LESTA OSCAR GIONA C.I. CA63570KF MIN.INTERNO",
            "2 28 06 07 DI FLORA DAVIDE C.I. CA26067VD MIN.INTERNO"
        ])

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .casa)

        #expect(result.players.count == 2)
        #expect(result.players[0].shirtNumber == "1")
        #expect(result.players[0].fullName == "LESTA OSCAR GIONA")
        #expect(result.players[1].shirtNumber == "2")
        #expect(result.players[1].fullName == "DI FLORA DAVIDE")
        #expect(result.players.allSatisfy { !$0.fullName.contains("COGNOME") && !$0.fullName.contains("MATRICOLA") })
    }

    @Test func separaGiocatoriFusiNellaStessaRigaOCR() {
        let rows = RapportoGaraDistinteParser.makeRows(from: [
            "7 26 09 95 CAPOZZOLI DONATO VK C.I. CA57098SC MIN.INTERNO 12 29 05 01 STASI FRANCESCO C.I. CA52570EG MIN.INTERNO"
        ])

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .casa)

        #expect(result.players.count == 2)
        #expect(result.players[0].shirtNumber == "7")
        #expect(result.players[0].fullName == "CAPOZZOLI DONATO")
        #expect(result.players[0].captainCode == "V")
        #expect(result.players[0].documentReleasedBy == "MIN.INTERNO")
        #expect(result.players[1].shirtNumber == "12")
        #expect(result.players[1].fullName == "STASI FRANCESCO")
        #expect(result.players[1].documentReleasedBy == "MIN.INTERNO")
    }

    @Test func separaGiocatoriQuandoUnaRigaOCRContieneDueBandeVerticali() {
        let rows = [
            RapportoGaraDistintaOCRRow(
                text: "15 16 03/10/2008 29/09/2007 RUSSO LEMBO CIRO VITO",
                fragments: [
                    RapportoGaraDistintaOCRFragment(text: "15", minX: 0.01, maxX: 0.03, midY: 0.80),
                    RapportoGaraDistintaOCRFragment(text: "03/10/2008", minX: 0.10, maxX: 0.20, midY: 0.80),
                    RapportoGaraDistintaOCRFragment(text: "RUSSO", minX: 0.28, maxX: 0.38, midY: 0.80),
                    RapportoGaraDistintaOCRFragment(text: "CIRO", minX: 0.40, maxX: 0.48, midY: 0.80),
                    RapportoGaraDistintaOCRFragment(text: "16", minX: 0.01, maxX: 0.03, midY: 0.788),
                    RapportoGaraDistintaOCRFragment(text: "29/09/2007", minX: 0.10, maxX: 0.20, midY: 0.788),
                    RapportoGaraDistintaOCRFragment(text: "LEMBO", minX: 0.28, maxX: 0.38, midY: 0.788),
                    RapportoGaraDistintaOCRFragment(text: "VITO", minX: 0.40, maxX: 0.48, midY: 0.788)
                ],
                order: 0
            )
        ]

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .casa)

        #expect(result.players.count == 2)
        #expect(result.players[0].shirtNumber == "15")
        #expect(result.players[0].fullName == "RUSSO CIRO")
        #expect(result.players[1].shirtNumber == "16")
        #expect(result.players[1].fullName == "LEMBO VITO")
    }

    @Test func leggeIlNumeroMagliaDallaColonnaSinistraAncheSeIlTestoRigaNonLoContiene() {
        let rows = [
            RapportoGaraDistintaOCRRow(
                text: "G M A Cognome e Nome Cap/V Cap Matricola FIGC Tipo Numero Rilasciato",
                fragments: [
                    RapportoGaraDistintaOCRFragment(text: "G", minX: 0.09, maxX: 0.10, midY: 0.90),
                    RapportoGaraDistintaOCRFragment(text: "M", minX: 0.12, maxX: 0.13, midY: 0.90),
                    RapportoGaraDistintaOCRFragment(text: "A", minX: 0.15, maxX: 0.16, midY: 0.90),
                    RapportoGaraDistintaOCRFragment(text: "Cognome e Nome", minX: 0.22, maxX: 0.38, midY: 0.90),
                    RapportoGaraDistintaOCRFragment(text: "Cap/V Cap", minX: 0.44, maxX: 0.50, midY: 0.90),
                    RapportoGaraDistintaOCRFragment(text: "Matricola FIGC", minX: 0.52, maxX: 0.60, midY: 0.90),
                    RapportoGaraDistintaOCRFragment(text: "Tipo", minX: 0.62, maxX: 0.66, midY: 0.90),
                    RapportoGaraDistintaOCRFragment(text: "Numero", minX: 0.70, maxX: 0.76, midY: 0.90),
                    RapportoGaraDistintaOCRFragment(text: "Rilasciato", minX: 0.82, maxX: 0.89, midY: 0.90)
                ],
                order: 0
            ),
            RapportoGaraDistintaOCRRow(
                text: "26 12 87 COSTANTINO STEFANO PAT U1U177941X MIT-UCO",
                fragments: [
                    RapportoGaraDistintaOCRFragment(text: "11", minX: 0.02, maxX: 0.05, midY: 0.85),
                    RapportoGaraDistintaOCRFragment(text: "26", minX: 0.09, maxX: 0.11, midY: 0.85),
                    RapportoGaraDistintaOCRFragment(text: "12", minX: 0.12, maxX: 0.14, midY: 0.85),
                    RapportoGaraDistintaOCRFragment(text: "87", minX: 0.15, maxX: 0.17, midY: 0.85),
                    RapportoGaraDistintaOCRFragment(text: "COSTANTINO", minX: 0.22, maxX: 0.31, midY: 0.85),
                    RapportoGaraDistintaOCRFragment(text: "STEFANO", minX: 0.32, maxX: 0.39, midY: 0.85),
                    RapportoGaraDistintaOCRFragment(text: "PAT", minX: 0.62, maxX: 0.65, midY: 0.85),
                    RapportoGaraDistintaOCRFragment(text: "U1U177941X", minX: 0.70, maxX: 0.78, midY: 0.85),
                    RapportoGaraDistintaOCRFragment(text: "MIT-UCO", minX: 0.82, maxX: 0.89, midY: 0.85)
                ],
                order: 1
            )
        ]

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .casa)

        #expect(result.players.count == 1)
        #expect(result.players[0].shirtNumber == "11")
        #expect(result.players[0].birthDate == "26/12/1987")
        #expect(result.players[0].fullName == "COSTANTINO STEFANO")
        #expect(result.players[0].documentKind == .patente)
        #expect(result.players[0].documentNumber == "U1U177941X")
        #expect(result.players[0].documentReleasedBy == "MIT-UCO")
    }

    @Test func mantieneOrdineOriginaleDellaDistintaSenzaRiordinarePerNumeroMaglia() {
        let rows = RapportoGaraDistinteParser.makeRows(from: [
            "18 06/12/2005 MAGLIANO ANTONINO C.I. CA49855RC CAMPAGNA",
            "6 26/01/1987 PASCUZZO VITO C.I. AX8258402 BUONABITACOLO",
            "20 29/11/2007 PERNA CRISTIAN C.I. CA66439MV LAVIANO"
        ])

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .casa)

        #expect(result.players.count == 3)
        #expect(result.players[0].shirtNumber == "18")
        #expect(result.players[1].shirtNumber == "6")
        #expect(result.players[2].shirtNumber == "20")
    }

    @Test func usaIlSecondoNumeroQuandoIlPrimoEIndiceRiga() {
        let rows = RapportoGaraDistinteParser.makeRows(from: [
            "2 18 06/12/2005 MAGLIANO ANTONINO C.I. CA49855RC CAMPAGNA",
            "3 6 26/01/1987 PASCUZZO VITO C.I. AX8258402 BUONABITACOLO"
        ])

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .casa)

        #expect(result.players.count == 2)
        #expect(result.players[0].shirtNumber == "18")
        #expect(result.players[0].fullName == "MAGLIANO ANTONINO")
        #expect(result.players[1].shirtNumber == "6")
        #expect(result.players[1].fullName == "PASCUZZO VITO")
    }

    @Test func mantieneIlGiocatoreAncheSeLaDataNonEVieneRiconosciuta() {
        let rows = RapportoGaraDistinteParser.makeRows(from: [
            "11 SENATORE FRANCESCO PIO C.I. CA797270K CAVA DEI TIRRENI",
            "14 SANTONICOLA FRANCESCO C.I. CA13626L4 POLLICA"
        ])

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .casa)

        #expect(result.players.count == 2)
        #expect(result.players[0].shirtNumber == "11")
        #expect(result.players[0].fullName == "SENATORE FRANCESCO PIO")
        #expect(result.players[0].birthDate.isEmpty)
        #expect(result.players[1].shirtNumber == "14")
        #expect(result.players[1].fullName == "SANTONICOLA FRANCESCO")
    }

    @Test func nonScambiaLaColonnaGiornoPerNumeroMagliaQuandoIlNumeroManca() {
        let rows = RapportoGaraDistinteParser.makeRows(from: [
            "07 05 08 LESTA OSCAR GIONA C.I. CA63570KF MIN.INTERNO"
        ])

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .casa)

        #expect(result.players.count == 1)
        #expect(result.players[0].shirtNumber.isEmpty)
        #expect(result.players[0].birthDate == "07/05/2008")
        #expect(result.players[0].fullName == "LESTA OSCAR GIONA")
        #expect(result.issues.contains(where: { $0.message.contains("Numero maglia non riconosciuto") }))
    }

    @Test func nonSegnalaDueAllenatoriQuandoIlSecondoERiconosciutoComeAllenatoreInSeconda() {
        let rows = RapportoGaraDistinteParser.makeRows(from: [
            "Allenatore Squillante Luigi Tess. 43762 LND",
            "Allenatore II Liguori Alfonso Tess. 108952 FIGC"
        ])

        let result = RapportoGaraDistinteParser.parse(rows: rows, lato: .ospiti)

        #expect(result.staff.count == 2)
        #expect(result.staff.contains(where: { $0.roleKind == .allenatore && $0.fullName == "SQUILLANTE LUIGI" }))
        #expect(result.staff.contains(where: { $0.roleKind == .allenatoreInSeconda && $0.fullName == "LIGUORI ALFONSO" }))
        #expect(!result.issues.contains(where: { $0.message.contains("ruolo Allenatore") }))
    }
}
