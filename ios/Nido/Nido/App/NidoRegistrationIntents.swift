import AppIntents
import Foundation

@MainActor
enum NidoRegistrationServices {
    static let eventHub = RegistrationMutationEventHub()
    static let shared = make(eventHub: eventHub)

    static func make(
        api: NidoAPI = NidoAPI(baseURL: AppConfiguration.apiBaseURL),
        cache: LocalCache = LocalCache(),
        credentialStore: CredentialStore = CredentialStore(),
        stateDefaults: UserDefaults? = UserDefaults(suiteName: NidoWidgetBridge.appGroupIdentifier),
        legacyDefaults: UserDefaults = .standard,
        stateStore: RegistrationStateFileStore? = nil,
        eventHub: RegistrationMutationEventHub,
        credentialOverride: SessionCredential? = nil,
        now: @escaping @Sendable () -> Date = { .now },
        createEntry: (@Sendable (Entry, String) async throws -> Entry)? = nil
    ) -> RegistrationMutationService {
        let durableDefaults = stateDefaults ?? UserDefaults()
        let resolvedStateStore = stateStore ?? productionStateStore()
        return RegistrationMutationService(
            cache: cache,
            stateStore: resolvedStateStore,
            legacyDefaults: RegistrationStateDefaults(durable: durableDefaults, legacy: legacyDefaults),
            dependencies: RegistrationMutationDependencies(
                loadCredential: { credentialOverride ?? credentialStore.load() },
                deleteCredential: { credentialStore.delete() },
                createEntry: createEntry ?? { entry, token in
                    try await api.create(entry: entry, accessToken: token)
                },
                publishLocalCommit: { commit in
                    await eventHub.publish(commit)
                },
                clearExternalState: {
                    await eventHub.invalidate()
                    await MainActor.run {
                        NidoWidgetBridge.update(
                            profile: nil,
                            entries: [],
                            activeSleepStartedAt: nil,
                            activeFeedStartedAt: nil
                        )
                    }
                    await NidoLiveActivity.endAll()
                },
                now: now,
                makeID: { UUID().uuidString }
            )
        )
    }

    private static func productionStateStore() -> RegistrationStateFileStore {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: NidoWidgetBridge.appGroupIdentifier
        ) else {
            return RegistrationStateFileStore(
                load: { throw CocoaError(.fileNoSuchFile) },
                save: { _ in throw CocoaError(.fileWriteNoPermission) },
                remove: {}
            )
        }
        return RegistrationStateFileStore(
            fileURL: container.appending(path: "registration-state.json")
        )
    }
}

struct RegisterDiaperIntent: AppIntent {
    static let title: LocalizedStringResource = "Registrar pañal"
    static let description = IntentDescription("Registra un pañal con los últimos detalles reutilizables.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    static let openAppWhenRun = false

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async -> some IntentResult & ProvidesDialog {
        let service = await MainActor.run { NidoRegistrationServices.shared }
        let result = await service.registerDiaper(caregiverID: nil, caregiverName: nil)
        await RegistrationIntentReconciler.reconcile(result)
        return .result(dialog: IntentDialog(stringLiteral: result.dialog))
    }
}

struct RepeatFeedIntent: AppIntent {
    static let title: LocalizedStringResource = "Repetir última toma"
    static let description = IntentDescription("Registra una toma reutilizando únicamente los últimos detalles compatibles.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    static let openAppWhenRun = false

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async -> some IntentResult & ProvidesDialog {
        let service = await MainActor.run { NidoRegistrationServices.shared }
        let result = await service.registerFeed(caregiverID: nil, caregiverName: nil)
        await RegistrationIntentReconciler.reconcile(result)
        return .result(dialog: IntentDialog(stringLiteral: result.dialog))
    }
}

struct StartSleepIntent: AppIntent {
    static let title: LocalizedStringResource = "Iniciar sueño"
    static let description = IntentDescription("Inicia un sueño ahora.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    static let openAppWhenRun = false

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async -> some IntentResult & ProvidesDialog {
        let service = await MainActor.run { NidoRegistrationServices.shared }
        let result = await service.startSleep()
        await RegistrationIntentReconciler.reconcile(result)
        return .result(dialog: IntentDialog(stringLiteral: result.dialog))
    }
}

struct FinishSleepIntent: AppIntent {
    static let title: LocalizedStringResource = "Terminar sueño"
    static let description = IntentDescription("Termina el sueño activo y guarda el registro.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    static let openAppWhenRun = false

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async -> some IntentResult & ProvidesDialog {
        let service = await MainActor.run { NidoRegistrationServices.shared }
        let result = await service.finishSleep(caregiverID: nil, caregiverName: nil)
        await RegistrationIntentReconciler.reconcile(result)
        return .result(dialog: IntentDialog(stringLiteral: result.dialog))
    }
}

struct NidoRegistrationShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RegisterDiaperIntent(),
            phrases: ["Registra un pañal con \(.applicationName)"],
            shortTitle: "Registrar pañal",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: RepeatFeedIntent(),
            phrases: [
                "Repite la última toma con \(.applicationName)",
                "Registra una toma con \(.applicationName)",
            ],
            shortTitle: "Repetir toma",
            systemImageName: "waterbottle.fill"
        )
        AppShortcut(
            intent: StartSleepIntent(),
            phrases: ["Inicia el sueño con \(.applicationName)"],
            shortTitle: "Iniciar sueño",
            systemImageName: "moon.fill"
        )
        AppShortcut(
            intent: FinishSleepIntent(),
            phrases: ["Termina el sueño con \(.applicationName)"],
            shortTitle: "Terminar sueño",
            systemImageName: "moon.zzz.fill"
        )
    }
}

private enum RegistrationIntentReconciler {
    @MainActor
    static func reconcile(_ result: RegistrationMutationResult) async {
        NidoWidgetBridge.update(
            profile: result.snapshot.profile,
            entries: result.snapshot.entries,
            activeSleepStartedAt: result.activeSleepStartedAt,
            activeFeedStartedAt: nil
        )
        switch result.outcome {
        case .sleepStarted:
            if let start = result.activeSleepStartedAt, let profile = result.snapshot.profile {
                _ = NidoLiveActivity.start(kind: "sleep", babyName: profile.babyName, startedAt: start)
            }
        case .sleepFinished, .queued, .noActiveSleep, .authenticationRequired:
            if result.category == .sleep || result.outcome == .authenticationRequired {
                await NidoLiveActivity.end(kind: "sleep")
            }
        case .registered, .noReusableFeed, .sleepAlreadyActive, .storageUnavailable:
            break
        }
    }
}
