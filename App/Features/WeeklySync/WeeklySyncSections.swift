import SwiftUI
import TwoStepCore

// MARK: - Top categories

/// Top categories vs. budget pace (PRD §4.7.1): household figures headline
/// each row; per-partner amounts appear ONLY inside the category drill-down,
/// always alongside the Joint share — never as ranked totals. That shape is
/// the §2.2 no-scoreboard rule made structural.
struct WeeklySyncCategoriesSection: View {
    let digest: WeeklyDigest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WeeklySyncSectionHeader(title: "Top categories")
            if digest.topCategories.isEmpty {
                Text("No spending recorded this week.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(digest.topCategories, id: \.categoryId) { row in
                        WeeklySyncCategoryRowView(row: row)
                        if row.categoryId != digest.topCategories.last?.categoryId {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
            }
        }
    }
}

private struct WeeklySyncCategoryRowView: View {
    @Environment(AppRepositories.self) private var repositories
    let row: CategoryDigest
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DisclosureGroup(isExpanded: $isExpanded) {
                attributionRows
                    .padding(.top, 6)
            } label: {
                headline
            }
            .tint(Theme.textTertiary)
            paceLine
        }
        .padding(.vertical, 10)
    }

    // MARK: - Pieces

    private var headline: some View {
        HStack(spacing: 8) {
            Text(categoryEmoji)
                .accessibilityHidden(true)
            Text(categoryName)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(DemoDayText.currency(max(0, row.weekSpentMinor)))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .contentShape(Rectangle())
        .frame(minHeight: 34)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(headlineSummary))
        .accessibilityHint(Text("Expands who contributed within this category"))
    }

    /// Household month-to-date vs. pace — status is text + color, never
    /// color alone (DESIGN.md §7).
    @ViewBuilder
    private var paceLine: some View {
        if let pace = row.paceMinor {
            let monthSpent = max(0, row.monthSpentMinor)
            let onPace = monthSpent <= pace
            HStack(spacing: 5) {
                Image(systemName: onPace ? "checkmark.circle" : "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(onPace ? Theme.success : Theme.warning)
                    .accessibilityHidden(true)
                Text(paceText(monthSpent: monthSpent, pace: pace, onPace: onPace))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
        } else {
            Text("Month so far: \(DemoDayText.currency(max(0, row.monthSpentMinor))) · no allocation")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Theme.textTertiary)
        }
    }

    /// A / B / Joint — three separate figures; Joint is never split
    /// (`DigestBuilder` invariant, PRD §4.7.1).
    private var attributionRows: some View {
        VStack(spacing: 6) {
            ForEach(attributionEntries, id: \.key) { entry in
                HStack {
                    PartnerBadge(name: entry.name, colorHex: entry.colorHex)
                    Spacer()
                    Text(DemoDayText.currency(entry.amountMinor))
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(entry.name): \(DemoDayText.currency(entry.amountMinor))"))
            }
        }
    }

    // MARK: - Derived

    private var category: TransactionCategory? {
        repositories.budgets.category(withId: row.categoryId)
    }

    private var categoryName: String { category?.name ?? "Uncategorized" }
    private var categoryEmoji: String { category?.emoji ?? "❓" }

    private struct AttributionEntry {
        let key: String
        let name: String
        let colorHex: String
        let amountMinor: Int
    }

    /// Both partners and Joint, in stable member order — all three always
    /// shown so no figure ever stands alone.
    private var attributionEntries: [AttributionEntry] {
        let households = repositories.households
        var attributions = households.members.map { Attribution.member($0.id) }
        attributions.append(.joint)
        return attributions.map { attribution in
            AttributionEntry(
                key: attribution.rawValue,
                name: households.displayName(for: attribution),
                colorHex: households.badgeColorHex(for: attribution),
                amountMinor: row.spentByAttribution[attribution.rawValue] ?? 0
            )
        }
    }

    private func paceText(monthSpent: Int, pace: Int, onPace: Bool) -> String {
        let spent = DemoDayText.currency(monthSpent)
        let paceAmount = DemoDayText.currency(pace)
        return onPace
            ? "Month so far: \(spent) — on pace (\(paceAmount))"
            : "Month so far: \(spent) — ahead of pace (\(paceAmount))"
    }

    private var headlineSummary: String {
        "\(categoryName), \(DemoDayText.currency(max(0, row.weekSpentMinor))) this week"
    }
}

// MARK: - Upcoming bills

/// The bills landing in the two weeks after the covered week, straight from
/// the digest (which delegates to `RecurrenceEngine`).
struct WeeklySyncBillsSection: View {
    @Environment(AppRepositories.self) private var repositories
    let bills: [UpcomingBill]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WeeklySyncSectionHeader(title: "Bills ahead")
            if bills.isEmpty {
                Text("Nothing due in the next two weeks.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(bills, id: \.self) { bill in
                        billRow(bill)
                        if bill != bills.last {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
            }
        }
    }

    private func billRow(_ bill: UpcomingBill) -> some View {
        let name = repositories.households.displayName(for: bill.attributedTo)
        let colorHex = repositories.households.badgeColorHex(for: bill.attributedTo)
        return HStack(spacing: Theme.cardSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.merchant)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(DemoDayText.weekdayShortDate(bill.dueDate))
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(DemoDayText.currency(bill.amountMinor))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            PartnerBadge(name: name, colorHex: colorHex)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text("\(bill.merchant), \(DemoDayText.currency(bill.amountMinor)), due \(DemoDayText.weekdayShortDate(bill.dueDate)), \(name)")
        )
    }
}

// MARK: - To discuss

/// The "Let's discuss" queue (PRD §4.7.2): a flag, one note, a one-tap
/// resolve — deliberately not a chat. Resolving is available to either
/// partner and simply clears the item from the queue.
struct WeeklySyncDiscussSection: View {
    @Environment(AppRepositories.self) private var repositories

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WeeklySyncSectionHeader(title: "To discuss")
            if flaggedTransactions.isEmpty {
                Text("Nothing waiting — enjoy the quiet week.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(spacing: Theme.cardSpacing) {
                    ForEach(flaggedTransactions) { transaction in
                        discussCard(transaction)
                    }
                }
            }
        }
    }

    private func discussCard(_ transaction: TwoStepCore.Transaction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(transaction.merchantName ?? "Transaction")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(DemoDayText.currency(transaction.amountMinor))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }
            if let note = transaction.discussNote {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if let flaggerUid = transaction.discussFlaggedByUid {
                    flaggedByBadge(uid: flaggerUid)
                }
                Spacer()
                Button("Resolve") {
                    resolve(transaction)
                }
                .font(.subheadline.weight(.medium))
                .buttonStyle(.bordered)
                .tint(Theme.primary)
                .accessibilityLabel(
                    Text("Resolve \(transaction.merchantName ?? "transaction") discussion")
                )
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    private func flaggedByBadge(uid: String) -> some View {
        let attribution = Attribution.member(uid)
        return HStack(spacing: 5) {
            Image(systemName: "flag")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .accessibilityHidden(true)
            PartnerBadge(
                name: repositories.households.displayName(for: attribution),
                colorHex: repositories.households.badgeColorHex(for: attribution)
            )
        }
    }

    // MARK: - Data

    private var flaggedTransactions: [TwoStepCore.Transaction] {
        repositories.transactions.transactions.filter {
            $0.discussFlaggedByUid != nil && $0.discussResolvedAt == nil
        }
    }

    /// One tap, either partner (PRD §4.7.2). Resolved items leave the queue
    /// but stay on the transaction record.
    private func resolve(_ transaction: TwoStepCore.Transaction) {
        var resolved = transaction
        resolved.discussResolvedAt = Date()
        repositories.transactions.update(resolved)
    }
}

// MARK: - Shared header

struct WeeklySyncSectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Theme.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
}
