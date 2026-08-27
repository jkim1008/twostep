import Foundation
import Observation
import SwiftUI
import TwoStepCore

/// One attribution's share of saved money: a partner, or Joint.
/// Neutral bookkeeping (PRD §2.2) — order is fixed (members, then Joint),
/// never ranked by amount.
struct SavingsShare: Identifiable, Hashable {
    let id: String
    let name: String
    let colorHex: String
    let amountMinor: Int
}

/// Aggregates contribution ledgers into per-attribution shares. Pure sums —
/// the aggregate invariant (saved == Σ contributions) is owned by the
/// repository; this only groups for display.
enum SavingsShareMath {
    @MainActor
    static func shares(
        contributions: [Contribution],
        households: any HouseholdRepository
    ) -> [SavingsShare] {
        var totals: [String: Int] = [:]
        for contribution in contributions {
            totals[contribution.contributedByUid, default: 0] += contribution.amountMinor
        }
        var shares: [SavingsShare] = households.members.map { member in
            SavingsShare(
                id: member.id,
                name: member.displayName,
                colorHex: member.colorHex,
                amountMinor: totals.removeValue(forKey: member.id) ?? 0
            )
        }
        // Whatever is left is Joint (or an unknown uid — render it neutrally).
        let remainder = totals.values.reduce(0, +)
        if remainder > 0 {
            shares.append(SavingsShare(
                id: Attribution.joint.rawValue,
                name: households.displayName(for: .joint),
                colorHex: households.badgeColorHex(for: .joint),
                amountMinor: remainder
            ))
        }
        return shares
    }
}

/// Session-scoped archive overlay for the demo build. The demo
/// `SavingsRepository` protocol exposes no project-update mutation (archive
/// is a server-side field flip in production), so the archive/unarchive flow
/// is demonstrated through this local overlay; everything else — projects,
/// contributions, aggregates — lives in the repository.
@MainActor
@Observable
final class SavingsArchiveStore {
    private var overrides: [String: Bool] = [:]

    func isArchived(_ project: SavingsProject) -> Bool {
        overrides[project.id] ?? project.isArchived
    }

    func setArchived(_ archived: Bool, projectId: String) {
        overrides[projectId] = archived
        print("[SavingsArchiveStore] \(archived ? "Archived" : "Unarchived") project \(projectId)")
    }
}

/// Display-boundary formatting and parsing for the Savings feature. Money
/// stays integer minor units; `Decimal` appears only here (via `Money`).
enum SavingsFormat {
    static func currency(_ amountMinor: Int) -> String {
        Money(amountMinor: amountMinor).decimalValue.formatted(.currency(code: "USD"))
    }

    /// Whole-dollar rendering ("$1,600"), cents kept when present.
    static func compactCurrency(_ amountMinor: Int) -> String {
        let digits = amountMinor % 100 == 0 ? 0 : 2
        return Money(amountMinor: amountMinor).decimalValue
            .formatted(.currency(code: "USD").precision(.fractionLength(digits)))
    }

    /// `"2026-08-15"` → `"Aug 15"`.
    static func shortDay(_ dateString: String) -> String {
        guard let day = CalendarDay(dateString: dateString) else { return dateString }
        return "\(DateFormatter().shortMonthSymbols[day.month - 1]) \(day.day)"
    }

    /// Parses user dollars input to minor units via `Money`'s canonical
    /// rounding. Returns nil for empty, malformed, or negative input.
    static func minorUnits(fromInput input: String) -> Int? {
        let cleaned = input
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, let decimal = Decimal(string: cleaned), decimal >= 0 else {
            return nil
        }
        return Money(decimal: decimal).amountMinor
    }
}

/// Circular progress ring (DESIGN.md §5.1): clockwise fill, brief animated
/// fill on load, sage while in progress and success green at 100%. A nil
/// fraction (open-ended project, no target) renders a quiet full track.
struct SavingsRingView<Center: View>: View {
    let fraction: Double?
    var lineWidth: CGFloat = 10
    @ViewBuilder var center: () -> Center

    @State private var animatedFraction: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surface, style: StrokeStyle(lineWidth: lineWidth))
            if fraction != nil {
                Circle()
                    .trim(from: 0, to: animatedFraction)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            center()
                .padding(lineWidth + 6)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { animateIn() }
        .onChange(of: fraction) { animateIn() }
        .accessibilityElement(children: .combine)
    }

    private var ringColor: Color {
        (fraction ?? 0) >= 1 ? Theme.success : Theme.primary
    }

    private func animateIn() {
        let target = min(1, max(0, fraction ?? 0))
        if reduceMotion {
            animatedFraction = target
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                animatedFraction = target
            }
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        SavingsRingView(fraction: 0.45) {
            Text("$450")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
        SavingsRingView(fraction: 1.0) {
            Text("$1,200")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
    }
    .frame(height: 100)
    .padding()
    .background(Theme.background)
}
