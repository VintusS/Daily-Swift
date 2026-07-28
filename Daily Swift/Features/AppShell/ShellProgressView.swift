import SwiftUI

struct ShellProgressView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    @AccessibilityFocusState private var headingIsFocused: Bool

    var body: some View {
        ZStack {
            StudioBackground()
                .ignoresSafeArea()

            VStack(spacing: StudioTokens.Spacing.xLarge) {
                StudioBrandMark()

                VStack(spacing: StudioTokens.Spacing.small) {
                    Text(title)
                        .font(StudioTokens.Typography.title)
                        .foregroundStyle(StudioTokens.Color.primaryText)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($headingIsFocused)

                    Text(message)
                        .font(StudioTokens.Typography.supporting)
                        .foregroundStyle(StudioTokens.Color.secondaryText)
                        .multilineTextAlignment(.center)
                }

                ProgressView()
                    .controlSize(.large)
                    .tint(StudioTokens.Color.action)
                    .accessibilityLabel(title)
            }
            .padding(StudioTokens.Spacing.xLarge)
        }
        .accessibilityIdentifier("app-shell.progress")
        .task {
            headingIsFocused = true
        }
    }
}
