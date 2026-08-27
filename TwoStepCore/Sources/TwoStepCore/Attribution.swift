import Foundation

/// Who a transaction, recurring item, or split belongs to: one partner's uid,
/// or the household jointly.
///
/// Wire format is a single string — `"joint"` or the member uid — matching the
/// Firestore `attributedTo: uid | "joint"` field exactly.
///
/// Invariants:
/// - Attribution is neutral bookkeeping (PRD §2.2): this type carries no
///   ordering, scoring, or comparison semantics beyond equality.
/// - Joint-attributed amounts are never split between partners downstream;
///   digest math reports A / B / Joint as three separate figures.
/// - A uid equal to the literal `"joint"` cannot exist (Firebase uids are
///   alphanumeric and 28 chars), so the encoding is unambiguous.
public enum Attribution: Hashable, Sendable {
    case joint
    case member(String)

    /// The exact string stored in Firestore.
    public var rawValue: String {
        switch self {
        case .joint: "joint"
        case .member(let uid): uid
        }
    }

    public init(rawValue: String) {
        self = rawValue == "joint" ? .joint : .member(rawValue)
    }
}

extension Attribution: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
