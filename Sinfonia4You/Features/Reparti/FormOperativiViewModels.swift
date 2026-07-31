//
//  FormOperativiViewModels.swift
//  Sinfonia4You
//
//  ViewModel per i reparti operativi in scrittura.
//

import Combine
import Foundation

@MainActor
final class IbanOperativoViewModel: ObservableObject {
    @Published var config: IbanConfigDTO?
    @Published var ibanCode = ""
    @Published var dichiarazioneConfermata = false
    @Published var fileSelezionato: FileSelezionatoApp?
    @Published var inCaricamento = false
    @Published var inInvio = false
    @Published var errore = ""
    @Published var messaggio = ""

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var puoPresentareConferma: Bool {
        let ibanNormalizzato = Self.normalizzaIban(ibanCode)
        return !inInvio && !ibanNormalizzato.isEmpty && dichiarazioneConfermata
    }

    func carica(token: String) async {
        inCaricamento = true
        errore = ""
        defer { inCaricamento = false }
        do {
            config = try await apiClient.formIban(token: token)
        } catch {
            errore = error.localizedDescription
        }
    }

    func aggiornaIbanInput(_ rawValue: String) {
        let normalized = Self.normalizzaIban(rawValue)
        guard normalized != rawValue else { return }
        ibanCode = normalized
    }

    func preparaInvio() -> Bool {
        errore = ""
        messaggio = ""

        let normalized = Self.normalizzaIban(ibanCode)
        if normalized != ibanCode {
            ibanCode = normalized
        }

        guard dichiarazioneConfermata else {
            errore = "Occorre accettare la dichiarazione di responsabilità."
            return false
        }

        let validationError = Self.validaIban(normalized)
        guard validationError.isEmpty else {
            errore = validationError
            return false
        }

        return true
    }

    func invia(token: String) async -> Bool {
        guard !inInvio else { return false }
        let normalizedIban = Self.normalizzaIban(ibanCode)

        guard dichiarazioneConfermata else {
            errore = "Occorre accettare la dichiarazione di responsabilità."
            return false
        }

        let validationError = Self.validaIban(normalizedIban)
        guard validationError.isEmpty else {
            errore = validationError
            return false
        }

        inInvio = true
        errore = ""
        messaggio = ""
        defer { inInvio = false }
        do {
            let esito = try await apiClient.inviaIban(token: token, ibanCode: normalizedIban, file: fileSelezionato)
            messaggio = esito.message
            await carica(token: token)
            ibanCode = ""
            dichiarazioneConfermata = false
            fileSelezionato = nil
            return true
        } catch {
            errore = error.localizedDescription
            return false
        }
    }

    private static func normalizzaIban(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .uppercased()
    }

    private static func validaIban(_ rawValue: String) -> String {
        let iban = normalizzaIban(rawValue)
        if iban.isEmpty {
            return "Inserisci un codice IBAN valido."
        }
        if iban == "N" {
            return ""
        }
        if iban.count != 27 {
            return "L'IBAN deve essere di 27 caratteri."
        }
        if !iban.hasPrefix("I") {
            return "La prima lettera dell'IBAN deve essere I."
        }
        let secondCharacter = iban[iban.index(after: iban.startIndex)]
        if secondCharacter != Character("T") {
            return "La seconda lettera dell'IBAN deve essere T."
        }
        let digitStart = iban.index(iban.startIndex, offsetBy: 2)
        let digitEnd = iban.index(iban.startIndex, offsetBy: 4)
        if !iban[digitStart..<digitEnd].allSatisfy(\.isNumber) {
            return "Il terzo e il quarto carattere dell'IBAN devono essere numerici."
        }
        let fifthCharacter = iban[iban.index(iban.startIndex, offsetBy: 4)]
        if !fifthCharacter.isLetter {
            return "Il quinto carattere dell'IBAN deve essere una lettera."
        }
        if !iban.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return "L'IBAN contiene caratteri non validi."
        }

        let rotated = String(iban.dropFirst(4)) + String(iban.prefix(4))
        var remainder = 0
        for character in rotated {
            if character.isNumber, let digit = character.wholeNumberValue {
                remainder = (remainder * 10 + digit) % 97
            } else {
                let value = Int(character.uppercased().unicodeScalars.first!.value) - 55
                for digitCharacter in String(value) {
                    guard let digit = digitCharacter.wholeNumberValue else { continue }
                    remainder = (remainder * 10 + digit) % 97
                }
            }
        }

        if remainder != 1 {
            return "Codice IBAN non valido."
        }
        return ""
    }
}

@MainActor
final class RinnovoCertificatoViewModel: ObservableObject {
    @Published var config: CertificateRenewalConfigDTO?
    @Published var tipoSelezionato = ""
    @Published var dataRilascio = ""
    @Published var dataScadenza = ""
    @Published var enteCertificatore = ""
    @Published var note = ""
    @Published var fileSelezionato: FileSelezionatoApp?
    @Published var inCaricamento = false
    @Published var inInvio = false
    @Published var errore = ""
    @Published var messaggio = ""

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func carica(token: String) async {
        inCaricamento = true
        errore = ""
        defer { inCaricamento = false }
        do {
            let loaded = try await apiClient.formRinnovoCertificato(token: token)
            config = loaded
            if tipoSelezionato.isEmpty {
                tipoSelezionato = loaded.types.first?.value ?? ""
            }
        } catch {
            errore = error.localizedDescription
        }
    }

    func invia(token: String) async -> Bool {
        guard !inInvio, let fileSelezionato else { return false }
        inInvio = true
        errore = ""
        messaggio = ""
        defer { inInvio = false }
        do {
            let esito = try await apiClient.inviaRinnovoCertificato(
                token: token,
                certType: tipoSelezionato,
                releaseDate: dataRilascio,
                expiryDate: dataScadenza,
                issuer: enteCertificatore,
                note: note,
                file: fileSelezionato
            )
            messaggio = esito.message
            await carica(token: token)
            resetBozza()
            return true
        } catch {
            errore = error.localizedDescription
            return false
        }
    }

    private func resetBozza() {
        dataRilascio = ""
        dataScadenza = ""
        enteCertificatore = ""
        note = ""
        fileSelezionato = nil
    }
}

@MainActor
final class IndisponibilitaOperativaViewModel: ObservableObject {
    @Published var config: IndisponibilitaConfigDTO?
    @Published var startDate = ""
    @Published var endDate = ""
    @Published var tipoSelezionato = ""
    @Published var motivoSelezionato = ""
    @Published var note = ""
    @Published var fileSelezionato: FileSelezionatoApp?
    @Published var inCaricamento = false
    @Published var inInvio = false
    @Published var errore = ""
    @Published var messaggio = ""

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func carica(token: String) async {
        inCaricamento = true
        errore = ""
        defer { inCaricamento = false }
        do {
            let loaded = try await apiClient.formIndisponibilita(token: token)
            config = loaded
            if tipoSelezionato.isEmpty {
                tipoSelezionato = loaded.types.first?.value ?? ""
            }
            if motivoSelezionato.isEmpty {
                motivoSelezionato = loaded.reasons.first?.value ?? ""
            }
        } catch {
            errore = error.localizedDescription
        }
    }

    func invia(token: String) async -> Bool {
        guard !inInvio else { return false }
        inInvio = true
        errore = ""
        messaggio = ""
        defer { inInvio = false }
        do {
            let esito = try await apiClient.inviaIndisponibilita(
                token: token,
                startDate: startDate,
                endDate: endDate,
                typeValue: tipoSelezionato,
                reasonValue: motivoSelezionato,
                note: note,
                file: fileSelezionato
            )
            messaggio = esito.message
            await carica(token: token)
            resetBozza()
            return true
        } catch {
            errore = error.localizedDescription
            return false
        }
    }

    private func resetBozza() {
        startDate = ""
        endDate = ""
        note = ""
        fileSelezionato = nil
    }
}

@MainActor
final class CongedoOperativoViewModel: ObservableObject {
    @Published var config: CongedoConfigDTO?
    @Published var startDate = ""
    @Published var endDate = ""
    @Published var motivoSelezionato = ""
    @Published var note = ""
    @Published var fileSelezionato: FileSelezionatoApp?
    @Published var inCaricamento = false
    @Published var inInvio = false
    @Published var errore = ""
    @Published var messaggio = ""

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func carica(token: String) async {
        inCaricamento = true
        errore = ""
        defer { inCaricamento = false }
        do {
            let loaded = try await apiClient.formCongedo(token: token)
            config = loaded
            if motivoSelezionato.isEmpty {
                motivoSelezionato = loaded.reasons.first?.value ?? ""
            }
        } catch {
            errore = error.localizedDescription
        }
    }

    func invia(token: String) async -> Bool {
        guard !inInvio else { return false }
        inInvio = true
        errore = ""
        messaggio = ""
        defer { inInvio = false }
        do {
            let esito = try await apiClient.inviaCongedo(
                token: token,
                startDate: startDate,
                endDate: endDate,
                reasonValue: motivoSelezionato,
                note: note,
                file: fileSelezionato
            )
            messaggio = esito.message
            await carica(token: token)
            resetBozza()
            return true
        } catch {
            errore = error.localizedDescription
            return false
        }
    }

    private func resetBozza() {
        startDate = ""
        endDate = ""
        note = ""
        fileSelezionato = nil
    }
}

@MainActor
final class PreclusioneOperativaViewModel: ObservableObject {
    @Published var config: PreclusioneConfigDTO?
    @Published var tipoSelezionato = ""
    @Published var opzioneSpeciale = "0"
    @Published var endDate = ""
    @Published var filtroCampo = ""
    @Published var filtroScope = ""
    @Published var filtroRisultati = ""
    @Published var termineRicerca = ""
    @Published var risultati: [RisultatoPreclusioneDTO] = []
    @Published var selezioneId = ""
    @Published var selezioneLabel = ""
    @Published var note = ""
    @Published var inCaricamento = false
    @Published var inRicerca = false
    @Published var inInvio = false
    @Published var errore = ""
    @Published var messaggio = ""

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func carica(token: String) async {
        inCaricamento = true
        errore = ""
        defer { inCaricamento = false }
        do {
            let loaded = try await apiClient.formPreclusione(token: token)
            config = loaded
            if tipoSelezionato.isEmpty {
                tipoSelezionato = loaded.types.first?.value ?? "1"
            }
            applicaDefaultRicerca()
        } catch {
            errore = error.localizedDescription
        }
    }

    func aggiornaTipo(_ value: String) {
        tipoSelezionato = value
        selezioneId = ""
        selezioneLabel = ""
        risultati = []
        termineRicerca = ""
        applicaDefaultRicerca()
    }

    func cerca(token: String) async {
        guard !inRicerca else { return }
        inRicerca = true
        errore = ""
        defer { inRicerca = false }
        do {
            risultati = try await apiClient.cercaPreclusione(
                token: token,
                preclType: tipoSelezionato,
                filterField: filtroCampo,
                filterScope: filtroScope,
                filterResult: filtroRisultati,
                term: termineRicerca
            )
        } catch {
            errore = error.localizedDescription
        }
    }

    func selezionaRisultato(_ result: RisultatoPreclusioneDTO) {
        selezioneId = result.itemId
        selezioneLabel = result.label
    }

    func invia(token: String) async -> Bool {
        guard !inInvio else { return false }
        inInvio = true
        errore = ""
        messaggio = ""
        defer { inInvio = false }
        do {
            let esito = try await apiClient.inviaPreclusione(
                token: token,
                endDate: endDate,
                specialCase: opzioneSpeciale,
                preclType: tipoSelezionato,
                selectionId: selezioneId,
                selectionLabel: selezioneLabel,
                note: note,
                filterField: filtroCampo,
                filterScope: filtroScope,
                filterResult: filtroRisultati,
                searchTerm: termineRicerca
            )
            messaggio = esito.message
            await carica(token: token)
            resetBozza()
            return true
        } catch {
            errore = error.localizedDescription
            return false
        }
    }

    var configRicercaCorrente: PreclusioneSearchConfigDTO {
        switch tipoSelezionato {
        case "2":
            return config?.squadraSearch ?? PreclusioneSearchConfigDTO(fieldOptions: [], scopeOptions: [], resultOptions: [])
        case "3":
            return config?.impiantoSearch ?? PreclusioneSearchConfigDTO(fieldOptions: [], scopeOptions: [], resultOptions: [])
        default:
            return config?.societaSearch ?? PreclusioneSearchConfigDTO(fieldOptions: [], scopeOptions: [], resultOptions: [])
        }
    }

    private func applicaDefaultRicerca() {
        let search = configRicercaCorrente
        if !search.fieldOptions.contains(where: { $0.value == filtroCampo }) {
            filtroCampo = search.fieldOptions.first?.value ?? ""
        }
        if !search.scopeOptions.contains(where: { $0.value == filtroScope }) {
            filtroScope = search.scopeOptions.first?.value ?? ""
        }
        if !search.resultOptions.contains(where: { $0.value == filtroRisultati }) {
            filtroRisultati = search.resultOptions.first?.value ?? ""
        }
    }

    private func resetBozza() {
        opzioneSpeciale = "0"
        endDate = ""
        termineRicerca = ""
        risultati = []
        selezioneId = ""
        selezioneLabel = ""
        note = ""
    }
}

@MainActor
final class DomandeOperativeViewModel: ObservableObject {
    @Published var config: DomandeConfigDTO?
    @Published var domandaSelezionata = ""
    @Published var note = ""
    @Published var fileSelezionato: FileSelezionatoApp?
    @Published var inCaricamento = false
    @Published var inInvio = false
    @Published var errore = ""
    @Published var messaggio = ""

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func carica(token: String) async {
        inCaricamento = true
        errore = ""
        defer { inCaricamento = false }
        do {
            let loaded = try await apiClient.formDomande(token: token)
            config = loaded
            if domandaSelezionata.isEmpty {
                domandaSelezionata = loaded.options.first?.value ?? ""
            }
        } catch {
            errore = error.localizedDescription
        }
    }

    func invia(token: String) async -> Bool {
        guard !inInvio, let fileSelezionato else { return false }
        inInvio = true
        errore = ""
        messaggio = ""
        defer { inInvio = false }
        do {
            let esito = try await apiClient.inviaDomanda(
                token: token,
                questionValue: domandaSelezionata,
                note: note,
                file: fileSelezionato
            )
            messaggio = esito.message
            await carica(token: token)
            resetBozza()
            return true
        } catch {
            errore = error.localizedDescription
            return false
        }
    }

    private func resetBozza() {
        note = ""
        fileSelezionato = nil
    }
}

@MainActor
final class DocumentiOperativiViewModel: ObservableObject {
    @Published var config: DocumentsConfigDTO?
    @Published var fileSelezionato: FileSelezionatoApp?
    @Published var documentoAttivo: DocumentoConfigItemDTO?
    @Published var inCaricamento = false
    @Published var inInvio = false
    @Published var errore = ""
    @Published var messaggio = ""

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var items: [DocumentoConfigItemDTO] {
        config?.items ?? []
    }

    var documentiDaCaricare: [DocumentoConfigItemDTO] {
        items.filter {
            let hasAttachment = !$0.attachmentUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasUploadDate = !$0.uploadedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return $0.statusCode == "missing" && !hasAttachment && !hasUploadDate
        }
    }

    var documentiInAttesa: [DocumentoConfigItemDTO] {
        items.filter { $0.statusCode == "pending" }
    }

    var documentiCaricati: [DocumentoConfigItemDTO] {
        items.filter { item in
            !documentiDaCaricare.contains(where: { $0.id == item.id })
                && !documentiInAttesa.contains(where: { $0.id == item.id })
        }
    }

    var puoInviareDocumento: Bool {
        documentoAttivo != nil && fileSelezionato != nil && !inInvio
    }

    func carica(token: String) async {
        inCaricamento = true
        errore = ""
        defer { inCaricamento = false }
        do {
            config = try await apiClient.formDocumenti(token: token)
        } catch {
            errore = error.localizedDescription
        }
    }

    func preparaUpload(per item: DocumentoConfigItemDTO) {
        errore = ""
        messaggio = ""
        documentoAttivo = item
        fileSelezionato = nil
    }

    func chiudiUpload() {
        documentoAttivo = nil
        fileSelezionato = nil
    }

    func invia(token: String) async -> Bool {
        guard !inInvio, let documentoAttivo else { return false }
        guard let fileSelezionato else {
            errore = "Seleziona un file PDF prima di procedere."
            return false
        }
        inInvio = true
        errore = ""
        messaggio = ""
        defer { inInvio = false }
        do {
            let esito = try await apiClient.caricaDocumento(
                token: token,
                typeId: documentoAttivo.typeId,
                file: fileSelezionato
            )
            messaggio = esito.message
            await carica(token: token)
            chiudiUpload()
            return true
        } catch {
            errore = error.localizedDescription
            return false
        }
    }
}

@MainActor
final class AccountOperativoViewModel: ObservableObject {
    @Published var config: AccountPasswordConfigDTO?
    @Published var oldPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var inCaricamento = false
    @Published var inInvio = false
    @Published var errore = ""
    @Published var messaggio = ""
    @Published var richiedeNuovoLogin = false

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var puoInviare: Bool {
        !oldPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        !inInvio
    }

    func carica(token: String) async {
        inCaricamento = true
        errore = ""
        defer { inCaricamento = false }
        do {
            config = try await apiClient.formAccount(token: token)
        } catch {
            errore = error.localizedDescription
        }
    }

    func invia(token: String) async -> Bool {
        guard !inInvio else { return false }
        let oldValue = oldPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let confirmValue = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !oldValue.isEmpty, !newValue.isEmpty, !confirmValue.isEmpty else {
            errore = "Compila tutti i campi prima di confermare il cambio password."
            return false
        }

        guard newValue == confirmValue else {
            errore = "La nuova password e la conferma non coincidono."
            return false
        }

        guard oldValue != newValue else {
            errore = "La nuova password deve essere diversa da quella attuale."
            return false
        }

        inInvio = true
        errore = ""
        messaggio = ""
        defer { inInvio = false }
        do {
            let esito = try await apiClient.cambiaPassword(
                token: token,
                oldPassword: oldValue,
                newPassword: newValue,
                confirmPassword: confirmValue
            )
            messaggio = esito.message
            richiedeNuovoLogin = esito.requiresRelogin ?? false
            oldPassword = ""
            newPassword = ""
            confirmPassword = ""
            return true
        } catch {
            errore = error.localizedDescription
            return false
        }
    }
}

@MainActor
final class EventiOperativiViewModel: ObservableObject {
    @Published var items: [EventoItemDTO] = []
    @Published var inCaricamento = false
    @Published var inInvio = false
    @Published var errore = ""
    @Published var messaggio = ""

    private let apiClient: APIClient

    init() {
        self.apiClient = .shared
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func carica(token: String) async {
        inCaricamento = true
        errore = ""
        defer { inCaricamento = false }
        do {
            items = try await apiClient.eventi(token: token)
        } catch {
            errore = error.localizedDescription
        }
    }

    func accetta(token: String, eventId: String) async {
        guard !inInvio else { return }
        inInvio = true
        errore = ""
        messaggio = ""
        defer { inInvio = false }
        do {
            items = try await apiClient.accettaEvento(token: token, eventId: eventId)
            messaggio = "Convocazione evento accettata correttamente."
        } catch {
            errore = error.localizedDescription
        }
    }
}
