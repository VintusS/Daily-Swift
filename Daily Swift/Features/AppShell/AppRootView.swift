import SwiftUI

@MainActor
struct AppRootView: View {
    @State private var viewModel: AppRootViewModel
    @State private var learningStudioViewModel: LearningStudioViewModel
    @State private var sourceLibraryViewModel: SourceLibraryViewModel
    @State private var sourceRetrievalViewModel: SourceRetrievalViewModel
    @State private var generatedLearningViewModel: GeneratedLearningViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        viewModel: AppRootViewModel,
        learningStudioViewModel: LearningStudioViewModel,
        sourceLibraryViewModel: SourceLibraryViewModel,
        sourceRetrievalViewModel: SourceRetrievalViewModel =
            SourceRetrievalViewModel(
                retriever: InMemorySourceRetriever()
            ),
        generatedLearningViewModel: GeneratedLearningViewModel =
            GeneratedLearningViewModel(
                generator: GeneratedLearningGenerator(
                    retriever: InMemorySourceRetriever(),
                    sourceLibrary: InMemorySourceLibraryService(),
                    provider: DeterministicLanguageModelProvider(),
                    store: InMemoryGeneratedLearningStore()
                )
            )
    ) {
        _viewModel = State(initialValue: viewModel)
        _learningStudioViewModel = State(
            initialValue: learningStudioViewModel
        )
        _sourceLibraryViewModel = State(
            initialValue: sourceLibraryViewModel
        )
        _sourceRetrievalViewModel = State(
            initialValue: sourceRetrievalViewModel
        )
        _generatedLearningViewModel = State(
            initialValue: generatedLearningViewModel
        )
    }

    var body: some View {
        ZStack {
            primaryContent
            .accessibilityHidden(recoverableFailure != nil)

            if let recoverableFailure {
                RecoverableStorageFailureView(
                    failure: recoverableFailure,
                    onRetry: viewModel.retry,
                    onContinueTemporarily: viewModel.continueTemporarily,
                    onReset: viewModel.reset
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .task {
            guard viewModel.state == .launching else {
                return
            }
            viewModel.start()
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.2),
            value: viewModel.state
        )
    }

    @ViewBuilder
    private var primaryContent: some View {
        switch viewModel.state {
        case .ready:
            LearningStudioView(
                viewModel: learningStudioViewModel,
                sourceLibraryViewModel: sourceLibraryViewModel,
                sourceRetrievalViewModel: sourceRetrievalViewModel,
                generatedLearningViewModel: generatedLearningViewModel,
                onPrivacy: {
                    viewModel.navigate(to: .privacyAndData)
                }
            )
            .sheet(isPresented: privacyPresentation) {
                NavigationStack {
                    PrivacyAndDataView(
                        isLearningSessionTemporary:
                            learningStudioViewModel.sessionMode
                                == .temporary
                    )
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done", action: dismissPrivacy)
                                    .accessibilityIdentifier(
                                        "privacy-and-data.done"
                                    )
                            }
                        }
                }
            }

        case .launching,
             .restoring,
             .firstRun,
             .recoverableStorageFailure:
            NavigationStack(path: navigationPath) {
                shellContent
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
            }
        }
    }

    private var navigationPath: Binding<[AppRoute]> {
        Binding(
            get: { viewModel.router.path },
            set: { viewModel.replaceNavigationPath(with: $0) }
        )
    }

    private var privacyPresentation: Binding<Bool> {
        Binding(
            get: {
                guard case .ready = viewModel.state else {
                    return false
                }
                return viewModel.router.path.last == .privacyAndData
            },
            set: { isPresented in
                if !isPresented {
                    dismissPrivacy()
                }
            }
        )
    }

    @ViewBuilder
    private var shellContent: some View {
        switch viewModel.state {
        case .launching:
            ShellProgressView(
                title: "Opening your learning studio",
                message: "Preparing a focused, private place to learn."
            )

        case .restoring:
            ShellProgressView(
                title: "Restoring your learning space",
                message: "Returning you to the last safe place you visited."
            )

        case let .firstRun(firstRunState):
            FirstRunView(
                isSaving: firstRunState == .saving,
                onContinue: viewModel.completeFirstRun,
                onPrivacy: {
                    viewModel.navigate(to: .privacyAndData)
                }
            )

        case .ready:
            Color.clear
                .accessibilityHidden(true)

        case .recoverableStorageFailure:
            Color.clear
                .accessibilityHidden(true)
        }
    }

    private func dismissPrivacy() {
        guard viewModel.router.path.last == .privacyAndData else {
            return
        }

        var routes = viewModel.router.path
        routes.removeLast()
        viewModel.replaceNavigationPath(with: routes)
    }

    private var recoverableFailure: AppShellFailure? {
        guard case let .recoverableStorageFailure(failure) = viewModel.state else {
            return nil
        }

        return failure
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .privacyAndData:
            PrivacyAndDataView()
        }
    }
}

#Preview("First Run") {
    AppRootView(
        viewModel: AppRootViewModel(
            bootstrapService: InMemoryAppBootstrapService()
        ),
        learningStudioViewModel: LearningStudioViewModel(
            catalog: .generatedOnly,
            store: InMemoryLearningProgressStore()
        ),
        sourceLibraryViewModel: SourceLibraryViewModel(
            service: InMemorySourceLibraryService()
        )
    )
}

#Preview("Ready — Dark") {
    AppRootView(
        viewModel: AppRootViewModel(
            bootstrapService: InMemoryAppBootstrapService(
                snapshot: AppShellSnapshot(
                    hasCompletedFirstRun: true
                )
            )
        ),
        learningStudioViewModel: LearningStudioViewModel(
            catalog: .generatedOnly,
            store: InMemoryLearningProgressStore()
        ),
        sourceLibraryViewModel: SourceLibraryViewModel(
            service: SourceLibraryFixtures.service()
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Recovery — Accessibility") {
    AppRootView(
        viewModel: AppRootViewModel(
            bootstrapService: InMemoryAppBootstrapService(
                restoreOutcomes: [.failure(.restorationCorrupt)]
            )
        ),
        learningStudioViewModel: LearningStudioViewModel(
            catalog: .generatedOnly,
            store: InMemoryLearningProgressStore()
        ),
        sourceLibraryViewModel: SourceLibraryViewModel(
            service: InMemorySourceLibraryService()
        )
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}
