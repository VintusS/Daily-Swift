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

    enum LearningScenario: String, Equatable, Sendable {
        case live
        case empty
        case seeded
        case restoreRetry = "restore-retry"
        case writeRetry = "write-retry"
    }

    enum SourceScenario: String, Equatable, Sendable {
        case live
        case empty
        case seeded
        case restoreRetry = "restore-retry"
    }

    static let uiTestingFlag = "--ui-testing"
    static let structuredGenerationSpikeFlag =
        "--open-structured-generation-spike"
    static let shellScenarioArgument = "--app-shell-scenario"
    static let resetUITestingShellFlag =
        "--reset-ui-testing-app-shell"
    static let learningScenarioArgument =
        "--learning-studio-scenario"
    static let resetUITestingLearningFlag =
        "--reset-ui-testing-learning-progress"
    static let sourceScenarioArgument =
        "--source-library-scenario"
    static let uiTestingSnapshotKey =
        "app-shell.ui-testing.snapshot"

    let isUITestingEnabled: Bool
    let isStructuredGenerationSpikeEnabled: Bool
    let shouldResetUITestingShell: Bool
    let shouldResetUITestingLearning: Bool
    let shellScenario: ShellScenario
    let learningScenario: LearningScenario
    let sourceScenario: SourceScenario

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
        shouldResetUITestingLearning = arguments.contains(
            Self.resetUITestingLearningFlag
        )
        shellScenario = Self.parseShellScenario(from: arguments)
        learningScenario = Self.parseLearningScenario(from: arguments)
            ?? (isUITestingEnabled ? .empty : .live)
        sourceScenario = Self.parseSourceScenario(from: arguments)
            ?? (isUITestingEnabled ? .empty : .live)
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

    private static func parseLearningScenario(
        from arguments: [String]
    ) -> LearningScenario? {
        let valuePrefix = "\(learningScenarioArgument)="
        if let argument = arguments.first(where: {
            $0.hasPrefix(valuePrefix)
        }) {
            let rawValue = String(argument.dropFirst(valuePrefix.count))
            return LearningScenario(rawValue: rawValue)
        }

        if let argumentIndex = arguments.firstIndex(
            of: learningScenarioArgument
        ) {
            let valueIndex = arguments.index(after: argumentIndex)
            if arguments.indices.contains(valueIndex) {
                return LearningScenario(rawValue: arguments[valueIndex])
            }
        }

        return nil
    }

    private static func parseSourceScenario(
        from arguments: [String]
    ) -> SourceScenario? {
        let valuePrefix = "\(sourceScenarioArgument)="
        if let argument = arguments.first(where: {
            $0.hasPrefix(valuePrefix)
        }) {
            let rawValue = String(argument.dropFirst(valuePrefix.count))
            return SourceScenario(rawValue: rawValue)
        }

        if let argumentIndex = arguments.firstIndex(
            of: sourceScenarioArgument
        ) {
            let valueIndex = arguments.index(after: argumentIndex)
            if arguments.indices.contains(valueIndex) {
                return SourceScenario(rawValue: arguments[valueIndex])
            }
        }

        return nil
    }
}

@MainActor
struct AppEnvironment {
    let bootstrapService: any AppBootstrapServing
    let router: AppRouter
    let learningProgressStore: any LearningProgressStoring
    let learningRouter: LearningStudioRouter
    let learningCatalog: LearningCatalog
    let sourceLibraryService: any SourceLibraryServing
    let launchConfiguration: AppLaunchConfiguration

    init(
        bootstrapService: any AppBootstrapServing,
        router: AppRouter = AppRouter(),
        learningProgressStore: any LearningProgressStoring =
            InMemoryLearningProgressStore(),
        learningRouter: LearningStudioRouter = LearningStudioRouter(),
        learningCatalog: LearningCatalog = SeedCurriculumProvider.catalog,
        sourceLibraryService: any SourceLibraryServing =
            InMemorySourceLibraryService(),
        launchConfiguration: AppLaunchConfiguration = AppLaunchConfiguration(
            arguments: []
        )
    ) {
        self.bootstrapService = bootstrapService
        self.router = router
        self.learningProgressStore = learningProgressStore
        self.learningRouter = learningRouter
        self.learningCatalog = learningCatalog
        self.sourceLibraryService = sourceLibraryService
        self.launchConfiguration = launchConfiguration
    }

    static func live(
        processInfo: ProcessInfo = .processInfo,
        defaults: UserDefaults = .standard
    ) -> AppEnvironment {
        let configuration = AppLaunchConfiguration(processInfo: processInfo)
        let learningProgressStore = Self.learningProgressStore(
            for: configuration
        )
        let sourceLibraryService = Self.sourceLibraryService(
            for: configuration
        )

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
                    learningProgressStore: learningProgressStore,
                    sourceLibraryService: sourceLibraryService,
                    launchConfiguration: configuration
                )
            }

            return AppEnvironment(
                bootstrapService: service(
                    for: configuration.shellScenario
                ),
                learningProgressStore: learningProgressStore,
                sourceLibraryService: sourceLibraryService,
                launchConfiguration: configuration
            )
        }
#endif

        return AppEnvironment(
            bootstrapService: UserDefaultsAppBootstrapService(
                defaults: defaults
            ),
            learningProgressStore: learningProgressStore,
            sourceLibraryService: sourceLibraryService,
            launchConfiguration: configuration
        )
    }

    func makeRootViewModel() -> AppRootViewModel {
        AppRootViewModel(
            bootstrapService: bootstrapService,
            router: router
        )
    }

    func makeLearningStudioViewModel() -> LearningStudioViewModel {
        LearningStudioViewModel(
            catalog: learningCatalog,
            store: learningProgressStore,
            router: learningRouter
        )
    }

    func makeSourceLibraryViewModel() -> SourceLibraryViewModel {
        SourceLibraryViewModel(service: sourceLibraryService)
    }

    private static func learningProgressStore(
        for configuration: AppLaunchConfiguration
    ) -> any LearningProgressStoring {
#if DEBUG
        if configuration.isUITestingEnabled {
            switch configuration.learningScenario {
            case .live:
                return ResetBeforeRestoreLearningProgressStore(
                    base: LearningProgressStoreFactory.live(),
                    shouldResetBeforeRestore:
                        configuration.shouldResetUITestingLearning
                )
            case .empty:
                return InMemoryLearningProgressStore()
            case .seeded:
                return seededLearningProgressStore()
            case .restoreRetry:
                return InMemoryLearningProgressStore(
                    restoreOutcomes: [
                        .failure(.readFailed),
                        .success(()),
                    ]
                )
            case .writeRetry:
                return InMemoryLearningProgressStore(
                    writeOutcomes: [
                        .success(()),
                        .failure(.writeFailed),
                        .success(()),
                    ]
                )
            }
        }
#endif

        return LearningProgressStoreFactory.live()
    }

    private static func sourceLibraryService(
        for configuration: AppLaunchConfiguration
    ) -> any SourceLibraryServing {
#if DEBUG
        if configuration.isUITestingEnabled {
            switch configuration.sourceScenario {
            case .live, .empty:
                return InMemorySourceLibraryService()
            case .seeded:
                return SourceLibraryFixtures.service()
            case .restoreRetry:
                return InMemorySourceLibraryService(
                    restoreOutcomes: [
                        .failure(.readFailed),
                        .success(()),
                    ]
                )
            }
        }
#endif

        return SourceLibraryStoreFactory.live()
    }

#if DEBUG
    private static func seededLearningProgressStore()
        -> any LearningProgressStoring {
        let catalog = SeedCurriculumProvider.catalog
        let article = catalog.articles[0]
        let challenge = catalog.challenges[0]
        let now = Date(timeIntervalSince1970: 1_785_200_000)

        return InMemoryLearningProgressStore(
            snapshot: LearningProgressSnapshot(
                attempts: [
                    ChallengeAttempt(
                        challengeID: challenge.id,
                        selectedChoiceID: challenge.correctChoiceID,
                        isCorrect: true,
                        attemptedAt: now
                    ),
                ],
                articleActivities: [
                    ArticleActivity(
                        articleID: article.id,
                        isBookmarked: true,
                        lastOpenedAt: now,
                        completedAt: now
                    ),
                ],
                preferences: LearningPreferences(
                    selectedTabIdentifier:
                        LearningStudioTab.progress.rawValue
                )
            )
        )
    }

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
