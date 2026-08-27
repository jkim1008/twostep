import SwiftUI

/// Design tokens — implements DESIGN.md v2.0 (sage system) verbatim.
/// That document is the source of truth; change it first, then this file.
enum Theme {
    // MARK: Palette (light / dark per DESIGN.md §2.1, §2.2)
    static let background = Color(light: "#FAFBF8", dark: "#141714")
    static let surface = Color(light: "#F1F3EC", dark: "#1D211C")
    static let surfaceElevated = Color(light: "#FFFFFF", dark: "#262B24")
    static let primary = Color(light: "#6F8360", dark: "#A3B98F")
    static let primaryDark = Color(light: "#59704C", dark: "#8CA378")
    static let primaryTint = Color(light: "#E4EAD9", dark: "#2A3326")
    static let textPrimary = Color(light: "#1D211C", dark: "#F2F4EF")
    static let textSecondary = Color(light: "#66705F", dark: "#9AA398")
    static let textTertiary = Color(light: "#98A091", dark: "#6E7769")
    static let separator = Color(light: "#E3E7DD", dark: "#2E342B")

    // MARK: Semantic (DESIGN.md §2.3 — never the sole carrier of meaning)
    static let success = Color(light: "#4F9D69", dark: "#4F9D69")
    static let warning = Color(light: "#E0A458", dark: "#E0A458")
    static let danger = Color(light: "#D9634E", dark: "#D9634E")
    static let info = Color(light: "#6C91C2", dark: "#6C91C2")

    // MARK: Spacing & radii (DESIGN.md §4)
    static let cardCornerRadius: CGFloat = 14
    static let cardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
}

extension Color {
    /// Dynamic color from light/dark hex pairs.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    /// `#RRGGBB` hex string. Malformed input yields opaque black in debug builds via assertion.
    convenience init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let valid = Scanner(string: cleaned).scanHexInt64(&value) && cleaned.count == 6
        assert(valid, "Malformed hex color: \(hex)")
        self.init(
            red: CGFloat((value & 0xFF0000) >> 16) / 255,
            green: CGFloat((value & 0x00FF00) >> 8) / 255,
            blue: CGFloat(value & 0x0000FF) / 255,
            alpha: 1
        )
    }
}
