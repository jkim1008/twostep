import SwiftUI

/// Large sage dial pad (PRD §4.3 Quick Add): digits append to the amount in
/// minor units — cents-first entry, the pattern of every fast money keypad.
/// "00" fills whole dollars quickly; delete pops one digit.
struct QuickAddDialPad: View {
    @Binding var amountMinor: Int

    /// Cap: $99,999.99 — keeps demo entry sane and the Int far from overflow.
    private static let maxAmountMinor = 99_999_99
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(1...9, id: \.self) { digit in
                digitKey(digit)
            }
            doubleZeroKey
            digitKey(0)
            deleteKey
        }
        .sensoryFeedback(.selection, trigger: amountMinor)
    }

    private func digitKey(_ digit: Int) -> some View {
        Button {
            append(digit: digit)
        } label: {
            Text(verbatim: "\(digit)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.primaryTint, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Digit \(digit)"))
    }

    private var doubleZeroKey: some View {
        Button {
            append(digit: 0)
            append(digit: 0)
        } label: {
            Text(verbatim: "00")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.primaryTint, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Double zero"))
    }

    private var deleteKey: some View {
        Button {
            amountMinor /= 10
        } label: {
            Image(systemName: "delete.left")
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Delete last digit"))
    }

    private func append(digit: Int) {
        let next = amountMinor * 10 + digit
        guard next <= Self.maxAmountMinor else { return }
        amountMinor = next
    }
}

#Preview {
    QuickAddDialPad(amountMinor: .constant(12_34))
        .padding()
        .background(Theme.background)
}
