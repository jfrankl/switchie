import SwiftUI
import AppKit

/// Single source of truth for colors, metrics, and typography.
/// Always reference colors via Theme.Color rather than NSColor / Color directly,
/// so the entire app stays consistent.
enum Theme {

    // MARK: - Colors

    enum Color {
        static let accent             = SwiftUI.Color(NSColor.controlAccentColor)
        static let accentSubtle       = SwiftUI.Color(NSColor.controlAccentColor).opacity(0.18)
        static let background         = SwiftUI.Color(NSColor.windowBackgroundColor)
        static let elevatedBackground = SwiftUI.Color(NSColor.underPageBackgroundColor)
        static let fieldBackground    = SwiftUI.Color(NSColor.controlBackgroundColor)
        static let label              = SwiftUI.Color(NSColor.labelColor)
        static let secondaryLabel     = SwiftUI.Color(NSColor.secondaryLabelColor)
        static let tertiaryLabel      = SwiftUI.Color(NSColor.tertiaryLabelColor)
        static let separator          = SwiftUI.Color(NSColor.separatorColor)
    }

    // MARK: - Metrics

    enum Metrics {
        static let labelColumnWidth: CGFloat = 130
        static let fieldWidth: CGFloat       = 200
        static let pickerHeight: CGFloat     = 28
        static let cornerRadius: CGFloat     = 6
        static let rowSpacing: CGFloat       = 12
        static let sectionPadding: CGFloat   = 18
        static let contentPadding: CGFloat   = 24
    }

    // MARK: - Typography

    enum Font {
        static let body      = SwiftUI.Font.system(size: 13)
        static let label     = SwiftUI.Font.system(size: 13)
        static let helpText  = SwiftUI.Font.system(size: 11)
        static let tabLabel  = SwiftUI.Font.system(size: 10, weight: .medium)
        static let title     = SwiftUI.Font.system(size: 14, weight: .semibold)
        static let buttonLabel = SwiftUI.Font.system(size: 12, weight: .medium)
    }
}
