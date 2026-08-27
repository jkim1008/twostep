import SwiftUI
import TwoStepCore

/// The hero-numeral pattern (DESIGN.md §3, §5.3): one large, bold,
/// tabular-digit dollar figure that animates a brief count-up when its
/// value changes — money visibly accumulating is a feature.
struct HeroNumberView: View {
    let amountMinor: Int
    var currencyCode: String = "USD"

    /// Scales relative to Dynamic Type instead of a fixed size (DESIGN.md §3).
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 48
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(formattedAmount)
            .font(.system(size: heroSize, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Theme.textPrimary)
            .contentTransition(.numericText(value: Double(amountMinor)))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: amountMinor)
            .accessibilityLabel(Text(formattedAmount))
    }

    private var formattedAmount: String {
        Money(amountMinor: amountMinor, currencyCode: currencyCode)
            .decimalValue
            .formatted(.currency(code: currencyCode))
    }
}

#Preview {
    HeroNumberView(amountMinor: 1_842_67)
        .padding()
        .background(Theme.background)
}
