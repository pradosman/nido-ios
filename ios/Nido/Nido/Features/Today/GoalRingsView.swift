import SwiftUI

/// Three concentric goal rings for the Today screen.
/// Values and goals use the same units; a missing/invalid goal leaves a neutral track.
struct GoalRingsView: View, Animatable {
    var sleep: Double
    var sleepGoal: Double?
    var feed: Double
    var feedGoal: Double?
    var diaper: Double
    var diaperGoal: Double?
    var size: CGFloat = 300
    var accessibilityLabel: String = "Objetivos del día"

    // Interpolate real quantities so crossing 100% continues forwards through the seam.
    nonisolated var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(sleep, AnimatablePair(feed, diaper)) }
        set {
            sleep = newValue.first
            feed = newValue.second.first
            diaper = newValue.second.second
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height)
            let thickness = min(diameter, diameter * 0.10)
            let spacing = diameter * 0.018
            let ringStep = thickness + spacing

            ZStack {
                ring(
                    progress: GoalRingProgress(value: sleep, goal: sleepGoal),
                    kind: .sleep,
                    diameter: diameter,
                    thickness: thickness,
                    inset: 0
                )
                ring(
                    progress: GoalRingProgress(value: feed, goal: feedGoal),
                    kind: .feed,
                    diameter: diameter,
                    thickness: thickness,
                    inset: ringStep
                )
                ring(
                    progress: GoalRingProgress(value: diaper, goal: diaperGoal),
                    kind: .diaper,
                    diameter: diameter,
                    thickness: thickness,
                    inset: ringStep * 2
                )
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var accessibilityDescription: String {
        let sleepText = progressDescription(value: sleep, goal: sleepGoal, unit: "minutos")
        let feedText = progressDescription(value: feed, goal: feedGoal, unit: "tomas")
        let diaperText = progressDescription(value: diaper, goal: diaperGoal, unit: "pañales")
        return "\(accessibilityLabel). Sueño: \(sleepText). Tomas: \(feedText). Pañales: \(diaperText)."
    }

    private func progressDescription(value: Double, goal: Double?, unit: String) -> String {
        let displayedValue = safeDisplayValue(value)
        guard let goal, goal.isFinite, goal > 0 else {
            return "\(displayedValue.formatted()) \(unit), sin objetivo"
        }
        return "\(displayedValue.formatted()) de \(goal.formatted()) \(unit)"
    }

    private func safeDisplayValue(_ value: Double) -> Double {
        value.isFinite && value >= 0 ? value : 0
    }

    private func ring(
        progress: GoalRingProgress,
        kind: EntryKind,
        diameter: CGFloat,
        thickness: CGFloat,
        inset: CGFloat
    ) -> some View {
        GoalRingLayer(
            progress: progress,
            accent: NidoTheme.chartAccent(for: kind),
            diameter: max(0, diameter - inset * 2),
            thickness: thickness
        )
    }
}

private struct GoalRingLayer: View {
    let progress: GoalRingProgress
    let accent: Color
    let diameter: CGFloat
    let thickness: CGFloat

    var body: some View {
        let strokeDiameter = max(0, diameter - thickness)

        ZStack {
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                .frame(width: strokeDiameter, height: strokeDiameter)

            if progress.visualFraction > 0 {
                Circle()
                    .trim(from: 0, to: progress.visualFraction)
                    .stroke(accent, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                    .overlay {
                        Circle()
                            .trim(from: 0, to: progress.visualFraction)
                            .stroke(
                                AngularGradient(
                                    colors: [.clear, .white.opacity(0.12), .clear, .black.opacity(0.08), .clear],
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360)
                                ),
                                style: StrokeStyle(lineWidth: thickness, lineCap: .round)
                            )
                    }
                    .rotationEffect(.degrees(-90))
                    .frame(width: strokeDiameter, height: strokeDiameter)
            }

            if progress.fraction.map({ $0 > 1 }) == true,
               progress.showsTerminalCap,
               let angle = progress.terminalAngleDegrees {
                terminalArcShadow(at: angle)
                Circle()
                    .trim(from: 0, to: additionalTurnFraction)
                    .stroke(accent, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: strokeDiameter, height: strokeDiameter)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    private var trackColor: Color {
        progress.goal == nil ? Color.secondary.opacity(0.15) : accent.opacity(0.14)
    }

    private var additionalTurnFraction: Double {
        guard let fraction = progress.fraction, fraction > 1 else { return 0 }
        return fraction.truncatingRemainder(dividingBy: 1)
    }

    private func terminalArcShadow(at angleDegrees: Double) -> some View {
        let strokeDiameter = max(0, diameter - thickness)
        let angle = angleDegrees * .pi / 180
        let tangentX = -sin(angle)
        let tangentY = cos(angle)

        // The stroke supplies its own rounded end. Cast its shadow first, then
        // paint the uninterrupted foreground arc over it; no separate cap disc.
        return Circle()
            .trim(from: max(0, additionalTurnFraction - 0.125), to: additionalTurnFraction)
            .stroke(accent, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: strokeDiameter, height: strokeDiameter)
            .shadow(
                color: .black.opacity(0.36),
                radius: max(1, thickness * 0.20),
                x: tangentX * thickness * 0.20,
                y: tangentY * thickness * 0.20
            )
            .frame(width: diameter, height: diameter)
            .mask {
                Circle()
                    .stroke(lineWidth: thickness)
                    .frame(width: strokeDiameter, height: strokeDiameter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .mask {
                        Path { path in
                            let center = CGPoint(x: diameter / 2, y: diameter / 2)
                            path.move(to: center)
                            path.addArc(
                                center: center,
                                radius: diameter,
                                startAngle: .degrees(angleDegrees - 2),
                                endAngle: .degrees(angleDegrees + 50),
                                clockwise: false
                            )
                            path.closeSubpath()
                        }
                    }
            }
    }
}
