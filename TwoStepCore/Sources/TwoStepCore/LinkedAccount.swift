import Foundation

/// A financial account visible to the household — a Plaid-linked bank account
/// or the built-in Cash account seeded at household creation.
///
/// Invariants (PRD §4.3, §6.2):
/// - `ownerUid == nil` means the account is joint; imported transactions on it
///   default to `Attribution.joint`.
/// - The Cash account (`type == .cash`) is the default target for manual
///   entries and is exempt from duplicate matching in both directions.
/// - `isHidden` removes the account (and its transactions) from default
///   surfaces for both partners identically — never one-sided.
public struct LinkedAccount: Hashable, Codable, Sendable, Identifiable {
    public enum AccountType: String, Codable, Sendable {
        case checking
        case savings
        case creditCard
        case cash
        case other
    }

    public let id: String
    /// nil = joint account.
    public var ownerUid: String?
    public var institutionName: String
    /// Last-four (or similar) account number mask; never a full number.
    public var mask: String
    public var type: AccountType
    public var isHidden: Bool

    public init(
        id: String,
        ownerUid: String? = nil,
        institutionName: String,
        mask: String,
        type: AccountType,
        isHidden: Bool = false
    ) {
        self.id = id
        self.ownerUid = ownerUid
        self.institutionName = institutionName
        self.mask = mask
        self.type = type
        self.isHidden = isHidden
    }

    /// Default attribution for transactions imported into this account.
    public var defaultAttribution: Attribution {
        if let ownerUid { .member(ownerUid) } else { .joint }
    }
}
