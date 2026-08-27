import SwiftUI

/// Design tokens — implements DESIGN.md verbatim. That document is the
/// source of truth; change it first, then this file.
enum Theme {
    // MARK: Palette (light / dark per DESIGN.md §1.1, §1.3)
    static let primary = Color(light: "#2AB3A6", dark: "#34D1BF")
    static let primaryDark = Color(light: "#1D8C82", dark: "#2AB3A6")
    static let primaryLight = Color(light: "#E0F5F1", dark: "#1C3B37")
    static let background = Color(light: "#FAFAF8", dark: "#0F0F11")
    static let surface = Color(light: "#F2F2EF", dark: "#1C1C1E")
    static let surfaceElevated = Color(light: "#FFFFFF", dark: "#2C2C2E")
    static let textPrimary = Color(light: "#1C1C1E", dark: "#F5F5F5")
    static let textSecondary = Color(light: "#6B7280", dark: "#8E8E93")
    static let textTertiary = Color(light: "#9CA3AF", dark: "#636366")

    // MARK: Semantic (DESIGN.md §1.2 — never the sole carrier of meaning)
    static let success = Color(light: "#10B981", dark: "#10B981")
    static let warning = Color(light: "#F59E0B", dark: "#F59E0B")
    static let danger = Color(light: "#EF4444", dark: "#EF4444")

    // MARK: Spacing & radii (DESIGN.md §3)
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
