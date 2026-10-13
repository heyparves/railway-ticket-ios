import CommonCrypto
import Foundation
import Security

/// Salted PBKDF2-SHA256 password hashing. Only the derived hash and salt are stored.
struct PasswordHash: Codable, Equatable, Sendable {
    let salt: Data
    let hash: Data
    let iterations: UInt32
}

enum PasswordHasher {
    static let defaultIterations: UInt32 = 210_000
    private static let keyLength = 32

    static func hash(_ password: String, iterations: UInt32 = defaultIterations) -> PasswordHash {
        let salt = randomBytes(count: 16)
        return PasswordHash(salt: salt, hash: derive(password, salt: salt, iterations: iterations), iterations: iterations)
    }

    static func verify(_ password: String, against stored: PasswordHash) -> Bool {
        let candidate = derive(password, salt: stored.salt, iterations: stored.iterations)
        return constantTimeEquals(candidate, stored.hash)
    }

    private static func derive(_ password: String, salt: Data, iterations: UInt32) -> Data {
        let passwordData = Data(password.utf8)
        var derived = Data(count: keyLength)
        let status = derived.withUnsafeMutableBytes { derivedBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: CChar.self), passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations,
                        derivedBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), keyLength
                    )
                }
            }
        }
        precondition(status == kCCSuccess, "PBKDF2 failed with status \(status)")
        return derived
    }

    private static func randomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        return Data(bytes)
    }

    private static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
}
