import ActivityKit
import SwiftUI
import WidgetKit

struct NidoLiveActivityWidget: Widget {
    private func accent(_ kind: String) -> Color {
        Color(NidoCarePalette.accent(for: kind == "sleep" ? .sleep : .feed))
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NidoActivityAttributes.self) { context in
            NidoLiveActivityContent(attributes: context.attributes)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.kind == "sleep" ? "moon.fill" : "figure.and.child.holdinghands")
                        .foregroundStyle(accent(context.attributes.kind))
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
                    .foregroundStyle(accent(context.attributes.kind))
                    .privacySensitive()
            } compactTrailing: {
                Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 70)
                    .privacySensitive()
            } minimal: {
                Image(systemName: context.attributes.kind == "sleep" ? "moon.fill" : "figure.and.child.holdinghands")
                    .foregroundStyle(accent(context.attributes.kind))
                    .privacySensitive()
            }
        }
    }
}

private struct NidoLiveActivityContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    let attributes: NidoActivityAttributes

    private var tint: Color {
        let appearance: CareAppearance = contrast == .increased
            ? (colorScheme == .dark ? .highContrastDark : .highContrastLight)
            : (colorScheme == .dark ? .dark : .light)
        return Color(NidoCarePalette.ink(for: attributes.kind == "sleep" ? .sleep : .feed, appearance: appearance))
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: attributes.kind == "sleep" ? "moon.fill" : "figure.and.child.holdinghands")
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(attributes.kind == "sleep" ? "Sueño en curso" : "Lactancia en curso")
                    .font(.headline)
                Text(attributes.babyName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(timerInterval: attributes.startedAt...Date.distantFuture, countsDown: false)
                .font(.headline.monospacedDigit())
                .foregroundStyle(tint)
        }
        .padding(16)
        .privacySensitive()
        .activityBackgroundTint(Color(uiColor: .systemBackground))
        .activitySystemActionForegroundColor(Color(red: 0.32, green: 0.43, blue: 0.37))
    }
}
