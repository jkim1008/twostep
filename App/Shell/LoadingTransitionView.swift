import SwiftUI

/// Branded loading transition (PRD §4.1, DESIGN.md §6/§8): the interim sage
/// "steps" mark with a subtle native pulse for about 1.5 seconds, then the
/// main shell. No video assets; the pulse is skipped under Reduce Motion.
struct LoadingTransitionView: View {
    @Environment(ShellRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: Theme.cardSpacing * 2) {
            StepsMarkView()
                .frame(width: 96, height: 96)
                .scaleEffect(isPulsing ? 1.06 : 1.0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: isPulsing
                )
            Text("Setting up your household…")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .onAppear { isPulsing = true }
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            router.route = .main
        }
    }
}

/// The interim geometric "steps" brand mark, drawn in the sage primary —
/// the final logo is an open question; this mark covers v1 needs.
struct StepsMarkView: View {
    var body: some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.width, geometry.size.height) / 3
            let corner = unit / 4
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: corner)
                    .frame(width: unit, height: unit)
                    .offset(x: unit * 2)
                RoundedRectangle(cornerRadius: corner)
                    .frame(width: unit, height: unit)
                    .offset(x: unit)
                RoundedRectangle(cornerRadius: corner)
                    .frame(width: unit, height: unit)
            }
            .foregroundStyle(Theme.primary)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Two Step")
    }
}

#Preview {
    LoadingTransitionView()
        .environment(ShellRouter(route: .loading))
}
