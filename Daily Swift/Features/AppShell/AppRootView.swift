import SwiftUI

@MainActor
struct AppRootView: View {
    @State private var viewModel: AppRootViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: AppRootViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            NavigationStack(path: navigationPath) {
                rootContent
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
            }
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

    private var navigationPath: Binding<[AppRoute]> {
        Binding(
            get: { viewModel.router.path },
            set: { viewModel.replaceNavigationPath(with: $0) }
        )
    }

    @ViewBuilder
    private var rootContent: some View {
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

        case let .ready(sessionMode):
            ReadyStudioView(
                sessionMode: sessionMode,
                onPrivacy: {
                    viewModel.navigate(to: .privacyAndData)
                }
            )

        case .recoverableStorageFailure:
            Color.clear
                .accessibilityHidden(true)
        }
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
        )
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}
