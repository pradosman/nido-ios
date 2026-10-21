#if DEBUG
import SwiftUI

/// A native, explicitly read-only design checkpoint. The live Trends route remains available.
struct EvolutionDesignPreviewView: View {
    let scenario: String
    @Environment(\.floatingNavigationClearance) private var floatingNavigationClearance

    private var summary: EvolutionSummary {
        EvolutionDesignFixture.summary(isEmpty: scenario == "evolution-design-empty")
    }

    var body: some View {
        if scenario == "evolution-design-sleep-empty" {
            SleepEvolutionDetailView(isEmpty: true)
        } else {
            summaryBody
        }
    }

    private var summaryBody: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Vista previa · Datos de ejemplo")
                        .font(.caption)
                        .foregroundStyle(NidoTheme.readableSupportingInk)
                        .accessibilityIdentifier("evolution-preview-notice")
                        .padding(.horizontal, 4)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Datos fijados")
                                .font(.title3.bold())
                                .foregroundStyle(NidoTheme.ink)
                            Spacer(minLength: 12)
                            Button("Editar", action: {})
                                .font(.body)
                                .foregroundStyle(NidoTheme.moss)
                                .buttonStyle(.plain)
                                .disabled(true)
                                .accessibilityIdentifier("evolution-edit")
                        }
                        .padding(.horizontal, 4)

                        ForEach(summary.metrics, id: \.metric) { metric in
                            if metric.metric == .sleep, scenario == "evolution-design-sleep" {
                                NavigationLink {
                                    SleepEvolutionDetailView(isEmpty: false)
                                } label: {
                                    metricCard(metric)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("evolution-sleep-card")
                            } else {
                                metricCard(metric)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .contentMargins(.bottom, floatingNavigationClearance, for: .scrollContent)
        }
        .navigationTitle("Evolución")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("M")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(NidoTheme.moss)
                    .frame(width: 44, height: 44)
                    .background(NidoTheme.surface, in: .circle)
                    .accessibilityLabel("Marco")
            }
        }
        .accessibilityIdentifier("evolution-summary-preview")
    }

    private func metricCard(_ snapshot: EvolutionMetricSnapshot) -> some View {
        EvolutionMetricCard(snapshot: snapshot, calendar: EvolutionDesignFixture.summaryCalendar)
    }
}

enum EvolutionDesignFixture {
    static var now: Date {
        guard let date = summaryCalendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 13, minute: 10)) else {
            preconditionFailure("Invalid evolution preview reference date")
        }
        return date
    }

    static var summaryCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .gmt
        return calendar
    }

    static var sleepCalendar: Calendar {
        var calendar = summaryCalendar
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    static var sleepEntries: [Entry] {
        let calendar = sleepCalendar
        let now = self.now
        let start = calendar.startOfDay(for: now)
        var entries = historicalEntries(calendar: calendar, start: start)
        let completedEnd = calendar.date(byAdding: .hour, value: 6, to: start)!
        entries.append(entry(id: "sleep-today-completed", kind: .sleep, date: completedEnd, duration: 180))
        return entries
    }

    static var activeSleepStartedAt: Date {
        let start = sleepCalendar.startOfDay(for: now)
        return sleepCalendar.date(byAdding: .minute, value: 10, to: sleepCalendar.date(byAdding: .hour, value: 10, to: start)!)!
    }

    static func summary(isEmpty: Bool) -> EvolutionSummary {
        let calendar = summaryCalendar
        let now = self.now
        if isEmpty { return EvolutionSummary.build(entries: [], measurements: [], now: now, calendar: calendar) }

        let start = calendar.startOfDay(for: now)
        let entries = historicalEntries(calendar: calendar, start: start)
        let growth: [(Int, Int, Int)] = [(-80, 3_450, 510), (-55, 4_200, 542), (-35, 5_100, 580), (-16, 6_200, 623), (-2, 6_950, 652)]
        let measurements = growth.compactMap { offset, grams, millimeters -> GrowthMeasurement? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return GrowthMeasurement(id: "preview-growth-\(offset)", measuredAt: Int64(date.addingTimeInterval(10 * 3_600).timeIntervalSince1970 * 1_000), weightGrams: grams, heightMillimeters: millimeters, note: "")
        }
        return EvolutionSummary.build(entries: entries, measurements: measurements, now: now, calendar: calendar)
    }

    private static func historicalEntries(calendar: Calendar, start: Date) -> [Entry] {
        let sleepMinutes = [720, 780, 735, 810, 765, 795, 750]
        let feedCounts = [7, 8, 8, 7, 9, 8, 9]
        let diaperCounts = [6, 0, 5, 7, 0, 6, 6]
        var entries: [Entry] = []
        for index in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: index - 7, to: start) else { continue }
            entries.append(entry(id: "sleep-\(index)", kind: .sleep, date: day.addingTimeInterval(18 * 3_600), duration: sleepMinutes[index]))
            for count in 0..<feedCounts[index] {
                entries.append(entry(id: "feed-\(index)-\(count)", kind: .feed, date: day.addingTimeInterval(Double((6 + count * 2) * 3_600))))
            }
            for count in 0..<diaperCounts[index] {
                entries.append(entry(id: "diaper-\(index)-\(count)", kind: .diaper, date: day.addingTimeInterval(Double((7 + count * 2) * 3_600))))
            }
        }
        return entries
    }

    private static func entry(id: String, kind: EntryKind, date: Date, duration: Int? = nil) -> Entry {
        Entry(id: "evolution-preview-\(id)", kind: kind, title: kind.title, detail: "", occurredAt: Int64(date.timeIntervalSince1970 * 1_000), durationMinutes: duration, amountMl: nil)
    }
}
#endif
