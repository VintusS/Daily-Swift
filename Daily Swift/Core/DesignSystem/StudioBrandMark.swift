import SwiftUI

struct StudioBrandMark: View {
    let showsTitle: Bool

    @ScaledMetric(relativeTo: .title) private var markSize: CGFloat = 56
    @ScaledMetric(relativeTo: .title) private var symbolSize: CGFloat = 30

    init(showsTitle: Bool = true) {
        self.showsTitle = showsTitle
    }

    var body: some View {
        HStack(spacing: StudioTokens.Spacing.small) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: StudioTokens.Radius.card,
                    style: .continuous
                )
                .fill(StudioTokens.Color.surface)

                RoundedRectangle(
                    cornerRadius: StudioTokens.Radius.card,
                    style: .continuous
                )
                .stroke(StudioTokens.Color.separator, lineWidth: 1)

                Image(systemName: "swift")
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(StudioTokens.Color.action)
            }
            .frame(
                width: max(markSize, 44),
                height: max(markSize, 44)
            )

            if showsTitle {
                Text("Daily Swift")
                    .font(StudioTokens.Typography.title)
                    .foregroundStyle(StudioTokens.Color.primaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily Swift")
    }
}
