import SwiftUI
import UIKit

struct StudioPrimaryButtonStyle: ButtonStyle {
    let isBusy: Bool

    init(isBusy: Bool = false) {
        self.isBusy = isBusy
    }

    func makeBody(configuration: Configuration) -> some View {
        StudioButtonStyleBody(
            configuration: configuration,
            appearance: .primary,
            isBusy: isBusy
        )
    }
}

struct StudioSecondaryButtonStyle: ButtonStyle {
    let isBusy: Bool

    init(isBusy: Bool = false) {
        self.isBusy = isBusy
    }

    func makeBody(configuration: Configuration) -> some View {
        StudioButtonStyleBody(
            configuration: configuration,
            appearance: .secondary,
            isBusy: isBusy
        )
    }
}

private struct StudioButtonStyleBody: View {
    enum Appearance: Equatable {
        case primary
        case secondary
    }

    let configuration: ButtonStyleConfiguration
    let appearance: Appearance
    let isBusy: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        ZStack {
            configuration.label
                .opacity(isBusy ? 0 : 1)

            if isBusy {
                ProgressView()
                    .tint(foregroundColor)
                    .accessibilityHidden(true)
            }
        }
        .font(StudioTokens.Typography.sectionHeading)
        .foregroundStyle(foregroundColor)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .padding(.horizontal, StudioTokens.Spacing.medium)
        .background {
            RoundedRectangle(
                cornerRadius: StudioTokens.Radius.control,
                style: .continuous
            )
            .fill(backgroundColor)
            .overlay {
                if appearance == .secondary {
                    RoundedRectangle(
                        cornerRadius: StudioTokens.Radius.control,
                        style: .continuous
                    )
                    .stroke(borderColor, lineWidth: borderWidth)
                }
            }
        }
        .contentShape(
            RoundedRectangle(
                cornerRadius: StudioTokens.Radius.control,
                style: .continuous
            )
        )
        .opacity(configuration.isPressed && !reduceMotion ? 0.82 : 1)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.12),
            value: configuration.isPressed
        )
        .allowsHitTesting(!isBusy)
        .accessibilityValue(isBusy ? "In progress" : "")
    }

    private var isInteractive: Bool {
        isEnabled && !isBusy
    }

    private var foregroundColor: Color {
        guard isInteractive else {
            return StudioTokens.Color.secondaryText
        }

        switch appearance {
        case .primary:
            return Color(uiColor: .systemBackground)
        case .secondary:
            return StudioTokens.Color.action
        }
    }

    private var backgroundColor: Color {
        guard isInteractive else {
            return Color(uiColor: .tertiarySystemFill)
        }

        switch appearance {
        case .primary:
            return StudioTokens.Color.action
        case .secondary:
            return StudioTokens.Color.surface
        }
    }

    private var borderColor: Color {
        isInteractive
            ? StudioTokens.Color.action
            : StudioTokens.Color.separator
    }

    private var borderWidth: CGFloat {
        isInteractive ? 1.5 : 1
    }
}
