import SwiftUI
import TwoStepCore

/// Add one contribution to a project (PRD §4.5 flow 2): amount, contributing
/// partner (or Joint), optional note. The repository adjusts the project
/// aggregate in the same mutation — mirroring the atomic-batch invariant.
struct SavingsContributeSheet: View {
    let project: SavingsProject

    @Environment(AppRepositories.self) private var repositories
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var contributorId: String
    @State private var note = ""

    init(project: SavingsProject, defaultContributorId: String) {
        self.project = project
        _contributorId = State(initialValue: defaultContributorId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(project.emoji)
                            .accessibilityHidden(true)
                        Text(project.name)
                            .font(.headline)
                    }
                    HStack {
                        Text("Amount")
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .accessibilityLabel(Text("Contribution amount in dollars"))
                    }
                }
                Section("Contributed by") {
                    Picker("Contributed by", selection: $contributorId) {
                        ForEach(contributorOptions, id: \.id) { option in
                            Text(option.name).tag(option.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(Text("Contributing partner"))
                }
                Section("Note") {
                    TextField("Optional note", text: $note)
                }
            }
            .navigationTitle("Add contribution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled((parsedMinor ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Options

    private var contributorOptions: [(id: String, name: String)] {
        let members = repositories.households.members.map { ($0.id, $0.displayName) }
        return members + [(Attribution.joint.rawValue, repositories.households.displayName(for: .joint))]
    }

    private var parsedMinor: Int? {
        SavingsFormat.minorUnits(fromInput: amountText)
    }

    // MARK: Save

    private func save() {
        guard let minor = parsedMinor, minor > 0 else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)
        let contribution = Contribution(
            id: "contrib-\(UUID().uuidString)",
            projectId: project.id,
            amountMinor: minor,
            date: DemoSeed.focusDate,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            contributedByUid: contributorId
        )
        print("[SavingsContributeSheet] \(contributorId) contributed \(minor) to \(project.id)")
        repositories.savings.addContribution(contribution)
        appendEvent(minor: minor)
        dismiss()
    }

    private func appendEvent(minor: Int) {
        let households = repositories.households
        let contributorName = households.displayName(for: Attribution(rawValue: contributorId))
        let actorUid = households.currentMember?.id ?? contributorId
        repositories.events.append(HouseholdEvent(
            id: UUID().uuidString,
            type: .contributionAdded,
            actorUid: actorUid,
            timestamp: DemoSeed.timestamp(DemoSeed.focusDate, hour: 18),
            payload: "\(contributorName) contributed \(SavingsFormat.compactCurrency(minor)) to \(project.emoji) \(project.name)"
        ))
    }
}

#Preview {
    SavingsContributeSheet(
        project: SavingsProject(
            id: "preview", name: "Anniversary Trip", emoji: "🏝️",
            recurringContributionMinor: 200_00, cadence: .monthly, durationMonths: 8
        ),
        defaultContributorId: DemoSeed.mayaUid
    )
    .environment(DemoSeed.makeRepositories())
}
