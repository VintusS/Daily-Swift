import SwiftUI

enum LearningBadgeRole {
    case neutral
    case information
    case success
    case warning

    fileprivate var color: Color {
        switch self {
        case .neutral:
            StudioTokens.Color.secondaryText
        case .information:
            StudioTokens.Color.information
        case .success:
            StudioTokens.Color.success
        case .warning:
            StudioTokens.Color.warning
        }
    }
}

struct LearningBadge: View {
    let text: String
    let symbol: String
    let role: LearningBadgeRole

    init(
        _ text: String,
        symbol: String,
        role: LearningBadgeRole = .neutral
    ) {
        self.text = text
        self.symbol = symbol
        self.role = role
    }

    var body: some View {
        Label(text, systemImage: symbol)
            .font(StudioTokens.Typography.codeCaption.weight(.semibold))
            .foregroundStyle(StudioTokens.Color.primaryText)
            .padding(.horizontal, StudioTokens.Spacing.xSmall)
            .padding(.vertical, StudioTokens.Spacing.xxSmall)
            .background(
                role.color.opacity(0.12),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(role.color.opacity(0.55), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
    }
}

struct LearningCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
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
                .stroke(StudioTokens.Color.separator, lineWidth: 1)
            }
    }
}

struct SelectableCodeBlock: View {
    let code: String
    let accessibilityLabel: String

    init(
        _ code: String,
        accessibilityLabel: String = "Code example"
    ) {
        self.code = code
        self.accessibilityLabel = accessibilityLabel
    }

    private var lines: [String] {
        code.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .map(String.init)
    }

    var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(lines.indices, id: \.self) { index in
                    let line = lines[index]
                    Text(line.isEmpty ? " " : line)
                        .accessibilityLabel("Line \(index + 1)")
                        .accessibilityValue(
                            line.isEmpty ? "Blank" : line
                        )
                }
            }
            .font(StudioTokens.Typography.codeBody)
            .foregroundStyle(StudioTokens.Color.primaryText)
            .textSelection(.enabled)
            .padding(StudioTokens.Spacing.medium)
            .fixedSize(horizontal: true, vertical: false)
        }
        .background(
            StudioTokens.Color.raisedSurface,
            in: RoundedRectangle(
                cornerRadius: StudioTokens.Radius.control,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: StudioTokens.Radius.control,
                style: .continuous
            )
            .stroke(StudioTokens.Color.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(accessibilityLabel), \(lines.count) lines"
        )
    }
}

struct EvidenceProgressView: View {
    let title: String
    let completed: Int
    let total: Int
    let supportingText: String

    private var fraction: Double {
        guard total > 0 else {
            return 0
        }
        return Double(completed) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioTokens.Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(StudioTokens.Typography.sectionHeading)
                    .foregroundStyle(StudioTokens.Color.primaryText)

                Spacer()

                Text("\(completed) of \(total)")
                    .font(StudioTokens.Typography.codeCaption.weight(.semibold))
                    .foregroundStyle(StudioTokens.Color.secondaryText)
            }

            ProgressView(value: fraction)
                .tint(StudioTokens.Color.action)
                .accessibilityHidden(true)

            Text(supportingText)
                .font(StudioTokens.Typography.supporting)
                .foregroundStyle(StudioTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(
            "\(completed) of \(total). \(supportingText)"
        )
    }
}
