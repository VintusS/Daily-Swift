import SwiftUI

struct FirstRunView: View {
    let isSaving: Bool
    let onContinue: () -> Void
    let onPrivacy: () -> Void

    @AccessibilityFocusState private var headingIsFocused: Bool

    var body: some View {
        ZStack {
            StudioBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: StudioTokens.Spacing.xLarge) {
                    StudioBrandMark()

                    VStack(alignment: .leading, spacing: StudioTokens.Spacing.small) {
                        Text("Build iOS skill that sticks.")
                            .font(StudioTokens.Typography.display)
                            .foregroundStyle(StudioTokens.Color.primaryText)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($headingIsFocused)
                            .accessibilityIdentifier("app-shell.first-run")

                        Text(
                            "A calm daily studio for Swift, SwiftUI, and the "
                                + "frameworks around them."
                        )
                        .font(StudioTokens.Typography.body)
                        .foregroundStyle(StudioTokens.Color.secondaryText)
                    }

                    VStack(spacing: StudioTokens.Spacing.small) {
                        FoundationPromiseRow(
                            symbol: "timer",
                            title: "Focused sessions",
                            detail: "Designed around a useful 20–30 minute rhythm."
                        )
                        FoundationPromiseRow(
                            symbol: "checkmark.seal",
                            title: "Evidence over activity",
                            detail: "Progress will explain what you proved, not just what you tapped."
                        )
                        FoundationPromiseRow(
                            symbol: "iphone.gen3",
                            title: "Local by default",
                            detail: "The learning path stays useful without a network, account, or model."
                        )
                    }

                    StatusNotice(
                        role: .information,
                        title: "Private from the foundation",
                        message: "No analytics SDK, no ads, and no source upload without your explicit choice."
                    )

                    VStack(spacing: StudioTokens.Spacing.small) {
                        Button(action: onContinue) {
                            Label(
                                isSaving ? "Creating your studio" : "Create my studio",
                                systemImage: "arrow.right"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudioPrimaryButtonStyle(isBusy: isSaving))
                        .disabled(isSaving)
                        .accessibilityIdentifier("app-shell.continue")

                        Button(action: onPrivacy) {
                            Label("Privacy & Data", systemImage: "hand.raised")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudioSecondaryButtonStyle())
                        .disabled(isSaving)
                        .accessibilityIdentifier("app-shell.privacy")
                    }

                    Text("No model, network, or iCloud account is required to begin.")
                        .font(StudioTokens.Typography.caption)
                        .foregroundStyle(StudioTokens.Color.secondaryText)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 680)
                .padding(StudioTokens.Spacing.large)
                .padding(.vertical, StudioTokens.Spacing.medium)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarBackButtonHidden()
        .task {
            headingIsFocused = true
        }
    }
}

private struct FoundationPromiseRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    @ScaledMetric(relativeTo: .body) private var symbolFrame: CGFloat = 32

    var body: some View {
        HStack(alignment: .top, spacing: StudioTokens.Spacing.medium) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(StudioTokens.Color.action)
                .frame(width: symbolFrame, height: symbolFrame)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: StudioTokens.Spacing.xxSmall) {
                Text(title)
                    .font(StudioTokens.Typography.sectionHeading)
                    .foregroundStyle(StudioTokens.Color.primaryText)

                Text(detail)
                    .font(StudioTokens.Typography.supporting)
                    .foregroundStyle(StudioTokens.Color.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(StudioTokens.Spacing.medium)
        .background(
            StudioTokens.Color.raisedSurface,
            in: RoundedRectangle(
                cornerRadius: StudioTokens.Radius.card,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: StudioTokens.Radius.card,
                style: .continuous
            )
            .stroke(StudioTokens.Color.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
