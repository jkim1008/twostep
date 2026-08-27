import Foundation
import TwoStepCore

/// Display catalog for the demo household's accounts (fictional institutions,
/// masked numbers only). The Plaid-backed `LinkedAccount` repository replaces
/// this once bank linking ships; until then the Recurring agenda and the
/// Playbook's linked-banks section both read from here.
enum DemoAccountsCatalog {
    struct DemoAccount: Identifiable {
        let id: String
        let name: String
        /// Last-four style mask; nil for the built-in Cash account.
        let mask: String?
        let ownedBy: Attribution
        let isCash: Bool

        /// "Meridian Bank Checking ••4821" / "Cash"
        var displayName: String {
            guard let mask else { return name }
            return "\(name) ••\(mask)"
        }
    }

    static let accounts: [DemoAccount] = [
        DemoAccount(
            id: DemoSeed.cashAccountId,
            name: "Cash",
            mask: nil,
            ownedBy: .joint,
            isCash: true
        ),
        DemoAccount(
            id: DemoSeed.mayaCheckingId,
            name: "Meridian Bank Checking",
            mask: "4821",
            ownedBy: DemoSeed.maya,
            isCash: false
        ),
        DemoAccount(
            id: DemoSeed.samCardId,
            name: "Cascade Credit Union Card",
            mask: "7310",
            ownedBy: DemoSeed.sam,
            isCash: false
        ),
        DemoAccount(
            id: DemoSeed.jointCheckingId,
            name: "Meridian Bank Joint Checking",
            mask: "0164",
            ownedBy: .joint,
            isCash: false
        )
    ]

    static func account(withId id: String?) -> DemoAccount? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }
    }

    /// Short label for agenda rows and pickers; nil id reads as untracked.
    static func displayName(forId id: String?) -> String {
        account(withId: id)?.displayName ?? "No account"
    }
}
