import Testing
import Foundation
@testable import TwoStepCore

@Suite("Money — integer minor units")
struct MoneyTests {
    @Test("Decimal converts to exact minor units")
    func decimalConversion() {
        #expect(Money(decimal: Decimal(string: "12.34") ?? .zero).amountMinor == 1234)
        #expect(Money(decimal: Decimal(string: "0.01") ?? .zero).amountMinor == 1)
        #expect(Money(decimal: Decimal(string: "100") ?? .zero).amountMinor == 10000)
    }

    @Test("Half-cent artifacts round away from zero — the canonical ingest rule")
    func halfAwayFromZeroRounding() {
        #expect(Money(decimal: Decimal(string: "2.005") ?? .zero).amountMinor == 201)
        #expect(Money(decimal: Decimal(string: "-2.005") ?? .zero).amountMinor == -201)
    }

    @Test("Round-trips through decimal display value")
    func roundTrip() {
        let money = Money(amountMinor: 123456)
        #expect(money.decimalValue == Decimal(string: "1234.56"))
        #expect(Money(decimal: money.decimalValue).amountMinor == money.amountMinor)
    }

    @Test("Arithmetic stays in integer space")
    func arithmetic() {
        let sum = Money(amountMinor: 1050) + Money(amountMinor: 275)
        #expect(sum.amountMinor == 1325)
        let diff = Money(amountMinor: 1050) - Money(amountMinor: 1075)
        #expect(diff.amountMinor == -25)
    }
}
