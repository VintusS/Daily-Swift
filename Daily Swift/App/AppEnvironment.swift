import Foundation

struct AppLaunchConfiguration: Equatable, Sendable {
    enum ShellScenario: String, Equatable, Sendable {
        case live
        case firstRun = "first-run"
        case ready
        case readySaveFailed = "ready-save-failed"
        case restoredPrivacy = "restored-privacy"
        case storeUnavailable = "store-unavailable"
        case restorationCorrupt = "restoration-corrupt"
        case unsupportedSnapshotVersion = "unsupported-snapshot-version"
        case saveFailed = "save-failed"
    }

    static let uiTestingFlag = "--ui-testing"
    static let structuredGenerationSpikeFlag =
        "--open-structured-generation-spike"
    static let shellScenarioArgument = "--app-shell-scenario"
    static let resetUITestingShellFlag =
        "--reset-ui-testing-app-shell"
    static let uiTestingSnapshotKey =
        "app-shell.ui-testing.snapshot"

    let isUITestingEnabled: Bool
    let isStructuredGenerationSpikeEnabled: Bool
    let shouldResetUITestingShell: Bool
    let shellScenario: ShellScenario

    init(processInfo: ProcessInfo = .processInfo) {
        self.init(arguments: processInfo.arguments)
    }

    init(arguments: [String]) {
        isUITestingEnabled = arguments.contains(Self.uiTestingFlag)
        isStructuredGenerationSpikeEnabled = arguments.contains(
            Self.structuredGenerationSpikeFlag
        )
        shouldResetUITestingShell = arguments.contains(
            Self.resetUITestingShellFlag
        )
        shellScenario = Self.parseShellScenario(from: arguments)
    }

    private static func parseShellScenario(
        from arguments: [String]
    ) -> ShellScenario {
        let valuePrefix = "\(shellScenarioArgument)="
        if let argument = arguments.first(where: {
            $0.hasPrefix(valuePrefix)
        }) {
            let rawValue = String(argument.dropFirst(valuePrefix.count))
            return ShellScenario(rawValue: rawValue) ?? .live
        }

        if let argumentIndex = arguments.firstIndex(
            of: shellScenarioArgument
        ) {
            let valueIndex = arguments.index(after: argumentIndex)
            if arguments.indices.contains(valueIndex) {
                return ShellScenario(rawValue: arguments[valueIndex]) ?? .live
            }
        }

        return .live
    }
}

@MainActor
struct AppEnvironment {
    let bootstrapService: any AppBootstrapServing
    let router: AppRouter
    let launchConfiguration: AppLaunchConfiguration

    init(
        bootstrapService: any AppBootstrapServing,
        router: AppRouter = AppRouter(),
        launchConfiguration: AppLaunchConfiguration = AppLaunchConfiguration(
            arguments: []
        )
    ) {
        self.bootstrapService = bootstrapService
        self.router = router
        self.launchConfiguration = launchConfiguration
    }

    static func live(
        processInfo: ProcessInfo = .processInfo,
        defaults: UserDefaults = .standard
    ) -> AppEnvironment {
        let configuration = AppLaunchConfiguration(processInfo: processInfo)

#if DEBUG
        if configuration.isUITestingEnabled {
            if configuration.shellScenario == .live {
                if configuration.shouldResetUITestingShell {
                    defaults.removeObject(
                        forKey: AppLaunchConfiguration.uiTestingSnapshotKey
                    )
                }

                return AppEnvironment(
                    bootstrapService: UserDefaultsAppBootstrapService(
                        defaults: defaults,
                        snapshotKey: AppLaunchConfiguration
                            .uiTestingSnapshotKey
                    ),
                    launchConfiguration: configuration
                )
            }

            return AppEnvironment(
                bootstrapService: service(
                    for: configuration.shellScenario
                ),
                launchConfiguration: configuration
            )
        }
#endif

        return AppEnvironment(
            bootstrapService: UserDefaultsAppBootstrapService(
                defaults: defaults
            ),
            launchConfiguration: configuration
        )
    }

    func makeRootViewModel() -> AppRootViewModel {
        AppRootViewModel(
            bootstrapService: bootstrapService,
            router: router
        )
    }

#if DEBUG
    private static func service(
        for scenario: AppLaunchConfiguration.ShellScenario
    ) -> any AppBootstrapServing {
        switch scenario {
        case .live, .firstRun:
            InMemoryAppBootstrapService()
        case .ready:
            InMemoryAppBootstrapService(
                snapshot: AppShellSnapshot(
                    hasCompletedFirstRun: true
                )
            )
        case .readySaveFailed:
            InMemoryAppBootstrapService(
                snapshot: AppShellSnapshot(
                    hasCompletedFirstRun: true
                ),
                saveOutcomes: [.failure(.saveFailed)]
            )
        case .restoredPrivacy:
            InMemoryAppBootstrapService(
                snapshot: AppShellSnapshot(
                    hasCompletedFirstRun: true,
                    routes: [.privacyAndData]
                )
            )
        case .storeUnavailable:
            InMemoryAppBootstrapService(
                restoreOutcomes: [.failure(.storeUnavailable)]
            )
        case .restorationCorrupt:
            InMemoryAppBootstrapService(
                restoreOutcomes: [.failure(.restorationCorrupt)]
            )
        case .unsupportedSnapshotVersion:
            InMemoryAppBootstrapService(
                restoreOutcomes: [
                    .failure(.unsupportedSnapshotVersion),
                ]
            )
        case .saveFailed:
            InMemoryAppBootstrapService(
                saveOutcomes: [.failure(.saveFailed)]
            )
        }
    }
#endif
}
