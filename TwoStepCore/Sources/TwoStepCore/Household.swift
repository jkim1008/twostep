import Foundation

/// The household — the root entity everything financial belongs to.
///
/// Invariants (PRD §6.2, §6.4):
/// - Exactly two authorized members at most; `memberUids` is the security-rules
///   gate and is only ever mutated by Cloud Functions, never by clients.
/// - `ownerUid` is the founding member and is immutable client-side.
/// - `weeklySync` is the single source of truth both devices schedule the
///   Weekly Sync local notification from.
public struct Household: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var currencyCode: String
    public var memberUids: [String]
    public var ownerUid: String
    public var weeklySync: WeeklySyncSchedule

    public init(
        id: String,
        name: String,
        currencyCode: String = "USD",
        memberUids: [String],
        ownerUid: String,
        weeklySync: WeeklySyncSchedule = .default
    ) {
        self.id = id
        self.name = name
        self.currencyCode = currencyCode
        self.memberUids = memberUids
        self.ownerUid = ownerUid
        self.weeklySync = weeklySync
    }
}

/// When the Weekly Sync digest is delivered, stored on the household doc so
/// both devices schedule the same local notification.
///
/// Invariants:
/// - `weekday` is 1...7 with 1 = Monday, 7 = Sunday (matching `WeekKey`'s
///   Monday-first weeks). Default is Sunday 7:00 PM (PRD §4.7.1).
public struct WeeklySyncSchedule: Hashable, Codable, Sendable {
    public var weekday: Int
    public var hour: Int
    public var minute: Int

    public init(weekday: Int, hour: Int, minute: Int) {
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
    }

    public static let `default` = WeeklySyncSchedule(weekday: 7, hour: 19, minute: 0)
}

/// A member document under `/households/{id}/members/{uid}`.
///
/// Invariants (PRD §6.3):
/// - Member docs are never hard-deleted; a departing partner becomes
///   `status: .left` so `attributedTo` history resolves to the snapshotted
///   `displayName` forever.
/// - `displayName` is a snapshot, not a live reference to the user profile.
/// - `colorHex` drives the partner attribution badge color.
public struct HouseholdMember: Hashable, Codable, Sendable, Identifiable {
    public enum Role: String, Codable, Sendable {
        case owner
        case partner
    }

    public enum Status: String, Codable, Sendable {
        case active
        case left
    }

    /// The member's Firebase uid.
    public let id: String
    public var role: Role
    public var status: Status
    public var displayName: String
    public var colorHex: String

    public init(
        id: String,
        role: Role,
        status: Status = .active,
        displayName: String,
        colorHex: String
    ) {
        self.id = id
        self.role = role
        self.status = status
        self.displayName = displayName
        self.colorHex = colorHex
    }
}
