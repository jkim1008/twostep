import SwiftUI
import TwoStepCore

/// Duration-first project creation (PRD §4.5 flow 1, primary): "$X per month
/// for N months" with the target derived live via `SavingsProject`'s tested
/// core math. A manual-target override remains available; both paths produce
/// the same project object.
struct SavingsProjectFormSheet: View {
    @Environment(AppRepositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "🏝️"
    @State private var monthlyAmountText = ""
    @State private var durationMonths = 6
    @State private var useManualTarget = false
    @State private var manualTargetText = ""

    private static let emojiChoices = [
        "🏝️", "🛋️", "🚗", "🏠", "💍", "🎸", "🚲", "🐕",
        "🎿", "📷", "🌱", "✈️", "🛠️", "🎓", "🚨", "🎁"
    ]

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                planSection
                if useManualTarget {
                    manualTargetSection
                }
            }
            .navigationTitle("New project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    // MARK: Sections

    private var identitySection: some View {
        Section("Name & emoji") {
            TextField("Project name", text: $name)
            SavingsEmojiPickerGrid(choices: Self.emojiChoices, selection: $emoji)
        }
    }

    private var planSection: some View {
        Section {
            HStack {
                Text("Per month")
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                TextField("0", text: $monthlyAmountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .disabled(useManualTarget)
                    .accessibilityLabel(Text("Monthly contribution in dollars"))
            }
            Stepper(value: $durationMonths, in: 1...48) {
                Text("For \(durationMonths) months")
                    .monospacedDigit()
            }
            .disabled(useManualTarget)
            Toggle("Set target manually instead", isOn: $useManualTarget)
                .tint(Theme.primary)
        } header: {
            Text("Monthly plan")
        } footer: {
            derivedTargetFooter
        }
    }

    private var manualTargetSection: some View {
        Section("Target amount") {
            HStack {
                Text("Target")
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                TextField("0", text: $manualTargetText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .accessibilityLabel(Text("Target amount in dollars"))
            }
        }
    }

    @ViewBuilder
    private var derivedTargetFooter: some View {
        if useManualTarget {
            Text("The target is whatever you set — no monthly plan attached.")
        } else if let derived = draftProject.derivedTargetAmountMinor, let monthly = parsedMonthlyMinor {
            let monthlyText = SavingsFormat.compactCurrency(monthly)
            Text("Target \(SavingsFormat.compactCurrency(derived)) — \(monthlyText) × \(durationMonths) months")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.primaryDark)
            .monospacedDigit()
        } else {
            Text("Enter a monthly amount to see the derived target.")
        }
    }

    // MARK: Derivation (TwoStepCore owns the formula)

    private var parsedMonthlyMinor: Int? {
        SavingsFormat.minorUnits(fromInput: monthlyAmountText)
    }

    /// A throwaway draft whose `derivedTargetAmountMinor` gives the live
    /// "amount × months" figure — the same rule both devices apply.
    private var draftProject: SavingsProject {
        SavingsProject(
            id: "draft",
            name: name,
            emoji: emoji,
            recurringContributionMinor: parsedMonthlyMinor ?? 0,
            cadence: .monthly,
            durationMonths: durationMonths
        )
    }

    private var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if useManualTarget {
            return (SavingsFormat.minorUnits(fromInput: manualTargetText) ?? 0) > 0
        }
        return (parsedMonthlyMinor ?? 0) > 0
    }

    // MARK: Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let project = SavingsProject(
            id: "project-\(UUID().uuidString)",
            name: trimmedName,
            emoji: emoji,
            recurringContributionMinor: useManualTarget ? 0 : (parsedMonthlyMinor ?? 0),
            cadence: .monthly,
            durationMonths: useManualTarget ? nil : durationMonths,
            manualTargetAmountMinor: useManualTarget
                ? SavingsFormat.minorUnits(fromInput: manualTargetText)
                : nil
        )
        print("[SavingsProjectFormSheet] Created project \(project.id) target \(project.targetAmountMinor ?? 0)")
        repositories.savings.add(project)
        appendCreationEvent(for: project)
        dismiss()
    }

    private func appendCreationEvent(for project: SavingsProject) {
        guard let member = repositories.households.currentMember else { return }
        repositories.events.append(HouseholdEvent(
            id: UUID().uuidString,
            type: .projectCreated,
            actorUid: member.id,
            timestamp: DemoSeed.timestamp(DemoSeed.focusDate, hour: 18),
            payload: "\(member.displayName) created \(project.emoji) \(project.name)"
        ))
    }
}

/// 44pt emoji swatches; selection carries a tint *and* a border so state
/// never rides on color alone.
private struct SavingsEmojiPickerGrid: View {
    let choices: [String]
    @Binding var selection: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
            ForEach(choices, id: \.self) { choice in
                Button {
                    selection = choice
                } label: {
                    Text(choice)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(
                            choice == selection ? Theme.primaryTint : Theme.surface,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(choice == selection ? Theme.primary : .clear, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Emoji \(choice)"))
                .accessibilityAddTraits(choice == selection ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SavingsProjectFormSheet()
        .environment(DemoSeed.makeRepositories())
}
