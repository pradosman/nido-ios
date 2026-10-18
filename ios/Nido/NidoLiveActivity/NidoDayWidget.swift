import SwiftUI
import WidgetKit

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
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme
    let entry: NidoDayEntry

    var body: some View {
        NidoDayWidgetContent(snapshot: entry.snapshot, family: family, renderingMode: renderingMode)
            .containerBackground(for: .widget) {
                colorScheme == .dark
                    ? Color(red: 0.075, green: 0.082, blue: 0.078)
                    : Color(red: 0.969, green: 0.973, blue: 0.961)
            }
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
