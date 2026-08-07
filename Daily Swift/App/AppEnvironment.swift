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
        case seededPDF = "seeded-pdf"
        case restoreRetry = "restore-retry"
    }

    enum GeneratedLearningScenario: String, Equatable, Sendable {
        case valid
        case unavailable
        case rejected
        case delayed
        case finalizing
        case providerFailure = "provider-failure"
        case storageRetry = "storage-retry"
        case persistent
        case seededHistory = "seeded-history"
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
    static let generatedLearningScenarioArgument =
        "--generated-learning-scenario"
    static let resetUITestingGeneratedLearningFlag =
        "--reset-ui-testing-generated-learning"
    static let uiTestingSnapshotKey =
        "app-shell.ui-testing.snapshot"

    let isUITestingEnabled: Bool
    let isStructuredGenerationSpikeEnabled: Bool
    let shouldResetUITestingShell: Bool
    let shouldResetUITestingLearning: Bool
    let shellScenario: ShellScenario
    let learningScenario: LearningScenario
    let sourceScenario: SourceScenario
    let generatedLearningScenario: GeneratedLearningScenario
    let shouldResetUITestingGeneratedLearning: Bool

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
        shouldResetUITestingGeneratedLearning = arguments.contains(
            Self.resetUITestingGeneratedLearningFlag
        )
        shellScenario = Self.parseShellScenario(from: arguments)
        learningScenario = Self.parseLearningScenario(from: arguments)
            ?? (isUITestingEnabled ? .empty : .live)
        sourceScenario = Self.parseSourceScenario(from: arguments)
            ?? (isUITestingEnabled ? .empty : .live)
        generatedLearningScenario = Self.parseGeneratedLearningScenario(
            from: arguments
        ) ?? .valid
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

    private static func parseGeneratedLearningScenario(
        from arguments: [String]
    ) -> GeneratedLearningScenario? {
        let valuePrefix = "\(generatedLearningScenarioArgument)="
        if let argument = arguments.first(where: {
            $0.hasPrefix(valuePrefix)
        }) {
            let rawValue = String(argument.dropFirst(valuePrefix.count))
            return GeneratedLearningScenario(rawValue: rawValue)
        }

        if let argumentIndex = arguments.firstIndex(
            of: generatedLearningScenarioArgument
        ) {
            let valueIndex = arguments.index(after: argumentIndex)
            if arguments.indices.contains(valueIndex) {
                return GeneratedLearningScenario(
                    rawValue: arguments[valueIndex]
                )
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
    let sourceRetriever: any SourceRetrieving
    let generatedLearningGenerator: any GeneratedLearningGenerating
    let launchConfiguration: AppLaunchConfiguration

    init(
        bootstrapService: any AppBootstrapServing,
        router: AppRouter = AppRouter(),
        learningProgressStore: any LearningProgressStoring =
            InMemoryLearningProgressStore(),
        learningRouter: LearningStudioRouter = LearningStudioRouter(),
        learningCatalog: LearningCatalog = .generatedOnly,
        sourceLibraryService: any SourceLibraryServing =
            InMemorySourceLibraryService(),
        sourceRetriever: (any SourceRetrieving)? = nil,
        generatedLearningGenerator: (any GeneratedLearningGenerating)? = nil,
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
        let resolvedSourceRetriever = sourceRetriever
            ?? DirectScanSourceRetriever(
                sourceLibrary: sourceLibraryService
            )
        self.sourceRetriever = resolvedSourceRetriever
        if let generatedLearningGenerator {
            self.generatedLearningGenerator = generatedLearningGenerator
        } else {
            let provider: any LanguageModelProvider
            let store: any GeneratedLearningStoring
#if DEBUG
            if launchConfiguration.isUITestingEnabled {
                switch launchConfiguration.generatedLearningScenario {
                case .valid:
                    provider = DeterministicLanguageModelProvider()
                    store = InMemoryGeneratedLearningStore()
                case .unavailable:
                    provider = DeterministicLanguageModelProvider(
                        availability: .unavailable(.modelNotReady)
                    )
                    store = InMemoryGeneratedLearningStore()
                case .rejected:
                    provider = DeterministicLanguageModelProvider(
                        mode: .uncited
                    )
                    store = InMemoryGeneratedLearningStore()
                case .delayed:
                    provider =
                        DeterministicCancellationDrainLanguageModelProvider()
                    store = InMemoryGeneratedLearningStore()
                case .finalizing:
                    provider = DeterministicLanguageModelProvider()
                    store = DelayedSaveGeneratedLearningStore(
                        base: InMemoryGeneratedLearningStore(),
                        delay: .seconds(4)
                    )
                case .providerFailure:
                    provider = DeterministicLanguageModelProvider(
                        mode: .failure(.requestFailed)
                    )
                    store = InMemoryGeneratedLearningStore()
                case .storageRetry:
                    provider = DeterministicLanguageModelProvider()
                    store = InMemoryGeneratedLearningStore(
                        restoreOutcomes: [
                            .failure(.readFailed),
                            .success(()),
                        ]
                    )
                case .persistent:
                    provider = DeterministicLanguageModelProvider()
                    store = GeneratedLearningStoreFactory.uiTesting(
                        reset:
                            launchConfiguration
                                .shouldResetUITestingGeneratedLearning
                    )
                case .seededHistory:
                    provider = DeterministicLanguageModelProvider()
                    store = InMemoryGeneratedLearningStore(
                        artifacts: [GeneratedLearningDebugFixtures.artifact]
                    )
                }
            } else {
                provider = AppleFoundationModelProvider()
                store = GeneratedLearningStoreFactory.live()
            }
#else
            provider = AppleFoundationModelProvider()
            store = GeneratedLearningStoreFactory.live()
#endif
            self.generatedLearningGenerator = GeneratedLearningGenerator(
                retriever: resolvedSourceRetriever,
                sourceLibrary: sourceLibraryService,
                provider: provider,
                store: store
            )
        }
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
        SourceLibraryViewModel(
            service: sourceLibraryService,
            sourceDeleter: CascadingLearningSourceDeleter(
                sourceLibrary: sourceLibraryService,
                generatedLearning: generatedLearningGenerator
            )
        )
    }

    func makeSourceRetrievalViewModel() -> SourceRetrievalViewModel {
        SourceRetrievalViewModel(retriever: sourceRetriever)
    }

    func makeGeneratedLearningViewModel() -> GeneratedLearningViewModel {
        GeneratedLearningViewModel(generator: generatedLearningGenerator)
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
                return generatedLearningProgressStore()
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
            case .seededPDF:
                return SourceLibraryFixtures.pdfService()
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
    private static func generatedLearningProgressStore()
        -> any LearningProgressStoring {
        let artifact = GeneratedLearningDebugFixtures.artifact
        let now = Date(timeIntervalSince1970: 1_785_200_000)

        return InMemoryLearningProgressStore(
            snapshot: LearningProgressSnapshot(
                attempts: [
                    ChallengeAttempt(
                        challengeID: artifact.quizID,
                        selectedChoiceID:
                            artifact.quiz.answerKeyChoiceID,
                        isCorrect: false,
                        attemptedAt: now
                    ),
                ],
                articleActivities: [
                    ArticleActivity(
                        articleID: artifact.articleID,
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
