import SwiftUI

struct RecoverableStorageFailureView: View {
    let failure: AppShellFailure
    let onRetry: () -> Void
    let onContinueTemporarily: () -> Void
    let onReset: () -> Void

    @State private var isResetConfirmationPresented = false
    @AccessibilityFocusState private var headingIsFocused: Bool

    var body: some View {
        ZStack {
            StudioBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: StudioTokens.Spacing.xLarge) {
                    StudioBrandMark()

                    VStack(alignment: .leading, spacing: StudioTokens.Spacing.small) {
                        Text("We couldn’t restore your learning space.")
                            .font(StudioTokens.Typography.display)
                            .foregroundStyle(StudioTokens.Color.primaryText)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($headingIsFocused)
                            .accessibilityIdentifier("app-shell.failure")

                        Text(
                            "Your learning data was not exposed or silently "
                                + "deleted. Choose how you want to continue."
                        )
                        .font(StudioTokens.Typography.body)
                        .foregroundStyle(StudioTokens.Color.secondaryText)
                    }

                    StatusNotice(
                        role: .error,
                        title: failure.noticeTitle,
                        message: failure.noticeMessage
                    )

                    VStack(spacing: StudioTokens.Spacing.small) {
                        Button(action: onRetry) {
                            Label("Try restoring again", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudioPrimaryButtonStyle())
                        .accessibilityHint(
                            "Attempts to read the saved launch state again."
                        )
                        .accessibilityIdentifier("app-shell.retry")

                        Button(action: onContinueTemporarily) {
                            Label("Continue temporarily", systemImage: "rectangle.and.pencil.and.ellipsis")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudioSecondaryButtonStyle())
                        .accessibilityHint(
                            "Keeps saved state unchanged and opens a session "
                                + "that will not be restored."
                        )
                        .accessibilityIdentifier("app-shell.continue-temporarily")

                        if failure.canReset {
                            Button(
                                role: .destructive,
                                action: {
                                    isResetConfirmationPresented = true
                                }
                            ) {
                                Label("Reset launch state", systemImage: "trash")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                            .tint(StudioTokens.Color.error)
                            .accessibilityHint(
                                "Deletes only the local launch snapshot after "
                                    + "confirmation."
                            )
                            .accessibilityIdentifier("app-shell.reset")
                        }
                    }

                    Text(
                        "Resetting affects only this small launch snapshot. "
                            + "It does not delete sources, lessons, or learner data."
                    )
                    .font(StudioTokens.Typography.caption)
                    .foregroundStyle(StudioTokens.Color.secondaryText)
                }
                .frame(maxWidth: 680)
                .padding(StudioTokens.Spacing.large)
                .padding(.vertical, StudioTokens.Spacing.medium)
                .frame(maxWidth: .infinity)
            }
        }
        .confirmationDialog(
            "Reset the local launch state?",
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Reset launch state", role: .destructive, action: onReset)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Daily Swift will return to the first-run screen.")
        }
        .task {
            headingIsFocused = true
        }
    }
}

private extension AppShellFailure {
    var noticeTitle: LocalizedStringKey {
        switch self {
        case .storeUnavailable:
            "Storage is temporarily unavailable"
        case .restorationCorrupt:
            "The launch snapshot cannot be read"
        case .unsupportedSnapshotVersion:
            "This launch snapshot is from another version"
        case .saveFailed:
            "The launch state could not be saved"
        }
    }

    var noticeMessage: LocalizedStringKey {
        switch self {
        case .storeUnavailable:
            "Retry now, or continue in a temporary session without replacing stored state."
        case .restorationCorrupt:
            "The snapshot stayed in place. You can retry, continue temporarily, or reset only the launch state."
        case .unsupportedSnapshotVersion:
            "Daily Swift left the newer snapshot untouched so it can fail closed safely."
        case .saveFailed:
            "Your action was not reported as saved. Retry before relying on restoration."
        }
    }

    var canReset: Bool {
        switch self {
        case .restorationCorrupt, .unsupportedSnapshotVersion:
            true
        case .storeUnavailable, .saveFailed:
            false
        }
    }
}
