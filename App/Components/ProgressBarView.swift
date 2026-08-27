import SwiftUI

/// Horizontal budget progress bar with the DESIGN.md §5.1 threshold colors:
/// sage below 75%, warning at 75–99%, danger at ≥100%.
///
/// PRD §4.4 stance: a category without an allocation has no on/off-track
/// state — pass `allocationMinor: nil` and no bar renders at all. Callers
/// always pair the bar with text (color is never the only signal).
struct ProgressBarView: View {
    let spentMinor: Int
    /// nil = unallocated category: renders nothing.
    let allocationMinor: Int?
    var height: CGFloat = 8

    var body: some View {
        if let allocationMinor, allocationMinor > 0 {
            bar(allocation: allocationMinor)
        }
    }

    private func bar(allocation: Int) -> some View {
        let fraction = min(1.0, max(0.0, Double(spentMinor) / Double(allocation)))
        let percent = Int((Double(max(0, spentMinor)) / Double(allocation) * 100).rounded())
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.surface)
                Capsule()
                    .fill(thresholdColor(spent: spentMinor, allocation: allocation))
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(Text("\(percent) percent of budget spent"))
    }

    /// Sage up to 75%, warning at 75–99%, danger at ≥100% — integer math,
    /// no float thresholds.
    private func thresholdColor(spent: Int, allocation: Int) -> Color {
        if spent >= allocation {
            Theme.danger
        } else if spent * 4 >= allocation * 3 {
            Theme.warning
        } else {
            Theme.primary
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ProgressBarView(spentMinor: 30_00, allocationMinor: 100_00)
        ProgressBarView(spentMinor: 82_00, allocationMinor: 100_00)
        ProgressBarView(spentMinor: 120_00, allocationMinor: 100_00)
        ProgressBarView(spentMinor: 55_00, allocationMinor: nil)
    }
    .padding()
    .background(Theme.background)
}
