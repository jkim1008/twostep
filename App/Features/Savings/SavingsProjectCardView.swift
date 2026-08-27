import SwiftUI
import TwoStepCore

/// One savings project card (PRD §4.5): emoji + name, progress ring with the
/// saved amount centered, saved-of-target line, and per-partner contribution
/// amounts — neutral bookkeeping, fixed order, never a comparison.
struct SavingsProjectCardView: View {
    let project: SavingsProject
    let shares: [SavingsShare]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(project.emoji)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(project.name)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            SavingsRingView(fraction: project.progressFraction) {
                Text(SavingsFormat.compactCurrency(project.savedAmountMinor))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: 96)
            .frame(maxWidth: .infinity)
            Text(targetLine)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
            partnerAmounts
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .strokeBorder(Theme.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private var partnerAmounts: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(shares.filter { $0.amountMinor > 0 }) { share in
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(hexString: share.colorHex))
                        .frame(width: 7, height: 7)
                    Text(share.name)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 4)
                    Text(SavingsFormat.currency(share.amountMinor))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
    }

    private var targetLine: String {
        if let target = project.targetAmountMinor {
            let saved = SavingsFormat.compactCurrency(project.savedAmountMinor)
            return "\(saved) of \(SavingsFormat.compactCurrency(target))"
        }
        return "Open-ended"
    }

    private var accessibilitySummary: String {
        let breakdown = shares
            .filter { $0.amountMinor > 0 }
            .map { "\($0.name) \(SavingsFormat.currency($0.amountMinor))" }
            .joined(separator: ", ")
        let progress = project.progressFraction.map { " \(Int(($0 * 100).rounded())) percent funded." } ?? ""
        return "\(project.name), \(targetLine).\(progress) \(breakdown)"
    }
}

#Preview {
    SavingsProjectCardView(
        project: SavingsProject(
            id: "preview", name: "Anniversary Trip", emoji: "🏝️",
            recurringContributionMinor: 200_00, cadence: .monthly,
            durationMonths: 8, savedAmountMinor: 450_00
        ),
        shares: [
            SavingsShare(id: "a", name: "Maya", colorHex: "#6366F1", amountMinor: 250_00),
            SavingsShare(id: "b", name: "Sam", colorHex: "#F97316", amountMinor: 200_00)
        ]
    )
    .frame(width: 190)
    .padding()
    .background(Theme.background)
}
