import SwiftUI
import UIKit

enum StudioTokens {
    enum Color {
        static var canvas: SwiftUI.Color {
            SwiftUI.Color(uiColor: .systemBackground)
        }

        static var groupedCanvas: SwiftUI.Color {
            SwiftUI.Color(uiColor: .systemGroupedBackground)
        }

        static var surface: SwiftUI.Color {
            SwiftUI.Color(uiColor: .secondarySystemBackground)
        }

        static var raisedSurface: SwiftUI.Color {
            SwiftUI.Color(uiColor: .tertiarySystemBackground)
        }

        static var primaryText: SwiftUI.Color {
            SwiftUI.Color(uiColor: .label)
        }

        static var secondaryText: SwiftUI.Color {
            SwiftUI.Color(uiColor: .secondaryLabel)
        }

        static var tertiaryText: SwiftUI.Color {
            SwiftUI.Color(uiColor: .tertiaryLabel)
        }

        static var separator: SwiftUI.Color {
            SwiftUI.Color(uiColor: .separator)
        }

        static var action: SwiftUI.Color {
            SwiftUI.Color.accentColor
        }

        static var focus: SwiftUI.Color {
            SwiftUI.Color.accentColor
        }

        static var information: SwiftUI.Color {
            SwiftUI.Color(uiColor: .systemBlue)
        }

        static var success: SwiftUI.Color {
            SwiftUI.Color(uiColor: .systemGreen)
        }

        static var warning: SwiftUI.Color {
            SwiftUI.Color(uiColor: .systemOrange)
        }

        static var error: SwiftUI.Color {
            SwiftUI.Color(uiColor: .systemRed)
        }
    }

    enum Typography {
        static var display: Font {
            .largeTitle.weight(.bold)
        }

        static var title: Font {
            .title2.weight(.semibold)
        }

        static var sectionHeading: Font {
            .headline
        }

        static var body: Font {
            .body
        }

        static var supporting: Font {
            .subheadline
        }

        static var caption: Font {
            .caption
        }

        static var codeBody: Font {
            .system(.body, design: .monospaced)
        }

        static var codeCaption: Font {
            .system(.caption, design: .monospaced)
        }
    }

    enum Spacing {
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 12
        static let card: CGFloat = 16
    }
}
