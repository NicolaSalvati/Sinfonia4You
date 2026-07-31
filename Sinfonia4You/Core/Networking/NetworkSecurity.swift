import CryptoKit
import Foundation
import Security

/// Validazione TLS del backend Sinfonia4You con certificate pinning SPKI.
///
/// Contesto: il backend risponde su un indirizzo IP, quindi non puo' avere un
/// certificato pubblico emesso da una CA per un nome di dominio. Finora l'app
/// aggirava il problema disattivando App Transport Security
/// (`NSAllowsArbitraryLoads = YES`), il che rendeva possibile un attacco
/// man-in-the-middle su qualunque Wi-Fi: credenziali AIA e token di sessione
/// erano intercettabili.
///
/// Qui ATS resta attivo e la fiducia viene concessa solo se la chiave pubblica
/// del server corrisponde a un pin noto. Si pinna la SPKI (Subject Public Key
/// Info) e non il certificato: cosi' il certificato puo' essere rinnovato senza
/// aggiornare l'app, purche' venga riusata la stessa chiave.
enum BackendPinning {

    /// Chiave Info.plist con i pin SPKI in base64, separati da virgola.
    ///
    /// Come calcolare il pin del server:
    /// ```sh
    /// openssl s_client -connect IL_TUO_HOST:443 </dev/null 2>/dev/null \
    ///   | openssl x509 -pubkey -noout \
    ///   | openssl pkey -pubin -outform der \
    ///   | openssl dgst -sha256 -binary \
    ///   | openssl enc -base64
    /// ```
    static let infoPlistPinsKey = "SINFONIA_API_PINS"

    /// Pin di riserva compilati nel binario.
    ///
    /// IMPORTANTE: inserire sempre almeno due pin, quello attivo e quello di
    /// backup della prossima chiave. Con un solo pin, la perdita della chiave
    /// rende l'app inutilizzabile fino a un aggiornamento su App Store.
    static let fallbackPins: Set<String> = [
        // TODO: pin SPKI del certificato di produzione.
        // TODO: pin SPKI della chiave di backup.
    ]

    /// Pin effettivamente in uso: Info.plist se presente, altrimenti i fallback.
    static var configuredPins: Set<String> {
        let raw = Bundle.main.object(forInfoDictionaryKey: infoPlistPinsKey) as? String ?? ""
        let fromPlist = raw
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return fromPlist.isEmpty ? fallbackPins : Set(fromPlist)
    }

    /// Host per cui il pinning viene applicato.
    ///
    /// Gli host di sviluppo locale sono esclusi: girano in HTTP o con
    /// certificati usa e getta sulla macchina dello sviluppatore.
    static func requiresPinning(host: String) -> Bool {
        let clean = host.lowercased()
        if clean == "localhost" || clean == "127.0.0.1" || clean == "::1" {
            return false
        }
        if clean.hasPrefix("192.168.") || clean.hasPrefix("10.") {
            return false
        }
        return true
    }

    /// SHA-256 in base64 della SPKI di un certificato.
    static func spkiPin(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let attributes = SecKeyCopyAttributes(publicKey) as? [CFString: Any],
              let keyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }

        let keyType = attributes[kSecAttrKeyType] as? String
        let keySize = attributes[kSecAttrKeySizeInBits] as? Int ?? 0

        guard let header = asn1Header(keyType: keyType, keySize: keySize) else {
            return nil
        }

        // SecKeyCopyExternalRepresentation restituisce la chiave grezza: per
        // ottenere la SPKI in DER va anteposto l'header ASN.1 corretto.
        var spki = Data(header)
        spki.append(keyData)

        return Data(SHA256.hash(data: spki)).base64EncodedString()
    }

    private static func asn1Header(keyType: String?, keySize: Int) -> [UInt8]? {
        let isRSA = keyType == (kSecAttrKeyTypeRSA as String)
        let isEC = keyType == (kSecAttrKeyTypeECSECPrimeRandom as String)

        if isRSA && keySize == 2048 {
            return [
                0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48,
                0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01,
                0x0f, 0x00,
            ]
        }
        if isRSA && keySize == 4096 {
            return [
                0x30, 0x82, 0x02, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48,
                0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x02,
                0x0f, 0x00,
            ]
        }
        if isEC && keySize == 256 {
            return [
                0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d,
                0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01,
                0x07, 0x03, 0x42, 0x00,
            ]
        }
        if isEC && keySize == 384 {
            return [
                0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d,
                0x02, 0x01, 0x06, 0x05, 0x2b, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62,
                0x00,
            ]
        }
        return nil
    }
}

/// Delegate di `URLSession` che applica il pinning alle connessioni verso il
/// backend e lascia intatto il comportamento di sistema altrove.
final class BackendTrustDelegate: NSObject, URLSessionDelegate {

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // Sviluppo locale: nessun pinning, vale la policy di sistema.
        guard BackendPinning.requiresPinning(host: host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let pins = BackendPinning.configuredPins

        // Nessun pin configurato: non si abbassa la guardia. Si applica la
        // validazione di sistema, quindi un certificato non valido viene
        // rifiutato come deve essere.
        guard !pins.isEmpty else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        var trustError: CFError?
        let systemTrusted = SecTrustEvaluateWithError(serverTrust, &trustError)

        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              !chain.isEmpty else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Si accetta se un qualunque certificato della catena combacia con un
        // pin: consente di pinnare la CA interna oppure direttamente la foglia.
        let matched = chain.contains { certificate in
            guard let pin = BackendPinning.spkiPin(for: certificate) else { return false }
            return pins.contains(pin)
        }

        if matched {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }

        #if DEBUG
        print("[Pinning] Chiave pubblica non attesa per \(host). Sistema: \(systemTrusted)")
        #endif

        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
