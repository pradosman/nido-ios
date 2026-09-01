import Testing
@testable import NidoCore

@Suite
struct AuthenticationFailurePolicyTests {
    @Test(arguments: PendingMutationKind.allCases)
    func missingLocalCredentialQueuesOptimisticMutation(kind: PendingMutationKind) {
        #expect(
            SessionFailurePolicy.disposition(for: APIError.missingCredential, during: kind)
                == .queueOffline
        )
    }

    @Test(arguments: PendingMutationKind.allCases)
    func genuineHTTP401InvalidatesSessionAndPrivateData(kind: PendingMutationKind) {
        #expect(
            SessionFailurePolicy.disposition(
                for: APIError.server(status: 401, message: "The session is expired or revoked"),
                during: kind
            ) == .invalidateSession
        )
    }

    @Test(arguments: PendingMutationKind.allCases)
    func nonAuthenticationFailuresKeepOptimisticMutationQueued(kind: PendingMutationKind) {
        #expect(
            SessionFailurePolicy.disposition(
                for: APIError.server(status: 503, message: "Unavailable"),
                during: kind
            ) == .queueOffline
        )
    }
}
