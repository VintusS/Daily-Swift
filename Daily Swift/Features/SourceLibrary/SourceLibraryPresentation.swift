import SwiftUI

struct ImportedSourceRow: View {
    let document: SourceDocument
    let chunkCount: Int

    var body: some View {
        HStack(
            alignment: .top,
            spacing: StudioTokens.Spacing.small
        ) {
            Image(systemName: "doc.text")
                .font(.title3)
                .foregroundStyle(StudioTokens.Color.action)
                .frame(minWidth: 30, minHeight: 30)
                .accessibilityHidden(true)

            VStack(
                alignment: .leading,
                spacing: StudioTokens.Spacing.xSmall
            ) {
                Text(document.title)
                    .font(StudioTokens.Typography.sectionHeading)
                    .foregroundStyle(StudioTokens.Color.primaryText)

                Text(document.originFileName)
                    .font(StudioTokens.Typography.supporting)
                    .foregroundStyle(StudioTokens.Color.secondaryText)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: StudioTokens.Spacing.xSmall) {
                        badges
                    }
                    VStack(
                        alignment: .leading,
                        spacing: StudioTokens.Spacing.xxSmall
                    ) {
                        badges
                    }
                }
            }

            Spacer(minLength: StudioTokens.Spacing.xSmall)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StudioTokens.Color.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.vertical, StudioTokens.Spacing.xxSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(document.title)
        .accessibilityValue(
            "\(document.format.label), \(document.rightsStatus.label), local only, \(chunkCount) passages"
        )
        .accessibilityHint("Opens source provenance and exact passages.")
    }

    @ViewBuilder
    private var badges: some View {
        LearningBadge(
            "Local source",
            symbol: "iphone",
            role: .information
        )
        LearningBadge(
            "\(chunkCount) \(chunkCount == 1 ? "passage" : "passages")",
            symbol: "quote.opening"
        )
    }
}

struct SourceLibraryFeedbackNotice: View {
    let feedback: SourceLibraryFeedback
    let onOpenSource: (UUID) -> Void
    let onDismiss: () -> Void

    var body: some View {
        switch feedback {
        case .idle:
            EmptyView()

        case .cancelled:
            notice(
                role: .information,
                title: "Import cancelled",
                message: "Nothing was added or changed."
            )

        case let .imported(sourceID):
            notice(
                role: .success,
                title: "Source available offline",
                message: "The approved original, normalized text, and exact passages are stored locally.",
                actionTitle: "Open Source",
                action: { onOpenSource(sourceID) }
            )

        case let .duplicate(existingSourceID):
            notice(
                role: .warning,
                title: "Source already imported",
                message: "An existing source has the same normalized content.",
                actionTitle: "Open Existing",
                action: { onOpenSource(existingSourceID) }
            )

        case .deleted:
            notice(
                role: .success,
                title: "Source deleted",
                message: "The original, normalized text, metadata, and derived passages were removed."
            )

        case let .failed(failure):
            notice(
                role: .error,
                title: failure.title,
                message: failure.message
            )
        }
    }

    private func notice(
        role: StatusNoticeRole,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: StudioTokens.Spacing.small
        ) {
            HStack(alignment: .top) {
                VStack(
                    alignment: .leading,
                    spacing: StudioTokens.Spacing.xxSmall
                ) {
                    Text(title)
                        .font(StudioTokens.Typography.sectionHeading)
                    Text(message)
                        .font(StudioTokens.Typography.supporting)
                        .foregroundStyle(
                            StudioTokens.Color.secondaryText
                        )
                }

                Spacer()

                Button("Dismiss", systemImage: "xmark") {
                    onDismiss()
                }
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("source-feedback.dismiss")
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(StudioTokens.Spacing.medium)
        .background(
            StudioTokens.Color.surface,
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
            .stroke(borderColor(for: role), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func borderColor(
        for role: StatusNoticeRole
    ) -> Color {
        switch role {
        case .information:
            StudioTokens.Color.information.opacity(0.55)
        case .success:
            StudioTokens.Color.success.opacity(0.55)
        case .warning:
            StudioTokens.Color.warning.opacity(0.55)
        case .error:
            StudioTokens.Color.error.opacity(0.55)
        }
    }
}
