import ActivityKit
import SwiftUI
import WidgetKit

struct NidoLiveActivityWidget: Widget {
    private let moss = Color(red: 0.32, green: 0.43, blue: 0.37)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NidoActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: context.attributes.kind == "sleep" ? "moon.fill" : "figure.and.child.holdinghands")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(moss)
                    .frame(width: 40, height: 40)
                    .background(moss.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.kind == "sleep" ? "Sueño en curso" : "Lactancia en curso")
                        .font(.headline)
                    Text(context.attributes.babyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(moss)
            }
            .padding(16)
            .privacySensitive()
            .activityBackgroundTint(Color(uiColor: .systemBackground))
            .activitySystemActionForegroundColor(moss)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.kind == "sleep" ? "moon.fill" : "figure.and.child.holdinghands")
                        .foregroundStyle(moss)
                        .privacySensitive()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.kind == "sleep" ? "Sueño" : "Lactancia")
                        .font(.headline)
                        .privacySensitive()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                        .font(.caption.monospacedDigit())
                        .privacySensitive()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("En curso para \(context.attributes.babyName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .privacySensitive()
                }
            } compactLeading: {
                Image(systemName: context.attributes.kind == "sleep" ? "moon.fill" : "figure.and.child.holdinghands")
                    .foregroundStyle(moss)
                    .privacySensitive()
            } compactTrailing: {
                Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 42)
                    .privacySensitive()
            } minimal: {
                Image(systemName: context.attributes.kind == "sleep" ? "moon.fill" : "figure.and.child.holdinghands")
                    .foregroundStyle(moss)
                    .privacySensitive()
            }
        }
    }
}
