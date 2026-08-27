import SwiftUI
import TwoStepCore

/// The Savings tool's hero snapshot (PRD §4.5, priority): combined progress
/// across ALL active projects — total saved as the hero numeral against total
/// planned, with each partner's (and Joint's) contribution share visible in
/// the stacked bar and the legend beneath. One glance answers "how are we
/// doing on everything we're saving for?".
struct SavingsCombinedHeroView: View {
    let totalSavedMinor: Int
    let totalPlannedMinor: Int
    let projectCount: Int
    /// Fixed order — members first, then Joint. Never ranked (PRD §2.2).
    let shares: [SavingsShare]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeroNumberView(amountMinor: totalSavedMinor)
            Text(plannedLine)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
            stackedBar
            legend
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    // MARK: Pieces

    private var stackedBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.surface)
                HStack(spacing: 0) {
                    ForEach(shares.filter { $0.amountMinor > 0 }) { share in
                        Rectangle()
                            .fill(Color(hexString: share.colorHex))
                            .frame(width: geometry.size.width * width(of: share))
                    }
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: 14)
    }

    private var legend: some View {
        HStack(alignment: .top, spacing: Theme.cardSpacing) {
            ForEach(shares) { share in
                VStack(alignment: .leading, spacing: 3) {
                    PartnerBadge(name: share.name, colorHex: share.colorHex)
                    Text(SavingsFormat.currency(share.amountMinor))
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Math (display fractions only — sums come in precomputed)

    private func width(of share: SavingsShare) -> Double {
        guard totalPlannedMinor > 0 else { return 0 }
        return min(1, Double(share.amountMinor) / Double(totalPlannedMinor))
    }

    private var plannedLine: String {
        let planned = SavingsFormat.compactCurrency(totalPlannedMinor)
        return projectCount == 1
            ? "of \(planned) planned across 1 project"
            : "of \(planned) planned across \(projectCount) projects"
    }

    private var accessibilitySummary: String {
        let total = SavingsFormat.currency(totalSavedMinor)
        let breakdown = shares
            .map { "\($0.name) \(SavingsFormat.currency($0.amountMinor))" }
            .joined(separator: ", ")
        return "Saved \(total) \(plannedLine). Contributions: \(breakdown)."
    }
}

#Preview {
    SavingsCombinedHeroView(
        totalSavedMinor: 2_050_00,
        totalPlannedMinor: 7_800_00,
        projectCount: 3,
        shares: [
            SavingsShare(id: "a", name: "Maya", colorHex: "#6366F1", amountMinor: 1_150_00),
            SavingsShare(id: "b", name: "Sam", colorHex: "#F97316", amountMinor: 900_00)
        ]
    )
    .padding()
    .background(Theme.background)
}
