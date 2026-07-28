import SwiftUI

enum StatusNoticeRole: Sendable {
    case information
    case success
    case warning
    case error

    fileprivate var symbolName: String {
        switch self {
        case .information:
            "info.circle.fill"
        case .success:
            "checkmark.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .error:
            "xmark.octagon.fill"
        }
    }

    fileprivate var label: LocalizedStringKey {
        switch self {
        case .information:
            "Information"
        case .success:
            "Success"
        case .warning:
            "Warning"
        case .error:
            "Error"
        }
    }

    fileprivate var color: Color {
        switch self {
        case .information:
            StudioTokens.Color.information
        case .success:
            StudioTokens.Color.success
        case .warning:
            StudioTokens.Color.warning
        case .error:
            StudioTokens.Color.error
        }
    }
}

struct StatusNotice: View {
    let role: StatusNoticeRole
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: StudioTokens.Spacing.small) {
            Image(systemName: role.symbolName)
                .font(StudioTokens.Typography.sectionHeading)
                .foregroundStyle(role.color)
                .accessibilityLabel(role.label)

            VStack(alignment: .leading, spacing: StudioTokens.Spacing.xxSmall) {
                Text(title)
                    .font(StudioTokens.Typography.sectionHeading)
                    .foregroundStyle(StudioTokens.Color.primaryText)

                Text(message)
                    .font(StudioTokens.Typography.supporting)
                    .foregroundStyle(StudioTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(StudioTokens.Spacing.medium)
        .background {
            RoundedRectangle(
                cornerRadius: StudioTokens.Radius.card,
                style: .continuous
            )
            .fill(StudioTokens.Color.surface)
            .overlay {
                RoundedRectangle(
                    cornerRadius: StudioTokens.Radius.card,
                    style: .continuous
                )
                .stroke(StudioTokens.Color.separator, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
