import SwiftUI

struct ReadyStudioView: View {
    let sessionMode: AppSessionMode
    let onPrivacy: () -> Void

    @AccessibilityFocusState private var headingIsFocused: Bool

    var body: some View {
        ZStack {
            StudioBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: StudioTokens.Spacing.xLarge) {
                    HStack(alignment: .center, spacing: StudioTokens.Spacing.medium) {
                        StudioBrandMark(showsTitle: false)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: StudioTokens.Spacing.xxSmall) {
                            Text("Daily Swift")
                                .font(StudioTokens.Typography.sectionHeading)
                                .foregroundStyle(StudioTokens.Color.primaryText)

                            Text("Learning studio")
                                .font(StudioTokens.Typography.caption)
                                .foregroundStyle(StudioTokens.Color.secondaryText)
                        }
                    }

                    VStack(alignment: .leading, spacing: StudioTokens.Spacing.small) {
                        Text("Your studio is ready.")
                            .font(StudioTokens.Typography.display)
                            .foregroundStyle(StudioTokens.Color.primaryText)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($headingIsFocused)
                            .accessibilityIdentifier("app-shell.ready")

                        Text(
                            "This is the stable home for the learning experience "
                                + "we’ll build one dependable layer at a time."
                        )
                        .font(StudioTokens.Typography.body)
                        .foregroundStyle(StudioTokens.Color.secondaryText)
                    }

                    StatusNotice(
                        role: sessionMode == .persistent ? .success : .warning,
                        title: sessionMode == .persistent
                            ? "Launch state saved"
                            : "Temporary session",
                        message: sessionMode == .persistent
                            ? "Daily Swift can restore this production shell on your next launch."
                            : "You can keep using the shell, but this session will not replace unreadable stored state."
                    )

                    VStack(alignment: .leading, spacing: StudioTokens.Spacing.medium) {
                        Text("What stays true")
                            .font(StudioTokens.Typography.title)
                            .foregroundStyle(StudioTokens.Color.primaryText)
                            .accessibilityAddTraits(.isHeader)

                        StudioCommitmentRow(
                            symbol: "wifi.slash",
                            title: "Useful offline",
                            detail: "Imported sources and saved generated learning remain readable when generation is unavailable."
                        )
                        StudioCommitmentRow(
                            symbol: "lock.shield",
                            title: "Private by default",
                            detail: "Imported sources and personal learning data stay on device unless you choose otherwise."
                        )
                        StudioCommitmentRow(
                            symbol: "scope",
                            title: "Honest evidence",
                            detail: "The interface distinguishes generated, structurally validated, and compiled results."
                        )
                    }
                    .padding(StudioTokens.Spacing.large)
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

                    Button(action: onPrivacy) {
                        Label("Review Privacy & Data", systemImage: "hand.raised")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StudioPrimaryButtonStyle())
                    .accessibilityIdentifier("app-shell.privacy")
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

private struct StudioCommitmentRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    @ScaledMetric(relativeTo: .body) private var symbolFrame: CGFloat = 28

    var body: some View {
        HStack(alignment: .top, spacing: StudioTokens.Spacing.medium) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
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
        }
        .accessibilityElement(children: .combine)
    }
}
