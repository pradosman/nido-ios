import CryptoKit
import Foundation

nonisolated struct SessionCredential: Codable, Equatable, Sendable {
    let accessToken: String
    let expiresAt: Date
    let appleUserID: String?

    func isExpired(at date: Date = .now) -> Bool {
        expiresAt <= date
    }
}

nonisolated struct AppleSignInChallenge: Decodable, Equatable, Sendable {
    let challengeID: String
    let nonce: String
    let expiresAt: Date

    static func requestNonce(for rawNonce: String) -> String {
        SHA256.hash(data: Data(rawNonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated struct AppleSession: Sendable {
    let credential: SessionCredential
    let hasMembership: Bool
}
