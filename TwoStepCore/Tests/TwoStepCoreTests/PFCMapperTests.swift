import Testing
@testable import TwoStepCore

@Suite("PFCMapper — Plaid category mapping and confidence threshold")
struct PFCMapperTests {
    @Test("All 16 PFC primaries have a seeded default category")
    func allPrimariesMapped() {
        let primaries = [
            "INCOME", "TRANSFER_IN", "TRANSFER_OUT", "LOAN_PAYMENTS",
            "BANK_FEES", "ENTERTAINMENT", "FOOD_AND_DRINK", "GENERAL_MERCHANDISE",
            "HOME_IMPROVEMENT", "MEDICAL", "PERSONAL_CARE", "GENERAL_SERVICES",
            "GOVERNMENT_AND_NON_PROFIT", "TRANSPORTATION", "TRAVEL", "RENT_AND_UTILITIES"
        ]
        #expect(PFCMapper.defaultCategories.count == 16)
        for primary in primaries {
            #expect(PFCMapper.defaultCategory(forPrimary: primary) != nil, "\(primary) unmapped")
        }
    }

    @Test("Emojis are unique — they are each category's primary identity")
    func emojiUniqueness() {
        let emojis = PFCMapper.defaultCategories.values.map(\.emoji)
        #expect(Set(emojis).count == emojis.count)
    }

    @Test("Income, transfers, and loan payments default to exclude-from-budget")
    func excludeDefaults() {
        for primary in ["INCOME", "TRANSFER_IN", "TRANSFER_OUT", "LOAN_PAYMENTS"] {
            #expect(PFCMapper.defaultCategory(forPrimary: primary)?.excludeFromBudgetByDefault == true)
        }
        for primary in ["FOOD_AND_DRINK", "TRAVEL", "BANK_FEES", "RENT_AND_UTILITIES"] {
            #expect(PFCMapper.defaultCategory(forPrimary: primary)?.excludeFromBudgetByDefault == false)
        }
    }

    @Test("Unknown or missing primaries map to nothing (→ Uncategorized)")
    func unmappedPrimaries() {
        #expect(PFCMapper.defaultCategory(forPrimary: "UNKNOWN") == nil)
        #expect(PFCMapper.defaultCategory(forPrimary: "SOMETHING_NEW") == nil)
        #expect(PFCMapper.defaultCategory(forPrimary: nil) == nil)
    }

    @Test("Confidence threshold: LOW, VERY_LOW, UNKNOWN, missing, garbage → needs review")
    func needsReviewTable() {
        #expect(PFCMapper.needsReview(confidence: "LOW"))
        #expect(PFCMapper.needsReview(confidence: "VERY_LOW"))
        #expect(PFCMapper.needsReview(confidence: "UNKNOWN"))
        #expect(PFCMapper.needsReview(confidence: nil))
        #expect(PFCMapper.needsReview(confidence: "NOT_A_LEVEL"))
        #expect(!PFCMapper.needsReview(confidence: "MEDIUM"))
        #expect(!PFCMapper.needsReview(confidence: "HIGH"))
        #expect(!PFCMapper.needsReview(confidence: "VERY_HIGH"))
    }

    @Test("Internal-transfer detection covers exactly the money-movement primaries")
    func internalTransfers() {
        #expect(PFCMapper.isInternalTransfer(primary: "TRANSFER_IN"))
        #expect(PFCMapper.isInternalTransfer(primary: "TRANSFER_OUT"))
        #expect(PFCMapper.isInternalTransfer(primary: "LOAN_PAYMENTS"))
        #expect(!PFCMapper.isInternalTransfer(primary: "INCOME"))
        #expect(!PFCMapper.isInternalTransfer(primary: "FOOD_AND_DRINK"))
        #expect(!PFCMapper.isInternalTransfer(primary: nil))
    }
}
