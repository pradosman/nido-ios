import Foundation
import Testing
@testable import NidoCore

@Suite
struct AuthenticationTests {
    @Test
    func sessionCredentialRoundTripsAndExpiresAtItsAbsoluteDeadline() throws {
        let expiry = Date(timeIntervalSince1970: 2_000)
        let credential = SessionCredential(
            accessToken: "private-token",
            expiresAt: expiry,
            appleUserID: "apple-user"
        )

        let decoded = try JSONDecoder().decode(
            SessionCredential.self,
            from: JSONEncoder().encode(credential)
        )

        #expect(decoded == credential)
        #expect(!decoded.isExpired(at: expiry.addingTimeInterval(-0.001)))
        #expect(decoded.isExpired(at: expiry))
    }

    @Test
    func appleRequestNonceIsTheLowercaseSHA256OfTheRawChallengeNonce() {
        #expect(
            AppleSignInChallenge.requestNonce(for: "raw-nonce")
                == "2c5d107938053a2275f022c153c9a71f65ee07754b8bca543ee97a0c3cc66990"
        )
    }
}
