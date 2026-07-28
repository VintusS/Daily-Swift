import SwiftUI

struct PrivacyAndDataView: View {
    let isLearningSessionTemporary: Bool

    init(isLearningSessionTemporary: Bool = false) {
        self.isLearningSessionTemporary = isLearningSessionTemporary
    }

    var body: some View {
        ZStack {
            StudioBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: StudioTokens.Spacing.xLarge) {
                    VStack(alignment: .leading, spacing: StudioTokens.Spacing.small) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(StudioTokens.Color.action)
                            .accessibilityHidden(true)

                        Text("Your work stays yours.")
                            .font(StudioTokens.Typography.display)
                            .foregroundStyle(StudioTokens.Color.primaryText)
                            .accessibilityAddTraits(.isHeader)

                        Text(
                            "Daily Swift is designed around local learning, "
                                + "clear consent, and recoverable data."
                        )
                        .font(StudioTokens.Typography.body)
                        .foregroundStyle(StudioTokens.Color.secondaryText)
                    }
                    .accessibilityIdentifier("privacy-and-data.screen")

                    if isLearningSessionTemporary {
                        StatusNotice(
                            role: .warning,
                            title: "Temporary mode is active",
                            message: "Learning changes are not being written to SwiftData and will disappear when the app closes."
                        )
                    }

                    StatusNotice(
                        role: .success,
                        title: "Private by default",
                        message: "The foundation contains no analytics SDK, no ad SDK, and no required account."
                    )

                    VStack(spacing: StudioTokens.Spacing.small) {
                        PrivacyCommitment(
                            symbol: "internaldrive",
                            title: "Learning progress",
                            detail: "Challenge attempts, article activity, interaction preferences, and your selected tab are stored locally with SwiftData. No account or cloud connection is required."
                        )
                        PrivacyCommitment(
                            symbol: "doc.text.magnifyingglass",
                            title: "Sources",
                            detail: "Imported documents remain on device by default. Private material is never treated as redistributable content."
                        )
                        PrivacyCommitment(
                            symbol: "sparkles.rectangle.stack",
                            title: "Generation",
                            detail: "On-device generation stays optional. Unavailable or rejected output never blocks deterministic learning."
                        )
                        PrivacyCommitment(
                            symbol: "icloud.slash",
                            title: "Sync",
                            detail: "iCloud is not required for offline use. Sync will be enabled only with explicit conflict and recovery behavior."
                        )
                        PrivacyCommitment(
                            symbol: "arrow.down.doc",
                            title: "Control",
                            detail: "Export and complete deletion remain product requirements before personal-product hardening closes."
                        )
                    }

                    Text(
                        isLearningSessionTemporary
                            ? "Clearing the temporary session removes only its in-memory activity; it does not modify the unavailable persistent store. PDF, TXT, and Markdown imports have separate local deletion; retrieval, sync, and export remain later capabilities."
                            : "Resetting learning progress removes only these local studio records. PDF, TXT, and Markdown imports have separate local deletion; retrieval, sync, and export remain later capabilities."
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
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyCommitment: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    @ScaledMetric(relativeTo: .body) private var symbolFrame: CGFloat = 34

    var body: some View {
        HStack(alignment: .top, spacing: StudioTokens.Spacing.medium) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(StudioTokens.Color.action)
                .frame(width: symbolFrame, height: symbolFrame)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: StudioTokens.Spacing.xSmall) {
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

#Preview("Privacy & Data") {
    NavigationStack {
        PrivacyAndDataView()
    }
}
