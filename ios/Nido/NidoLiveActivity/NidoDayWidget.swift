import SwiftUI
import WidgetKit

nonisolated private struct NidoWidgetSnapshot: Codable, Sendable {
    let babyName: String
    let sleepMinutes: Int
    let feeds: Int
    let diapers: Int
    let latestKind: String?
    let latestDate: Date?
    let activeKind: String?
    let activeStartedAt: Date?
    let updatedAt: Date
    let sleepGoalMinutes: Int?
    let feedGoal: Int?
    let diaperGoal: Int?

    static let preview = NidoWidgetSnapshot(
        babyName: "Marco",
        sleepMinutes: 192,
        feeds: 4,
        diapers: 3,
        latestKind: "feed",
        latestDate: .now.addingTimeInterval(-1_800),
        activeKind: nil,
        activeStartedAt: nil,
        updatedAt: .now,
        sleepGoalMinutes: nil,
        feedGoal: nil,
        diaperGoal: nil
    )
}

nonisolated private struct NidoDayEntry: TimelineEntry, Sendable {
    let date: Date
    let snapshot: NidoWidgetSnapshot
}

private struct NidoDayProvider: TimelineProvider {
    private let appGroupIdentifier = "group.com.momentumia.nido"
    private let snapshotKey = "nido.widget.snapshot.v1"

    func placeholder(in context: Context) -> NidoDayEntry {
        NidoDayEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (NidoDayEntry) -> Void) {
        completion(NidoDayEntry(date: .now, snapshot: loadSnapshot() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NidoDayEntry>) -> Void) {
        let now = Date.now
        let entry = NidoDayEntry(date: now, snapshot: loadSnapshot() ?? .preview)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadSnapshot() -> NidoWidgetSnapshot? {
        guard
            let data = UserDefaults(suiteName: appGroupIdentifier)?.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(NidoWidgetSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }
}

struct NidoDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NidoDayWidget", provider: NidoDayProvider()) { entry in
            NidoDayWidgetView(entry: entry)
        }
        .configurationDisplayName("El día en Nido")
        .description("Sueño, tomas y pañales de hoy de un vistazo.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private struct NidoDayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NidoDayEntry

    private let moss = Color(red: 0.27, green: 0.39, blue: 0.32)
    private let paper = Color(red: 0.97, green: 0.95, blue: 0.90)
    private let ink = Color(red: 0.15, green: 0.14, blue: 0.12)
    private let sleepAccent = Color(.displayP3, red: 228.0 / 255, green: 62.0 / 255, blue: 108.0 / 255)
    private let feedAccent = Color(.displayP3, red: 186.0 / 255, green: 249.0 / 255, blue: 78.0 / 255)
    private let diaperAccent = Color(.displayP3, red: 100.0 / 255, green: 218.0 / 255, blue: 214.0 / 255)

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                accessoryCircular
            case .accessoryRectangular:
                accessoryRectangular
            case .systemMedium:
                medium
            default:
                small
            }
        }
        .containerBackground(for: .widget) { paper }
        .widgetAccentable()
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 10)
            if let activeKind = entry.snapshot.activeKind, let startedAt = entry.snapshot.activeStartedAt {
                activeStatus(kind: activeKind, startedAt: startedAt, compact: false)
            } else {
                Text("Hoy con \(entry.snapshot.babyName)")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .privacySensitive()
                Spacer(minLength: 8)
                metricStrip
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 10)
                if let activeKind = entry.snapshot.activeKind, let startedAt = entry.snapshot.activeStartedAt {
                    activeStatus(kind: activeKind, startedAt: startedAt, compact: false)
                } else {
                    Text("Hoy con \(entry.snapshot.babyName)")
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .privacySensitive()
                    if let latestLabel {
                        Text(latestLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 5)
                            .privacySensitive()
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                metricRow(symbol: "moon.fill", value: sleepLabel + (entry.snapshot.sleepGoalMinutes.map { " / \($0 / 60) h \($0 % 60) min" } ?? ""), tint: sleepAccent)
                metricRow(symbol: "waterbottle.fill", value: "\(entry.snapshot.feeds)" + (entry.snapshot.feedGoal.map { " / \($0)" } ?? ""), tint: feedAccent)
                metricRow(symbol: "drop.fill", value: "\(entry.snapshot.diapers)" + (entry.snapshot.diaperGoal.map { " / \($0)" } ?? ""), tint: diaperAccent)
            }
            .privacySensitive()
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let kind = entry.snapshot.activeKind, let startedAt = entry.snapshot.activeStartedAt {
                VStack(spacing: 1) {
                    Image(systemName: symbol(for: kind))
                    Text(startedAt, style: .timer)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "moon.fill")
                    Text(shortSleepLabel)
                        .font(.caption2.bold())
                }
            }
        }
        .privacySensitive()
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nido · \(entry.snapshot.babyName)")
                .font(.headline)
            if let kind = entry.snapshot.activeKind, let startedAt = entry.snapshot.activeStartedAt {
                HStack(spacing: 5) {
                    Image(systemName: symbol(for: kind))
                    Text(kind == "sleep" ? "Sueño" : "Lactancia")
                    Text(startedAt, style: .timer).monospacedDigit()
                }
                .font(.caption)
            } else {
                Text("\(sleepLabel) sueño · \(entry.snapshot.feeds) tomas · \(entry.snapshot.diapers) pañales")
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .privacySensitive()
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "bird.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(moss)
            Text("Nido")
                .font(.caption.weight(.semibold))
                .foregroundStyle(moss)
            Spacer(minLength: 0)
        }
    }

    private var metricStrip: some View {
        HStack(spacing: 13) {
            compactMetric(symbol: "moon.fill", value: shortSleepLabel, tint: sleepAccent)
            compactMetric(symbol: "waterbottle.fill", value: "\(entry.snapshot.feeds)", tint: feedAccent)
            compactMetric(symbol: "drop.fill", value: "\(entry.snapshot.diapers)", tint: diaperAccent)
        }
        .privacySensitive()
    }

    private func compactMetric(symbol: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: symbol)
                .font(.caption2)
                .foregroundStyle(tint)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(ink)
        }
    }

    private func metricRow(symbol: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 15)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(ink)
                .frame(minWidth: 42, alignment: .leading)
        }
    }

    private func activeStatus(kind: String, startedAt: Date, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: symbol(for: kind))
                    .foregroundStyle(moss)
                Text(kind == "sleep" ? "Sueño en curso" : "Lactancia en curso")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                .font(.system(compact ? .headline : .title2, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(ink)
        }
        .privacySensitive()
    }

    private func symbol(for kind: String) -> String {
        kind == "sleep" ? "moon.fill" : "figure.and.child.holdinghands"
    }

    private var sleepLabel: String {
        let hours = entry.snapshot.sleepMinutes / 60
        let minutes = entry.snapshot.sleepMinutes % 60
        return hours > 0 ? "\(hours) h \(minutes) min" : "\(minutes) min"
    }

    private var shortSleepLabel: String {
        let hours = entry.snapshot.sleepMinutes / 60
        let minutes = entry.snapshot.sleepMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private var latestLabel: String? {
        guard let kind = entry.snapshot.latestKind, let date = entry.snapshot.latestDate else { return nil }
        let title: String = switch kind {
        case "sleep": "Sueño"
        case "feed": "Toma"
        case "diaper": "Pañal"
        default: "Cuidado"
        }
        return "Último: \(title) · \(date.formatted(date: .omitted, time: .shortened))"
    }
}

#Preview(as: .systemSmall) {
    NidoDayWidget()
} timeline: {
    NidoDayEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemMedium) {
    NidoDayWidget()
} timeline: {
    NidoDayEntry(date: .now, snapshot: .preview)
}
