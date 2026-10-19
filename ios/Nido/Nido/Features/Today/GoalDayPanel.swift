import SwiftUI

/// A day’s actual quantities against the goals that were effective on that day.
struct GoalDayPanel: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let date: Date
    var size: CGFloat = 294
    var summaryIdentifierPrefix = "history-summary"
    var showsRings = true
    var onSelect: (EntryKind) -> Void

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = store.currentDate(for: context.date)
            let totals = BabyCareMetrics.summary(on: date, entries: store.entries,
                activeSleepStartedAt: store.activeSleepStartedAt, now: now,
                calendar: BabyCareMetrics.calendar(for: store.babyCareState))
            let goals = BabyCareMetrics.goals(on: date, state: store.babyCareState)
            VStack(spacing: 16) {
                if showsRings {
                Button { onSelect(.sleep) } label: {
                    GoalRingsView(sleep: Double(totals.sleepSeconds) / 60, sleepGoal: goals?.sleepMinutes.map(Double.init),
                        feed: Double(totals.feedCount), feedGoal: goals?.feedCount.map(Double.init),
                        diaper: Double(totals.diaperCount), diaperGoal: goals?.diaperCount.map(Double.init), size: size)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ver el detalle de este día")
                .accessibilityIdentifier("daily-goal-ring-graphic")
                }
                summaryLayout {
                    metric(.sleep, value: totals.sleepSeconds / 60, goal: goals?.sleepMinutes)
                    metric(.feed, value: totals.feedCount, goal: goals?.feedCount)
                    metric(.diaper, value: totals.diaperCount, goal: goals?.diaperCount)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.45), value: totals)
            .accessibilityElement(children: .contain)
        }
    }

    private var summaryLayout: AnyLayout {
        typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
    }

    private func metric(_ kind: EntryKind, value: Int, goal: Int?) -> some View {
        let name = kind == .sleep ? "Sueño" : kind == .feed ? "Tomas" : "Pañales"
        return Button { onSelect(kind) } label: {
            VStack(alignment: .leading, spacing: 7) {
                Label {
                    Text(name)
                } icon: {
                    CareCategoryIcon(category: kind.careCategory, size: 17, tint: NidoTheme.color(for: kind))
                }
                    .labelStyle(GoalMetricLabelStyle())
                    .font(.subheadline.weight(.semibold))
                quantity(kind, value: value)
                    .font(.system(.largeTitle, design: .rounded, weight: .medium))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
                    .contentTransition(.numericText())
                Text(goal.map { kind == .sleep ? "de \(DurationLabel.minutes($0))" : "de \($0)" } ?? "Sin objetivo")
                    .font(.subheadline).foregroundStyle(NidoTheme.readableSupportingInk)
            }
            .foregroundStyle(NidoTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityValue(kind == .sleep
            ? "\(DurationLabel.minutes(value)), \(goal.map { "objetivo \(DurationLabel.minutes($0))" } ?? "sin objetivo")"
            : "\(value), \(goal.map { "objetivo \($0)" } ?? "sin objetivo")")
        .accessibilityIdentifier("\(summaryIdentifierPrefix)-\(kind.rawValue)")
    }

    private func quantity(_ kind: EntryKind, value: Int) -> Text {
        guard kind == .sleep else { return Text("\(value)") }
        return Text("\(value / 60)") + Text(" h ").font(.subheadline)
            + Text(String(format: "%02d", value % 60)) + Text(" min").font(.caption)
    }
}

private struct GoalMetricLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
            configuration.title
        }
    }
}

struct BabyCareSyncStatus: View {
    @Environment(NidoStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.babyCareHasConflict {
                Text("Hay cambios de otro cuidador. Elige qué versión conservar.")
                Button("Conservar mis cambios") { Task { await store.resolveBabyCareConflict(keepLocal: true) } }
                Button("Usar los cambios compartidos") { Task { await store.resolveBabyCareConflict(keepLocal: false) } }
            } else if store.babyCareNeedsSync {
                Label("Guardado aquí · pendiente de sincronizar", systemImage: "arrow.triangle.2.circlepath")
                Button("Reintentar") { Task { await store.retryBabyCareSync() } }
            }
            if let error = store.babyCareError { Text(error) }
        }
        .font(.footnote)
        .foregroundStyle(NidoTheme.readableSupportingInk)
        .accessibilityIdentifier("baby-care-sync-status")
    }
}
