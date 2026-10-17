import Foundation
import XCTest

@testable import Nido

@MainActor
final class AccountDeletionSessionFenceTests: XCTestCase {
    func testPreparingAppleSignInPreservesAccountRevocationNotice() async throws {
        let fixture = try makeFixture(delaysFirstChallenge: false, unauthorizedLoad: true)
        defer { fixture.cleanup() }
        let revocationNotice = "Vuelve a iniciar sesión para acceder."

        await fixture.store.load()

        XCTAssertEqual(fixture.store.phase, .authentication)
        XCTAssertEqual(fixture.store.notice, revocationNotice)

        await fixture.store.prepareAppleSignIn()

        XCTAssertNotNil(fixture.store.appleSignInChallenge)
        XCTAssertEqual(
            fixture.store.notice,
            revocationNotice,
            "Getting a fresh Apple challenge must not erase the account-revocation message."
        )

        try await fixture.store.completeAppleSignIn(
            identityToken: Data("new-identity-token".utf8),
            appleUserID: "apple-user-new"
        )

        XCTAssertNotEqual(
            fixture.store.notice,
            revocationNotice,
            "A successful sign-in must not carry the previous account-revocation explanation into onboarding."
        )
    }

    func testRegistrationServiceInvalidationNoticeSurvivesAppleChallenge() async throws {
        let fixture = try makeFixture(delaysFirstChallenge: false)
        defer { fixture.cleanup() }

        fixture.eventHub.invalidate()
        XCTAssertEqual(fixture.store.phase, .authentication)
        XCTAssertEqual(fixture.store.notice, "Vuelve a iniciar sesión para acceder.")

        await fixture.store.prepareAppleSignIn()

        XCTAssertEqual(fixture.store.notice, "Vuelve a iniciar sesión para acceder.")
    }

    func testPreparingAppleSignInPreservesAppleCredentialRevocationReason() async throws {
        let fixture = try makeFixture(
            delaysFirstChallenge: false,
            appleUserID: "revoked-account-\(UUID().uuidString)"
        )
        defer { fixture.cleanup() }

        await fixture.store.load()

        XCTAssertEqual(fixture.store.phase, .authentication)
        XCTAssertEqual(fixture.store.notice, "Tu acceso con Apple ya no está autorizado.")

        await fixture.store.prepareAppleSignIn()

        XCTAssertEqual(
            fixture.store.notice,
            "Tu acceso con Apple ya no está autorizado.",
            "Preparing a fresh challenge must retain the reason an Apple credential was invalidated."
        )
    }

    func testSuccessfulAppleChallengeRetryClearsItsTransientError() async throws {
        let fixture = try makeFixture(delaysFirstChallenge: false, failsFirstChallenge: true)
        defer { fixture.cleanup() }
        fixture.store.phase = .authentication

        await fixture.store.prepareAppleSignIn()

        XCTAssertNotNil(fixture.store.notice)
        XCTAssertNil(fixture.store.appleSignInChallenge)

        await fixture.store.prepareAppleSignIn()

        XCTAssertNotNil(fixture.store.appleSignInChallenge)
        XCTAssertNil(fixture.store.notice, "A successful retry should clear the previous challenge error.")
    }

    func testLateDeletionSuccessCannotClearANewAppleSession() async throws {
        let fixture = try makeFixture(delaysFirstChallenge: false, delaysDeletion: true)
        defer { fixture.cleanup() }

        let deletionChallenge = try await fixture.store.prepareAccountDeletionChallenge()
        let deletion = Task {
            try await fixture.store.deleteAccount(proof: AppleAccountDeletionProof(
                challengeID: deletionChallenge.challengeID,
                identityToken: "old-account-identity-token",
                authorizationCode: "old-account-authorization-code"
            ))
        }
        await fulfillment(of: [try XCTUnwrap(fixture.controller.deletionStarted)], timeout: 5)

        await fixture.store.signOut()
        await signInNewAccount(fixture.store)
        XCTAssertEqual(fixture.credentialStore.load()?.accessToken, "new-nido-session")

        fixture.controller.releaseDeletion()
        try await deletion.value

        XCTAssertEqual(fixture.store.phase, .onboarding)
        XCTAssertEqual(
            fixture.credentialStore.load()?.accessToken,
            "new-nido-session",
            "A late DELETE response must not erase credentials from the newer Apple session."
        )
    }

    func testLateDeletionChallengeIsDiscardedAfterTheSessionChanges() async throws {
        let fixture = try makeFixture(delaysFirstChallenge: true)
        defer { fixture.cleanup() }

        let challengeRequest = Task {
            try await fixture.store.prepareAccountDeletionChallenge()
        }
        await fulfillment(of: [try XCTUnwrap(fixture.controller.firstChallengeStarted)], timeout: 5)

        await fixture.store.signOut()
        await signInNewAccount(fixture.store)
        fixture.controller.releaseFirstChallenge()

        do {
            _ = try await challengeRequest.value
            XCTFail("A challenge from the previous session must be rejected.")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidResponse)
        }
        XCTAssertEqual(fixture.credentialStore.load()?.accessToken, "new-nido-session")
    }

    func testLateLogoutCannotClearANewAppleSession() async throws {
        let fixture = try makeFixture(delaysFirstChallenge: false, delaysLogout: true)
        defer { fixture.cleanup() }

        let logout = Task { await fixture.store.signOut() }
        await fulfillment(of: [try XCTUnwrap(fixture.controller.logoutStarted)], timeout: 5)
        await signInNewAccount(fixture.store)
        XCTAssertEqual(fixture.credentialStore.load()?.accessToken, "new-nido-session")

        fixture.controller.releaseLogout()
        await logout.value

        XCTAssertEqual(
            fixture.credentialStore.load()?.accessToken,
            "new-nido-session",
            "A late logout response must not erase credentials from a newer Apple session."
        )
    }

    private func signInNewAccount(_ store: NidoStore) async {
        await store.prepareAppleSignIn()
        do {
            try await store.completeAppleSignIn(
                identityToken: Data("new-identity-token".utf8),
                appleUserID: "apple-user-new"
            )
        } catch {
            XCTFail("The fixture sign-in should succeed: \(error)")
        }
    }

    private func makeFixture(
        delaysFirstChallenge: Bool,
        failsFirstChallenge: Bool = false,
        unauthorizedLoad: Bool = false,
        delaysDeletion: Bool = false,
        delaysLogout: Bool = false,
        appleUserID: String? = nil
    ) throws -> Fixture {
        let identifier = UUID().uuidString
        let suiteName = "nido.account-deletion-session.\(identifier)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory.appending(path: identifier)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let credentialStore = CredentialStore(service: suiteName)
        let oldCredential = SessionCredential(accessToken: "old-nido-session", expiresAt: .distantFuture, appleUserID: appleUserID)
        if appleUserID != nil { try credentialStore.save(oldCredential) }
        let controller = AccountDeletionSessionURLProtocol.Controller(
            delaysFirstChallenge: delaysFirstChallenge,
            failsFirstChallenge: failsFirstChallenge,
            unauthorizedLoad: unauthorizedLoad,
            firstChallengeStarted: delaysFirstChallenge ? expectation(description: "First challenge request starts") : nil,
            deletionStarted: delaysDeletion ? expectation(description: "Delete request starts") : nil,
            logoutStarted: delaysLogout ? expectation(description: "Logout request starts") : nil
        )
        AccountDeletionSessionURLProtocol.install(controller)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AccountDeletionSessionURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let api = NidoAPI(baseURL: try XCTUnwrap(URL(string: "https://account-deletion.test")), session: session)
        let eventHub = RegistrationMutationEventHub()
        let registrationService = NidoRegistrationServices.make(
            api: api,
            cache: LocalCache(fileURL: directory.appending(path: "cache.json")),
            credentialStore: credentialStore,
            stateDefaults: defaults,
            legacyDefaults: defaults,
            stateStore: RegistrationStateFileStore(fileURL: directory.appending(path: "state.json")),
            eventHub: eventHub,
            credentialOverride: oldCredential,
            loadSleep: { _ in nil }
        )
        let store = NidoStore(
            api: api,
            credentialStore: credentialStore,
            defaults: defaults,
            shouldLoadCredential: appleUserID != nil,
            initialAccessToken: appleUserID == nil ? oldCredential.accessToken : nil,
            registrationService: registrationService,
            registrationEventHub: eventHub
        )

        return Fixture(
            store: store,
            credentialStore: credentialStore,
            defaults: defaults,
            suiteName: suiteName,
            directory: directory,
            session: session,
            controller: controller,
            eventHub: eventHub
        )
    }

    private struct Fixture {
        let store: NidoStore
        let credentialStore: CredentialStore
        let defaults: UserDefaults
        let suiteName: String
        let directory: URL
        let session: URLSession
        let controller: AccountDeletionSessionURLProtocol.Controller
        let eventHub: RegistrationMutationEventHub

        func cleanup() {
            AccountDeletionSessionURLProtocol.install(nil)
            session.invalidateAndCancel()
            defaults.removePersistentDomain(forName: suiteName)
            credentialStore.delete()
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

private final class AccountDeletionSessionURLProtocol: URLProtocol, @unchecked Sendable {
    final class Controller: @unchecked Sendable {
        let firstChallengeStarted: XCTestExpectation?
        let deletionStarted: XCTestExpectation?
        let logoutStarted: XCTestExpectation?
        private let lock = NSLock()
        private var challengeCount = 0
        private let delaysFirstChallenge: Bool
        private let failsFirstChallenge: Bool
        private let unauthorizedLoad: Bool
        private var pendingChallenge: AccountDeletionSessionURLProtocol?
        private var pendingDeletion: AccountDeletionSessionURLProtocol?
        private var pendingLogout: AccountDeletionSessionURLProtocol?

        init(
            delaysFirstChallenge: Bool,
            failsFirstChallenge: Bool,
            unauthorizedLoad: Bool,
            firstChallengeStarted: XCTestExpectation?,
            deletionStarted: XCTestExpectation?,
            logoutStarted: XCTestExpectation?
        ) {
            self.delaysFirstChallenge = delaysFirstChallenge
            self.failsFirstChallenge = failsFirstChallenge
            self.unauthorizedLoad = unauthorizedLoad
            self.firstChallengeStarted = firstChallengeStarted
            self.deletionStarted = deletionStarted
            self.logoutStarted = logoutStarted
        }

        func receive(_ protocolRequest: AccountDeletionSessionURLProtocol) {
            switch (protocolRequest.request.httpMethod, protocolRequest.request.url?.path) {
            case ("GET", "/api/nido") where unauthorizedLoad:
                protocolRequest.respond(status: 401, body: #"{"error":"The session is expired or revoked"}"#)
            case ("POST", "/api/nido/auth/apple/challenge"):
                lock.lock()
                challengeCount += 1
                let count = challengeCount
                if count == 1, delaysFirstChallenge { pendingChallenge = protocolRequest }
                lock.unlock()
                if count == 1, failsFirstChallenge {
                    protocolRequest.respond(status: 503, body: #"{"error":"Temporary Apple sign-in service failure"}"#)
                    return
                }
                if count == 1 {
                    firstChallengeStarted?.fulfill()
                    if delaysFirstChallenge { return }
                }
                let identifier = count == 1 ? "old-deletion-challenge" : "new-login-challenge"
                protocolRequest.respond(status: 201, body: #"{"challengeID":"\#(identifier)","nonce":"raw-nonce","expiresAt":"2030-01-01T00:00:00Z"}"#)
            case ("DELETE", "/api/nido/auth/account"):
                lock.lock()
                pendingDeletion = protocolRequest
                lock.unlock()
                deletionStarted?.fulfill()
            case ("POST", "/api/nido/auth/logout"):
                if let logoutStarted {
                    lock.lock()
                    pendingLogout = protocolRequest
                    lock.unlock()
                    logoutStarted.fulfill()
                } else {
                    protocolRequest.respond(status: 200, body: #"{"loggedOut":true}"#)
                }
            case ("POST", "/api/nido/auth/apple/session"):
                protocolRequest.respond(status: 201, body: #"{"token":"new-nido-session","expiresAt":"2030-02-01T00:00:00Z","membership":null}"#)
            default:
                protocolRequest.respond(status: 404, body: #"{"error":"Unexpected fixture route"}"#)
            }
        }

        func releaseFirstChallenge() {
            let request = lock.withLock { let value = pendingChallenge; pendingChallenge = nil; return value }
            request?.respond(status: 201, body: #"{"challengeID":"old-deletion-challenge","nonce":"raw-nonce","expiresAt":"2030-01-01T00:00:00Z"}"#)
        }

        func releaseDeletion() {
            let request = lock.withLock { let value = pendingDeletion; pendingDeletion = nil; return value }
            request?.respond(status: 200, body: #"{"deleted":true}"#)
        }

        func releaseLogout() {
            let request = lock.withLock { let value = pendingLogout; pendingLogout = nil; return value }
            request?.respond(status: 200, body: #"{"loggedOut":true}"#)
        }
    }

    nonisolated(unsafe) private static var controller: Controller?

    static func install(_ controller: Controller?) { self.controller = controller }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let controller = Self.controller else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        controller.receive(self)
    }

    override func stopLoading() {}

    func respond(status: Int, body: String) {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                             headerFields: ["Content-Type": "application/json"]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
