import Foundation
import Observation

@MainActor
@Observable
final class NidoDemoSessionCoordinator {
    private(set) var store: NidoStore?
    private(set) var defaults: UserDefaults?
    private(set) var isTransitioning = false

    private var repository: NidoDemoRepository?
    private var credentialStore: CredentialStore?
    private var stateDirectory: URL?
    private var defaultsSuiteName: String?

    var isActive: Bool { store != nil }

    func enter() async {
        guard !isActive, !isTransitioning else { return }
        isTransitioning = true
        defer { isTransitioning = false }
        await installFreshSession()
    }

    func reset() async {
        guard isActive, !isTransitioning else { return }
        isTransitioning = true
        defer { isTransitioning = false }
        await installFreshSession()
    }

    func exit() {
        guard isActive, !isTransitioning else { return }
        discardSession()
    }

    private func installFreshSession() async {
        let previousDefaults = defaults
        let previousSuiteName = defaultsSuiteName
        let previousCredentialStore = credentialStore
        let previousDirectory = stateDirectory
        let runID = UUID().uuidString.lowercased()
        let suiteName = "com.momentumia.nido.demo.\(runID)"
        guard let demoDefaults = UserDefaults(suiteName: suiteName) else { return }
        demoDefaults.removePersistentDomain(forName: suiteName)

        let directory = FileManager.default.temporaryDirectory
            .appending(path: "NidoDemo", directoryHint: .isDirectory)
            .appending(path: runID, directoryHint: .isDirectory)
        let cacheURL = directory.appending(path: "snapshot.json")
        let stateStoreURL = directory.appending(path: "registration-state.json")
        let cache = LocalCache(fileURL: cacheURL)
        let babyCareCache = BabyCareCache(fileURL: directory.appending(path: "baby-care.json"))
        let isolatedCredentialStore = CredentialStore(service: "com.momentumia.nido.demo.\(runID)")
        let eventHub = RegistrationMutationEventHub()
        let demoRepository = NidoDemoRepository()
        await demoRepository.reset()
        let api = NidoDemoRepository.makeAPI(repository: demoRepository)
        let credential = SessionCredential(
            accessToken: NidoDemoRepository.demoAccessToken,
            expiresAt: .distantFuture,
            appleUserID: nil
        )
        let registrationService = NidoRegistrationServices.make(
            api: api,
            cache: cache,
            credentialStore: isolatedCredentialStore,
            stateDefaults: demoDefaults,
            legacyDefaults: demoDefaults,
            stateStore: RegistrationStateFileStore(fileURL: stateStoreURL),
            eventHub: eventHub,
            credentialOverride: credential,
            allowsExternalEffects: false
        )
        let demoStore = NidoStore(
            api: api,
            babyCareCache: babyCareCache,
            credentialStore: isolatedCredentialStore,
            defaults: demoDefaults,
            shouldLoadCredential: false,
            initialAccessToken: NidoDemoRepository.demoAccessToken,
            registrationService: registrationService,
            registrationEventHub: eventHub,
            allowsExternalEffects: false
        )

        repository = demoRepository
        credentialStore = isolatedCredentialStore
        stateDirectory = directory
        defaultsSuiteName = suiteName
        defaults = demoDefaults
        store = demoStore
        await demoStore.load()
        cleanup(
            defaults: previousDefaults,
            suiteName: previousSuiteName,
            credentialStore: previousCredentialStore,
            directory: previousDirectory
        )
    }

    private func discardSession() {
        store = nil
        repository = nil
        cleanup(
            defaults: defaults,
            suiteName: defaultsSuiteName,
            credentialStore: credentialStore,
            directory: stateDirectory
        )
        credentialStore = nil
        defaults = nil
        stateDirectory = nil
        defaultsSuiteName = nil
    }

    private func cleanup(
        defaults: UserDefaults?,
        suiteName: String?,
        credentialStore: CredentialStore?,
        directory: URL?
    ) {
        credentialStore?.delete()
        if let suiteName { defaults?.removePersistentDomain(forName: suiteName) }
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }
}
