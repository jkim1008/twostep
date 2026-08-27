import Foundation

/// A monetary amount stored as integer minor units (cents).
///
/// Integer minor units round-trip exactly across every platform and support
/// atomic increments in the backing store — critical with two concurrent
/// writers in one household. `Decimal` is exposed only at the display boundary.
public struct Money: Hashable, Codable, Sendable {
    public let amountMinor: Int
    public let currencyCode: String

    public init(amountMinor: Int, currencyCode: String = "USD") {
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
    }

    /// Converts a decimal amount (e.g. 12.34) to minor units, rounding
    /// half away from zero — the canonical rule at every ingest boundary.
    public init(decimal: Decimal, currencyCode: String = "USD") {
        var scaled = decimal * Decimal(100)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        self.amountMinor = NSDecimalNumber(decimal: rounded).intValue
        self.currencyCode = currencyCode
    }

    /// Decimal value for display math only — never stored.
    public var decimalValue: Decimal {
        Decimal(amountMinor) / Decimal(100)
    }

    public static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currencyCode == rhs.currencyCode, "Currency mismatch")
        return Money(amountMinor: lhs.amountMinor + rhs.amountMinor, currencyCode: lhs.currencyCode)
    }

    public static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currencyCode == rhs.currencyCode, "Currency mismatch")
        return Money(amountMinor: lhs.amountMinor - rhs.amountMinor, currencyCode: lhs.currencyCode)
    }

    public static let zero = Money(amountMinor: 0)
}
