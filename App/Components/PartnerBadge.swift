import SwiftUI

/// Partner attribution badge (DESIGN.md §2.5): the partner's color paired
/// with their name — color is never the only carrier. Joint spending always
/// uses the neutral slate badge; it belongs to no one.
struct PartnerBadge: View {
    /// Display name — a partner's name or "Joint".
    let name: String
    /// Badge color hex — a partner's chosen color, or slate for Joint.
    let colorHex: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(hexString: colorHex))
                .frame(width: 8, height: 8)
            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Theme.surface, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Attributed to \(name)"))
    }
}

extension Color {
    /// Opaque color from a `#RRGGBB` hex string (data-driven colors: partner
    /// badges, category chart colors). Theme tokens stay in `Theme`.
    init(hexString: String) {
        self.init(uiColor: UIColor(hex: hexString))
    }
}

#Preview {
    HStack {
        PartnerBadge(name: "Maya", colorHex: "#6366F1")
        PartnerBadge(name: "Sam", colorHex: "#F97316")
        PartnerBadge(name: "Joint", colorHex: "#64748B")
    }
    .padding()
    .background(Theme.background)
}
