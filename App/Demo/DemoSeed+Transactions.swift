import Foundation
import TwoStepCore

// ~60 fictional transactions across July–August 2026 for the demo household.
// Mix of Plaid imports and manual entries; attributions across Maya, Sam, and
// Joint; two items flagged for discussion; two still pending. Amounts are
// integer minor units, written as dollars_cents for readability.

extension DemoSeed {
    static var maya: Attribution { .member(mayaUid) }
    static var sam: Attribution { .member(samUid) }

    static func makeTransactions() -> [Transaction] {
        julyFirstHalf + julySecondHalf + augustFirstHalf + augustSecondHalf
    }

    private static var julyFirstHalf: [Transaction] {
        [
            autoLogged(cash(1, "2026-07-01", "Maple Grove Apartments", 2_200_00, "housing", .joint), item: "rec-rent"),
            spend(2, "2026-07-02", "Trader Joe's", 84_37, "groceries", maya, mayaCheckingId),
            linked(spend(3, "2026-07-03", "Netflix", 17_99, "subscriptions", sam, samCardId), item: "rec-netflix"),
            spend(4, "2026-07-05", "Shell", 46_20, "transport", sam, samCardId),
            spend(5, "2026-07-05", "Sunrise Diner", 38_75, "dining", .joint, jointCheckingId),
            spend(6, "2026-07-07", "Whole Foods Market", 112_60, "groceries", .joint, jointCheckingId),
            linked(spend(7, "2026-07-08", "City Power & Water", 132_48, "housing", .joint, jointCheckingId), item: "rec-utilities"),
            spend(8, "2026-07-09", "AMC Theatres", 32_00, "entertainment", maya, mayaCheckingId),
            paycheck(9, "2026-07-10", "Northwind Design Payroll", 3_120_00, maya, mayaCheckingId),
            spend(10, "2026-07-11", "CVS Pharmacy", 24_99, "health", sam, samCardId),
            spend(11, "2026-07-12", "Uber", 18_40, "transport", maya, mayaCheckingId),
            spend(12, "2026-07-13", "Home Depot", 76_13, "shopping", .joint, jointCheckingId),
            linked(spend(13, "2026-07-14", "Peak Fitness", 45_00, "health", maya, mayaCheckingId), item: "rec-gym"),
            paycheck(14, "2026-07-15", "Harbor Analytics Payroll", 2_980_00, sam, jointCheckingId)
        ]
    }

    private static var julySecondHalf: [Transaction] {
        [
            spend(15, "2026-07-16", "Safeway", 67_22, "groceries", sam, samCardId),
            spend(16, "2026-07-18", "Olive & Thyme", 92_80, "dining", .joint, jointCheckingId),
            spend(17, "2026-07-19", "Chevron", 51_15, "transport", .joint, jointCheckingId),
            spend(18, "2026-07-20", "Spotify", 11_99, "subscriptions", maya, mayaCheckingId),
            spend(19, "2026-07-21", "Target", 134_52, "shopping", maya, mayaCheckingId),
            linked(spend(20, "2026-07-21", "Geico Insurance", 128_00, "transport", sam, samCardId), item: "rec-car-insurance"),
            transfer(21, "2026-07-23", "Card Payment — Meridian Bank", 850_00, .joint, jointCheckingId),
            spend(22, "2026-07-24", "Trader Joe's", 91_05, "groceries", maya, mayaCheckingId),
            spend(23, "2026-07-25", "Dave's Hot Chicken", 27_35, "dining", sam, samCardId),
            spend(24, "2026-07-26", "Marquee Movie Rental", 5_99, "entertainment", .joint, samCardId),
            spend(25, "2026-07-27", "Walgreens", 15_47, "health", maya, mayaCheckingId),
            spend(26, "2026-07-28", "Amazon", 58_90, "shopping", sam, samCardId),
            spend(27, "2026-07-29", "Lyft", 22_75, "transport", sam, samCardId),
            paycheck(28, "2026-07-31", "Northwind Design Payroll", 3_120_00, maya, mayaCheckingId),
            cash(29, "2026-07-31", "Riverside Farmers Market", 34_00, "groceries", maya)
        ]
    }

    private static var augustFirstHalf: [Transaction] {
        [
            autoLogged(cash(30, "2026-08-01", "Maple Grove Apartments", 2_200_00, "housing", .joint), item: "rec-rent"),
            spend(31, "2026-08-02", "Trader Joe's", 88_14, "groceries", maya, mayaCheckingId),
            linked(spend(32, "2026-08-03", "Netflix", 17_99, "subscriptions", sam, samCardId), item: "rec-netflix"),
            spend(33, "2026-08-04", "Shell", 48_60, "transport", sam, samCardId),
            transfer(34, "2026-08-05", "Card Payment — Meridian Bank", 920_00, .joint, jointCheckingId),
            spend(35, "2026-08-05", "Sunrise Diner", 42_10, "dining", .joint, jointCheckingId),
            linked(spend(36, "2026-08-07", "City Power & Water", 147_92, "housing", .joint, jointCheckingId), item: "rec-utilities"),
            spend(37, "2026-08-08", "Whole Foods Market", 123_75, "groceries", .joint, jointCheckingId),
            flagged(
                spend(38, "2026-08-09", "Rivergate Amphitheater", 156_00, "entertainment", .joint, jointCheckingId),
                by: samUid,
                note: "Is this the show with Jess and Omar? Want to make sure we're all going the same night."
            ),
            paycheck(39, "2026-08-10", "Northwind Design Payroll", 3_120_00, maya, mayaCheckingId),
            spend(40, "2026-08-11", "CVS Pharmacy", 31_20, "health", sam, samCardId),
            spend(41, "2026-08-12", "Uber", 16_85, "transport", maya, mayaCheckingId),
            flagged(
                spend(42, "2026-08-13", "TechVault Online", 249_99, "shopping", sam, samCardId),
                by: mayaUid,
                note: "Which order was this one? Just matching it to the boxes that arrived."
            ),
            linked(spend(43, "2026-08-14", "Peak Fitness", 45_00, "health", maya, mayaCheckingId), item: "rec-gym"),
            paycheck(44, "2026-08-15", "Harbor Analytics Payroll", 2_980_00, sam, jointCheckingId)
        ]
    }

    private static var augustSecondHalf: [Transaction] {
        [
            spend(45, "2026-08-15", "Safeway", 72_48, "groceries", sam, samCardId),
            spend(46, "2026-08-16", "The Book Nook", 28_50, "shopping", maya, mayaCheckingId),
            spend(47, "2026-08-17", "Olive & Thyme", 68_40, "dining", .joint, jointCheckingId),
            spend(48, "2026-08-18", "Chevron", 53_30, "transport", .joint, jointCheckingId),
            spend(49, "2026-08-19", "Willow Home Goods", 44_99, "shopping", .joint, jointCheckingId),
            spend(50, "2026-08-20", "Spotify", 11_99, "subscriptions", maya, mayaCheckingId),
            linked(spend(51, "2026-08-21", "Geico Insurance", 128_00, "transport", sam, samCardId), item: "rec-car-insurance"),
            spend(52, "2026-08-22", "Trader Joe's", 95_63, "groceries", maya, mayaCheckingId),
            cash(53, "2026-08-22", "El Camion Taco Truck", 18_00, "dining", sam),
            spend(54, "2026-08-23", "Walgreens", 12_99, "health", maya, mayaCheckingId),
            spend(55, "2026-08-24", "Grand Marquee Cinema", 36_00, "entertainment", .joint, jointCheckingId),
            refund(56, "2026-08-24", "Amazon Refund", 29_99, "shopping", sam, samCardId),
            pending(spend(57, "2026-08-25", "Whole Foods Market", 108_31, "groceries", .joint, jointCheckingId)),
            cash(58, "2026-08-26", "Riverside Farmers Market", 27_50, "groceries", sam),
            spend(59, "2026-08-26", "Pet Corner", 21_75, "shopping", .joint, jointCheckingId),
            pending(spend(60, "2026-08-26", "Sunrise Diner", 24_60, "dining", maya, mayaCheckingId)),
            cash(61, "2026-08-27", "Fern & Fig Coffee", 9_40, "dining", maya)
        ]
    }

    // MARK: Builders

    /// A posted Plaid-imported expense.
    private static func spend(
        _ number: Int, _ date: String, _ merchant: String, _ cents: Int,
        _ categoryId: String, _ attribution: Attribution = .joint,
        _ accountId: String = DemoSeed.jointCheckingId
    ) -> Transaction {
        Transaction(
            id: transactionId(number), source: .plaid, accountId: accountId,
            amountMinor: cents, direction: .expense, date: date,
            merchantName: merchant, categoryId: categoryId, attributedTo: attribution
        )
    }

    /// A manual cash entry, attributed to (and entered by) the given partner —
    /// or entered by Maya for joint entries.
    private static func cash(
        _ number: Int, _ date: String, _ merchant: String, _ cents: Int,
        _ categoryId: String, _ attribution: Attribution = .joint
    ) -> Transaction {
        let author: String = if case .member(let uid) = attribution { uid } else { mayaUid }
        return Transaction(
            id: transactionId(number), source: .manual, accountId: cashAccountId,
            amountMinor: cents, direction: .expense, date: date,
            merchantName: merchant, categoryId: categoryId,
            attributedTo: attribution, enteredByUid: author
        )
    }

    /// Ordinary income — excluded from budget math (PRD §4.3).
    private static func paycheck(
        _ number: Int, _ date: String, _ merchant: String, _ cents: Int,
        _ attribution: Attribution, _ accountId: String = DemoSeed.jointCheckingId
    ) -> Transaction {
        Transaction(
            id: transactionId(number), source: .plaid, accountId: accountId,
            amountMinor: cents, direction: .income, date: date,
            merchantName: merchant, categoryId: "income",
            attributedTo: attribution, excludeFromBudget: true
        )
    }

    /// An internal transfer (credit-card payment) — shown in the feed as
    /// internal, never counted toward spend (PRD §4.3, R17).
    private static func transfer(
        _ number: Int, _ date: String, _ merchant: String, _ cents: Int,
        _ attribution: Attribution, _ accountId: String = DemoSeed.jointCheckingId
    ) -> Transaction {
        Transaction(
            id: transactionId(number), source: .plaid, accountId: accountId,
            amountMinor: cents, direction: .expense, date: date,
            merchantName: merchant, categoryId: "transfers",
            attributedTo: attribution, excludeFromBudget: true
        )
    }

    /// A refund into a spending category — nets against that category's spend.
    private static func refund(
        _ number: Int, _ date: String, _ merchant: String, _ cents: Int,
        _ categoryId: String, _ attribution: Attribution = .joint,
        _ accountId: String = DemoSeed.jointCheckingId
    ) -> Transaction {
        Transaction(
            id: transactionId(number), source: .plaid, accountId: accountId,
            amountMinor: cents, direction: .income, date: date,
            merchantName: merchant, categoryId: categoryId, attributedTo: attribution
        )
    }

    // MARK: Modifiers

    private static func pending(_ transaction: Transaction) -> Transaction {
        var copy = transaction
        copy.status = .pending
        return copy
    }

    private static func flagged(_ transaction: Transaction, by uid: String, note: String) -> Transaction {
        var copy = transaction
        copy.discussFlaggedByUid = uid
        copy.discussNote = note
        return copy
    }

    private static func linked(_ transaction: Transaction, item recurringItemId: String) -> Transaction {
        var copy = transaction
        copy.recurringItemId = recurringItemId
        return copy
    }

    private static func autoLogged(_ transaction: Transaction, item recurringItemId: String) -> Transaction {
        linked(transaction, item: recurringItemId)
    }

    private static func transactionId(_ number: Int) -> String {
        String(format: "demo-txn-%03d", number)
    }
}
