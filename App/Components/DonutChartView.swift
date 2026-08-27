import SwiftUI

/// One slice of the donut: a non-negative value, its chart color, and an
/// accessibility label ("🛒 Groceries, $412").
struct DonutSegment: Identifiable {
    let id: String
    let value: Double
    let color: Color
    let label: String

    init(id: String, value: Double, color: Color, label: String) {
        self.id = id
        self.value = max(0, value)
        self.color = color
        self.label = label
    }
}

/// Canvas-drawn donut chart (DESIGN.md §5.2) with a center content slot for
/// the hero numeral. With no positive segments it renders a quiet empty ring.
struct DonutChartView<Center: View>: View {
    let segments: [DonutSegment]
    var lineWidth: CGFloat = 26
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Canvas { context, size in
                draw(in: context, size: size)
            }
            center()
                .padding(lineWidth + 12)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private var total: Double {
        segments.reduce(0) { $0 + $1.value }
    }

    private var accessibilitySummary: String {
        guard total > 0 else { return String(localized: "No spending yet") }
        return segments
            .filter { $0.value > 0 }
            .map(\.label)
            .joined(separator: ", ")
    }

    private func draw(in context: GraphicsContext, size: CGSize) {
        let centerPoint = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - lineWidth / 2
        guard radius > 0 else { return }
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .butt)

        guard total > 0 else {
            let ring = Path { path in
                path.addArc(
                    center: centerPoint, radius: radius,
                    startAngle: .zero, endAngle: .degrees(360), clockwise: false
                )
            }
            context.stroke(ring, with: .color(Theme.surface), style: style)
            return
        }

        var startAngle = Angle.degrees(-90)
        for segment in segments where segment.value > 0 {
            let sweep = Angle.degrees(360 * segment.value / total)
            let endAngle = startAngle + sweep
            let arc = Path { path in
                path.addArc(
                    center: centerPoint, radius: radius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: false
                )
            }
            context.stroke(arc, with: .color(segment.color), style: style)
            startAngle = endAngle
        }
    }
}

#Preview {
    DonutChartView(segments: [
        DonutSegment(id: "a", value: 412, color: Theme.primary, label: "Groceries, $412"),
        DonutSegment(id: "b", value: 156, color: Theme.info, label: "Dining, $156"),
        DonutSegment(id: "c", value: 88, color: Theme.warning, label: "Transport, $88")
    ]) {
        Text("$656")
            .font(.title.bold())
            .monospacedDigit()
    }
    .padding(40)
    .background(Theme.background)
}
