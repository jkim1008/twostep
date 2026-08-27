import SwiftUI
import TwoStepCore

/// The agenda beneath the calendar hero (PRD §4.6): every occurrence of the
/// visible period in date order — merchant, expected amount, due date,
/// attribution badge, source account, and paid/paused state.
struct RecurringAgendaView: View {
    let occurrences: [BillOccurrence]
    let displayName: (Attribution) -> String
    let badgeColorHex: (Attribution) -> String
    let onSelect: (BillOccurrence) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if occurrences.isEmpty {
                EmptyStateView(
                    systemImage: "calendar.badge.plus",
                    title: "Nothing in this period",
                    message: "Bills you add show up on the calendar and in this agenda.",
                    actionTitle: "Add a bill",
                    action: onAdd
                )
            } else {
                rows
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Agenda")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if !occurrences.isEmpty {
                Text(summary)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(occurrences) { occurrence in
                Button {
                    onSelect(occurrence)
                } label: {
                    RecurringAgendaRowView(
                        occurrence: occurrence,
                        attributionName: displayName(occurrence.attributedTo),
                        attributionColorHex: badgeColorHex(occurrence.attributedTo)
                    )
                }
                .buttonStyle(.plain)
                if occurrence.id != occurrences.last?.id {
                    Divider().overlay(Theme.separator)
                }
            }
        }
    }

    /// "5 bills · $2,530.99 expected"
    private var summary: String {
        let total = occurrences.reduce(0) { $0 + $1.amountMinor }
        let count = occurrences.count
        return "\(count) bill\(count == 1 ? "" : "s") · \(DemoDayText.currency(total))"
    }
}

/// One agenda row. Paid rows show a green check state; paused rows dim and
/// say so in text (never color alone).
private struct RecurringAgendaRowView: View {
    let occurrence: BillOccurrence
    let attributionName: String
    let attributionColorHex: String

    var body: some View {
        HStack(alignment: .center, spacing: Theme.cardSpacing) {
            dateBlock
            details
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .opacity(occurrence.state == .paused ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
        .accessibilityHint(Text("Opens the bill for editing"))
    }

    // MARK: - Pieces

    private var dateBlock: some View {
        VStack(spacing: 0) {
            Text(DemoDayText.shortDate(occurrence.date))
                .font(.caption.weight(.semibold))
                .foregroundStyle(occurrence.state == .paid ? Theme.textTertiary : Theme.primaryDark)
        }
        .frame(minWidth: 52)
        .padding(.vertical, 6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(occurrence.merchant)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text(DemoAccountsCatalog.displayName(forId: occurrence.accountId))
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            statusLine
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch occurrence.state {
        case .paid:
            Label("Paid", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.success)
        case .paused:
            Label("Paused", systemImage: "pause.circle")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
        case .upcoming:
            EmptyView()
        }
    }

    private var trailing: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(DemoDayText.currency(occurrence.amountMinor))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            PartnerBadge(name: attributionName, colorHex: attributionColorHex)
        }
    }

    private var accessibilitySummary: String {
        var parts = [
            occurrence.merchant,
            DemoDayText.currency(occurrence.amountMinor),
            "due \(DemoDayText.weekdayShortDate(occurrence.date))",
            "attributed to \(attributionName)",
            DemoAccountsCatalog.displayName(forId: occurrence.accountId)
        ]
        switch occurrence.state {
        case .paid: parts.append("paid")
        case .paused: parts.append("paused")
        case .upcoming: break
        }
        return parts.joined(separator: ", ")
    }
}
