import SwiftUI

struct StudioBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                base

                guidePattern(in: geometry.size)

                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(
                        .system(
                            size: min(max(geometry.size.width * 0.28, 96), 164),
                            weight: .ultraLight,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(
                        StudioTokens.Color.action.opacity(
                            reduceTransparency ? 0.06 : motifOpacity
                        )
                    )
                    .padding(StudioTokens.Spacing.xLarge)
            }
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var base: some View {
        if reduceTransparency {
            StudioTokens.Color.canvas
        } else {
            LinearGradient(
                colors: [
                    StudioTokens.Color.groupedCanvas,
                    StudioTokens.Color.canvas
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var motifOpacity: Double {
        colorSchemeContrast == .increased ? 0.16 : 0.10
    }

    private var guideOpacity: Double {
        colorSchemeContrast == .increased ? 0.42 : 0.22
    }

    private var guideWidth: CGFloat {
        colorSchemeContrast == .increased ? 1 : 0.5
    }

    private func guidePattern(in size: CGSize) -> some View {
        Path { path in
            var x = StudioTokens.Spacing.xLarge

            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += StudioTokens.Spacing.xLarge
            }

            var y = StudioTokens.Spacing.xLarge

            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += StudioTokens.Spacing.xLarge
            }
        }
        .stroke(
            StudioTokens.Color.separator.opacity(guideOpacity),
            lineWidth: guideWidth
        )
    }
}
