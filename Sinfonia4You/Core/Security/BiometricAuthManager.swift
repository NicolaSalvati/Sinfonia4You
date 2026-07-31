import Foundation
import LocalAuthentication
import Security

enum BiometricKind: Equatable {
    case none
    case faceID
    case touchID

    var displayName: String {
        switch self {
        case .none:
            return "Biometria"
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        }
    }

    var iconName: String {
        switch self {
        case .none:
            return "lock.shield"
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        }
    }
}

struct BiometricAuthState: Equatable {
    let kind: BiometricKind
    let isAvailable: Bool
    let isEnabled: Bool
    let hasStoredCredentials: Bool

    var displayName: String { kind.displayName }
    var iconName: String { kind.iconName }
    var canLogin: Bool { isAvailable && isEnabled && hasStoredCredentials }
}

struct StoredPortalCredentials: Codable, Equatable {
    let username: String
    let password: String
}

enum BiometricAuthError: LocalizedError {
    case notAvailable(String)
    case notConfigured
    case invalidCredentials
    case cancelled
    case unexpected(OSStatus)

    var errorDescription: String? {
        switch self {
        case .notAvailable(let message):
            return message
        case .notConfigured:
            return "Attiva prima l'accesso biometrico nelle impostazioni dell'app."
        case .invalidCredentials:
            return "Non riesco a leggere le credenziali salvate in modo sicuro sul dispositivo."
        case .cancelled:
            return nil
        case .unexpected:
            return "Non sono riuscito a completare l'operazione con la biometria."
        }
    }
}

final class BiometricAuthManager {
    static let shared = BiometricAuthManager()

    private let service = "nicola.Sinfonia4You.secure-login"
    private let account = "app-auth"
    private let defaultsKey = "sinfonia4you.biometric-login.enabled.v3"
    private let legacyDefaultsKeys = [
        "sinfonia4you.biometric-login.enabled",
        "sinfonia4you.biometric-login.enabled.v2"
    ]

    private init() {}

    func currentState() -> BiometricAuthState {
        normalizeStoredPreference()
        let availability = evaluateAvailability()
        let requested = UserDefaults.standard.bool(forKey: defaultsKey)
        let storedCredentials = requested ? hasStoredCredentials() : false
        let enabled = requested && storedCredentials

        if requested && !storedCredentials {
            UserDefaults.standard.set(false, forKey: defaultsKey)
        }

        return BiometricAuthState(
            kind: availability.kind,
            isAvailable: availability.isAvailable,
            isEnabled: enabled,
            hasStoredCredentials: storedCredentials
        )
    }

    func enable(with credentials: StoredPortalCredentials) throws {
        normalizeStoredPreference()
        let availability = evaluateAvailability()
        guard availability.isAvailable else {
            throw BiometricAuthError.notAvailable(availability.message)
        }

        let cleanUsername = credentials.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUsername.isEmpty, !credentials.password.isEmpty else {
            throw BiometricAuthError.invalidCredentials
        }

        let data = try JSONEncoder().encode(
            StoredPortalCredentials(username: cleanUsername, password: credentials.password)
        )

        var accessControlError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            &accessControlError
        ) else {
            throw BiometricAuthError.unexpected(errSecParam)
        }

        SecItemDelete(baseQuery as CFDictionary)

        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessControl as String] = accessControl

        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BiometricAuthError.unexpected(status)
        }

        UserDefaults.standard.set(true, forKey: defaultsKey)
    }

    func disable() {
        SecItemDelete(baseQuery as CFDictionary)
        UserDefaults.standard.set(false, forKey: defaultsKey)
    }

    func loadCredentials(prompt: String) throws -> StoredPortalCredentials {
        normalizeStoredPreference()
        guard UserDefaults.standard.bool(forKey: defaultsKey) else {
            throw BiometricAuthError.notConfigured
        }

        let availability = evaluateAvailability()
        guard availability.isAvailable else {
            throw BiometricAuthError.notAvailable(availability.message)
        }

        let context = LAContext()
        context.localizedCancelTitle = "Annulla"
        context.localizedReason = prompt

        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw BiometricAuthError.notConfigured
            }
            if status == errSecUserCanceled {
                throw BiometricAuthError.cancelled
            }
            throw BiometricAuthError.unexpected(status)
        }

        guard let data = item as? Data,
              let credentials = try? JSONDecoder().decode(StoredPortalCredentials.self, from: data) else {
            throw BiometricAuthError.invalidCredentials
        }

        return credentials
    }

    private func hasStoredCredentials() -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true

        var query = baseQuery
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    private func normalizeStoredPreference() {
        if UserDefaults.standard.object(forKey: defaultsKey) == nil {
            UserDefaults.standard.set(false, forKey: defaultsKey)
        }

        for key in legacyDefaultsKeys where UserDefaults.standard.object(forKey: key) != nil {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func evaluateAvailability() -> (kind: BiometricKind, isAvailable: Bool, message: String) {
        let context = LAContext()
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        let kind: BiometricKind

        switch context.biometryType {
        case .faceID:
            kind = .faceID
        case .touchID:
            kind = .touchID
        default:
            kind = .none
        }

        guard available else {
            return (kind, false, availabilityMessage(for: error, kind: kind))
        }

        return (kind, true, "")
    }

    private func availabilityMessage(for error: NSError?, kind: BiometricKind) -> String {
        let label = kind.displayName
        guard let error else {
            return "\(label) non disponibile su questo dispositivo."
        }

        switch LAError.Code(rawValue: error.code) {
        case .biometryNotAvailable:
            return "\(label) non disponibile su questo dispositivo."
        case .biometryNotEnrolled:
            return "Configura \(label) nelle impostazioni di iPhone per usarlo nell'app."
        case .passcodeNotSet:
            return "Imposta prima un codice di sblocco su iPhone per usare \(label)."
        default:
            return error.localizedDescription
        }
    }
}
