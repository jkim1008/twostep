import SwiftUI
import TwoStepCore

/// The calendar hero's grid (PRD §4.6): a Monday-first month grid (or single
/// week row) whose cells carry payment chips on due dates. Day scope renders
/// one full-width card with every chip spelled out.
struct RecurringCalendarGridView: View {
    let scope: RecurringCalendarScope
    let anchor: CalendarDay
    let today: CalendarDay
    /// Occurrences of the visible period, grouped by `"YYYY-MM-DD"`.
    let occurrencesByDate: [String: [BillOccurrence]]
    let badgeColorHex: (Attribution) -> String
    let onSelectDay: (CalendarDay) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        switch scope {
        case .month:
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(monthCells.indices, id: \.self) { index in
                    cell(for: monthCells[index])
                }
            }
        case .week:
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<7, id: \.self) { offset in
                    cell(for: weekStart.adding(days: offset))
                }
            }
        case .day:
            RecurringDayCardView(
                day: anchor,
                occurrences: occurrencesByDate[anchor.dateString] ?? [],
                badgeColorHex: badgeColorHex
            )
        }
    }

    // MARK: - Pieces

    private var monthCells: [CalendarDay?] {
        RecurringCalendarModel.monthGridWeeks(anchor: anchor).flatMap(\.self)
    }

    private var weekStart: CalendarDay {
        RecurringCalendarModel.period(for: .week, anchor: anchor).start
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(DemoDayText.mondayFirstWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func cell(for day: CalendarDay?) -> some View {
        if let day {
            RecurringDayCellView(
                day: day,
                isToday: day == today,
                occurrences: occurrencesByDate[day.dateString] ?? [],
                badgeColorHex: badgeColorHex
            ) {
                onSelectDay(day)
            }
        } else {
            Color.clear
                .frame(minHeight: 56)
                .accessibilityHidden(true)
        }
    }
}

/// One tappable day cell: the day number plus up to two payment chips and an
/// overflow count (PRD §4.6 — stacked/overflow chip for busy days).
private struct RecurringDayCellView: View {
    let day: CalendarDay
    let isToday: Bool
    let occurrences: [BillOccurrence]
    let badgeColorHex: (Attribution) -> String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                dayNumber
                chips
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .top)
            .padding(.vertical, 2)
            .background(cellBackground)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
        .accessibilityAddTraits(isToday ? [.isSelected] : [])
    }

    private var dayNumber: some View {
        Text("\(day.day)")
            .font(.footnote.weight(isToday ? .bold : .regular))
            .monospacedDigit()
            .foregroundStyle(isToday ? Theme.primaryDark : Theme.textPrimary)
            .frame(minWidth: 22, minHeight: 22)
            .background(isToday ? Theme.primaryTint : .clear, in: Circle())
    }

    @ViewBuilder
    private var chips: some View {
        ForEach(occurrences.prefix(2)) { occurrence in
            BillChipView(
                occurrence: occurrence,
                colorHex: badgeColorHex(occurrence.attributedTo)
            )
        }
        if occurrences.count > 2 {
            Text("+\(occurrences.count - 2)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private var cellBackground: some View {
        if occurrences.isEmpty {
            Color.clear
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.surface)
        }
    }

    private var accessibilitySummary: String {
        var parts = [DemoDayText.weekdayShortDate(day.dateString)]
        if isToday { parts.append("today") }
        if occurrences.isEmpty {
            parts.append("no bills")
        } else {
            let names = occurrences
                .map { "\($0.merchant) \(DemoDayText.currency($0.amountMinor))" }
                .joined(separator: ", ")
            parts.append("\(occurrences.count) bill\(occurrences.count == 1 ? "" : "s"): \(names)")
        }
        return parts.joined(separator: ", ")
    }
}

/// Day-scope hero: the selected date with each occurrence as a full-width
/// chip row (merchant + amount + attribution color).
private struct RecurringDayCardView: View {
    let day: CalendarDay
    let occurrences: [BillOccurrence]
    let badgeColorHex: (Attribution) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.cardSpacing) {
            Text(DemoDayText.weekdayShortDate(day.dateString))
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            if occurrences.isEmpty {
                Text("Nothing due on this day.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(occurrences) { occurrence in
                    HStack(spacing: 8) {
                        BillChipView(
                            occurrence: occurrence,
                            colorHex: badgeColorHex(occurrence.attributedTo)
                        )
                        Text(occurrence.merchant)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(DemoDayText.currency(occurrence.amountMinor))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}

/// The payment chip (PRD §4.6): attribution color + compact amount, with a
/// paid checkmark once the imported charge has linked, dimmed when paused.
/// Color never stands alone — the amount text and agenda carry the meaning.
struct BillChipView: View {
    let occurrence: BillOccurrence
    let colorHex: String

    var body: some View {
        HStack(spacing: 3) {
            if occurrence.state == .paid {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.success)
            } else {
                Circle()
                    .fill(Color(hexString: colorHex))
                    .frame(width: 5, height: 5)
            }
            Text(DemoDayText.compactCurrency(occurrence.amountMinor))
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            Color(hexString: colorHex).opacity(0.16),
            in: RoundedRectangle(cornerRadius: 5)
        )
        .opacity(occurrence.state == .paused ? 0.45 : 1)
        .accessibilityHidden(true)
    }
}
