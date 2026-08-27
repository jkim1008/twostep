import Testing
@testable import TwoStepCore

@Suite("DedupMatcher — manual/import duplicate decision table")
struct DedupMatcherTests {
    private let cashAccounts: Set<String> = ["acct-cash"]

    private func manual(
        accountId: String? = "acct-chase",
        amountMinor: Int = 4599,
        direction: Transaction.Direction = .expense,
        date: String = "2026-08-20",
        merchantName: String? = "Blue Bottle Coffee"
    ) -> Transaction {
        Transaction(
            id: "manual-1",
            source: .manual,
            accountId: accountId,
            amountMinor: amountMinor,
            direction: direction,
            date: date,
            merchantName: merchantName,
            attributedTo: .member("uid-a")
        )
    }

    private func imported(
        accountId: String? = "acct-chase",
        amountMinor: Int = 4599,
        direction: Transaction.Direction = .expense,
        date: String = "2026-08-21",
        merchantName: String? = "BLUEBOTTLE COFFEE OAKLAND",
        originalDescription: String? = nil
    ) -> Transaction {
        Transaction(
            id: "plaid-1",
            source: .plaid,
            accountId: accountId,
            amountMinor: amountMinor,
            direction: direction,
            date: date,
            merchantName: merchantName,
            originalDescription: originalDescription,
            attributedTo: .member("uid-a")
        )
    }

    private func verdict(_ manualTxn: Transaction, _ importedTxn: Transaction) -> DedupMatcher.Confidence {
        DedupMatcher.confidence(manual: manualTxn, imported: importedTxn, cashAccountIds: cashAccounts)
    }

    // MARK: - Decision table

    @Test("Exact amount + close date + same account + fuzzy merchant → high")
    func highConfidence() {
        #expect(verdict(manual(), imported()) == .high)
    }

    @Test("Cash accounts are exempt in both directions")
    func cashExemption() {
        #expect(verdict(manual(accountId: "acct-cash"), imported()) == .none)
        #expect(verdict(manual(), imported(accountId: "acct-cash")) == .none)
    }

    @Test("Any amount difference kills the match — even one cent")
    func amountMustBeExact() {
        #expect(verdict(manual(amountMinor: 4598), imported()) == .none)
        #expect(verdict(manual(amountMinor: 4600), imported()) == .none)
    }

    @Test("Directions must agree")
    func directionMustMatch() {
        #expect(verdict(manual(direction: .income), imported()) == .none)
    }

    @Test("Date window: ±3 days inclusive, 4 days is out")
    func dateWindow() {
        // Import on 2026-08-21.
        #expect(verdict(manual(date: "2026-08-18"), imported()) == .high)   // −3
        #expect(verdict(manual(date: "2026-08-24"), imported()) == .high)   // +3
        #expect(verdict(manual(date: "2026-08-17"), imported()) == .none)   // −4
        #expect(verdict(manual(date: "2026-08-25"), imported()) == .none)   // +4
        #expect(verdict(manual(date: "2026-08-21"), imported()) == .high)   // same day
    }

    @Test("Date window spans a month boundary")
    func dateWindowMonthBoundary() {
        #expect(verdict(manual(date: "2026-08-31"), imported(date: "2026-09-02")) == .high)
    }

    @Test("Malformed dates never match")
    func malformedDates() {
        #expect(verdict(manual(date: "bogus"), imported()) == .none)
        #expect(verdict(manual(), imported(date: "2026-02-30")) == .none)
    }

    @Test("A specified manual account must equal the import's account")
    func accountMismatch() {
        #expect(verdict(manual(accountId: "acct-amex"), imported(accountId: "acct-chase")) == .none)
    }

    @Test("An unspecified manual account matches any non-cash import")
    func unspecifiedAccountIsWildcard() {
        #expect(verdict(manual(accountId: nil), imported()) == .high)
        #expect(verdict(manual(accountId: nil, merchantName: nil), imported()) == .medium)
    }

    @Test("Base match without a merchant match → medium")
    func mediumWhenMerchantMissingOrDifferent() {
        #expect(verdict(manual(merchantName: nil), imported()) == .medium)
        #expect(verdict(manual(), imported(merchantName: nil)) == .medium)
        #expect(verdict(manual(merchantName: "Trader Joes"), imported(merchantName: "Shell Oil")) == .medium)
    }

    @Test("Import's originalDescription serves as merchant fallback")
    func originalDescriptionFallback() {
        let importedTxn = imported(merchantName: nil, originalDescription: "BLUE BOTTLE COFFEE 0042 OAK")
        #expect(verdict(manual(), importedTxn) == .high)
    }

    // MARK: - Merchant fuzzy matching

    @Test("Fuzzy merchant matching: containment and shared distinctive tokens")
    func fuzzyMatching() {
        #expect(DedupMatcher.merchantsFuzzyMatch("Starbucks #1234", "STARBUCKS"))
        #expect(DedupMatcher.merchantsFuzzyMatch("H Mart", "HMART SAN JOSE"))
        #expect(DedupMatcher.merchantsFuzzyMatch("Blue Bottle Coffee", "bluebottle coffee oakland"))
        #expect(DedupMatcher.merchantsFuzzyMatch("CVS", "CVS/PHARMACY #9921"))
        #expect(!DedupMatcher.merchantsFuzzyMatch("Trader Joes", "Shell Oil"))
        #expect(!DedupMatcher.merchantsFuzzyMatch(nil, "Starbucks"))
        #expect(!DedupMatcher.merchantsFuzzyMatch("Starbucks", nil))
        #expect(!DedupMatcher.merchantsFuzzyMatch("", "Starbucks"))
        #expect(!DedupMatcher.merchantsFuzzyMatch("###", "Starbucks"))
    }

    @Test("Short shared tokens alone don't fuzzy-match")
    func shortTokensInsufficient() {
        // Shared token "oil" (3 chars) and no containment.
        #expect(!DedupMatcher.merchantsFuzzyMatch("Oil Change Co", "Oil Painting Supply"))
    }
}
