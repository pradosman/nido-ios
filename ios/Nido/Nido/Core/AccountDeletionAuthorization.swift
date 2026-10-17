import Foundation

nonisolated struct AppleAccountDeletionProof: Equatable, Sendable {
    let challengeID: String
    let identityToken: String
    let authorizationCode: String
}
