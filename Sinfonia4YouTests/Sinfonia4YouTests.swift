//
//  Sinfonia4YouTests.swift
//  Sinfonia4YouTests
//
//  Created by Dalle on 14/03/26.
//

import Testing
@testable import Sinfonia4You

struct Sinfonia4YouTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func parseParametriPaginaClassificaTuttocampo() {
        let html = """
        <script>
        var currentMatchDay='33';
        var tckk='cd1ce24d32cf5dbc478151718ab48fca4a7081bf';
        var roundID='CP.E.B';
        </script>
        """

        let result = TuttocampoOfficialStandingsParser.parsePageParameters(from: html)

        #expect(result == TuttocampoOfficialStandingsPageParameters(
            tckk: "cd1ce24d32cf5dbc478151718ab48fca4a7081bf",
            roundID: "CP.E.B"
        ))
    }

    @Test func parseRigheClassificaUfficialeTuttocampo() {
        let html = """
        <table class="tc-table sticky table_ranking sortable">
        <tbody>
        <tr class="promotion 1018931" data-team-id="1018931">
        <td class="last_match"><img alt="vittoria"/></td>
        <td class="team_logo"><img alt="logo Ebolitana Calcio 1925"/></td>
        <td class="team"><a href="https://www.tuttocampo.it/Campania/SA/Eccellenza/GironeB/Squadra/EbolitanaCalcio1925/1018931/Scheda">Ebolitana Calcio 1925</a></td>
        <td class="points">70</td>
        <td>32</td>
        <td>20</td>
        <td>10</td>
        <td>2</td>
        <td>55</td>
        <td>23</td>
        <td>32</td>
        <td class="details"><img alt="Grafico"/></td>
        </tr>
        <tr class="playoff 933590" data-team-id="933590">
        <td class="last_match"><img alt="vittoria"/></td>
        <td class="team_logo"><img alt="logo Battipagliese Calcio"/></td>
        <td class="team"><a href="https://www.tuttocampo.it/Campania/SA/Eccellenza/GironeB/Squadra/BattipaglieseCalcio/933590/Scheda">Battipagliese Calcio</a></td>
        <td class="points">65</td>
        <td>32</td>
        <td>19</td>
        <td>8</td>
        <td>5</td>
        <td>64</td>
        <td>32</td>
        <td>32</td>
        <td class="details"><img alt="Grafico"/></td>
        </tr>
        </tbody>
        </table>
        """

        let rows = TuttocampoOfficialStandingsParser.parseRows(from: html)

        #expect(rows.count == 2)
        #expect(rows[0].position == 1)
        #expect(rows[0].teamId == "1018931")
        #expect(rows[0].team == "Ebolitana Calcio 1925")
        #expect(rows[0].points == 70)
        #expect(rows[0].played == 32)
        #expect(rows[0].goalDiff == 32)
        #expect(rows[1].position == 2)
        #expect(rows[1].teamId == "933590")
        #expect(rows[1].team == "Battipagliese Calcio")
        #expect(rows[1].points == 65)
        #expect(rows[1].won == 19)
        #expect(rows[1].lost == 5)
    }

}
