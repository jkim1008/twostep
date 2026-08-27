import Foundation

/// One entry in the household activity feed (`/events`) — the notification
/// mechanism of v1: no push, just this feed plus an unread badge.
///
/// Invariants (PRD §6.2):
/// - Events are written by Cloud Functions only; clients are read-only.
/// - `payload` is a short human-readable summary string, already neutralized —
///   it never contains partner-vs-partner comparisons.
/// - The feed is append-only household history.
public struct HouseholdEvent: Hashable, Codable, Sendable, Identifiable {
    public enum EventType: String, Codable, Sendable {
        case memberJoined
        case memberLeft
        case expenseAdded
        case expenseEdited
        case budgetChanged
        case accountLinked
        case accountUnlinked
        case projectCreated
        case contributionAdded
    }

    public let id: String
    public let type: EventType
    public let actorUid: String
    public let timestamp: Date
    /// Short display summary, e.g. "Linked Chase ••1234".
    public let payload: String

    public init(id: String, type: EventType, actorUid: String, timestamp: Date, payload: String) {
        self.id = id
        self.type = type
        self.actorUid = actorUid
        self.timestamp = timestamp
        self.payload = payload
    }
}
