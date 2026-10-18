import SwiftUI
import WidgetKit

/// Used by the widget extension and native visual validation.
struct NidoDayWidgetContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    let snapshot: NidoWidgetSnapshot
    let family: WidgetFamily
    let renderingMode: WidgetRenderingMode

    private var appearance: CareAppearance {
        if contrast == .increased {
            return colorScheme == .dark ? .highContrastDark : .highContrastLight
        }
        return colorScheme == .dark ? .dark : .light
    }

    private var ink: Color { colorScheme == .dark ? .white : Color(red: 0.15, green: 0.20, blue: 0.17) }
    private var brand: Color { colorScheme == .dark ? Color(red: 0.65, green: 0.80, blue: 0.71) : Color(red: 0.27, green: 0.39, blue: 0.32) }
    private var captionInk: Color { renderingMode == .fullColor ? ink.opacity(0.72) : .primary }

    private func tint(_ category: CareCategory) -> Color {
        guard renderingMode == .fullColor else { return .primary }
        let value = NidoCarePalette.ink(for: category, appearance: appearance)
        return Color(.sRGB, red: value.red, green: value.green, blue: value.blue)
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .systemMedium: medium
            default: small
            }
        }
        .foregroundStyle(renderingMode == .fullColor ? ink : .primary)
        .privacySensitive()
    }

    private var header: some View {
        HStack(spacing: 5) {
            NidoBrandSymbol(tint: renderingMode == .fullColor ? brand : .primary)
                .frame(width: 18, height: 18)
            Text("Nido")
                .font(.caption.weight(.semibold))
                .foregroundStyle(renderingMode == .fullColor ? brand : .primary)
            Spacer(minLength: 0)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 8)
            if let kind = snapshot.activeKind, let startedAt = snapshot.activeStartedAt {
                activeStatus(kind: kind, startedAt: startedAt)
            } else {
                Text("Hoy con \(snapshot.babyName)")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .lineLimit(2)
                Spacer(minLength: 8)
                HStack(alignment: .top, spacing: 0) {
                    compactMetric(.sleep, value: shortSleepLabel)
                    Spacer(minLength: 3)
                    compactMetric(.feed, value: "\(snapshot.feeds)")
                    Spacer(minLength: 3)
                    compactMetric(.diaper, value: "\(snapshot.diapers)")
                }
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 8)
                if let kind = snapshot.activeKind, let startedAt = snapshot.activeStartedAt {
                    activeStatus(kind: kind, startedAt: startedAt)
                } else {
                    Text("Hoy con \(snapshot.babyName)")
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .lineLimit(2)
                    if let latestLabel {
                        Text(latestLabel)
                            .font(.caption)
                            .foregroundStyle(captionInk)
                            .padding(.top, 5)
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 9) {
                metricRow(.sleep, value: shortSleepLabel, goal: snapshot.sleepGoalMinutes.map { shortDuration($0) })
                metricRow(.feed, value: "\(snapshot.feeds)", goal: snapshot.feedGoal.map(String.init))
                metricRow(.diaper, value: "\(snapshot.diapers)", goal: snapshot.diaperGoal.map(String.init))
            }
        }
    }

    private func compactMetric(_ category: CareCategory, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            CareCategoryIcon(category: category, size: 13, tint: tint(category))
                .widgetAccentable()
            Text(value).font(.caption.weight(.semibold).monospacedDigit())
            Text(title(category)).font(.system(.caption2)).foregroundStyle(captionInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title(category)), \(value)")
    }

    private func metricRow(_ category: CareCategory, value: String, goal: String?) -> some View {
        HStack(spacing: 7) {
            CareCategoryIcon(category: category, size: 15, tint: tint(category))
                .frame(width: 17)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                Text(title(category)).font(.caption2).foregroundStyle(captionInk)
                Text(value + (goal.map { " / \($0)" } ?? ""))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category == .sleep
            ? "Sueño, \(sleepLabel)" + (snapshot.sleepGoalMinutes.map { ", objetivo \(duration($0))" } ?? "")
            : "\(title(category)), \(value)" + (goal.map { ", objetivo \($0)" } ?? ""))
    }

    private func activeGlyph(_ kind: String) -> some View {
        Group {
            if kind == "sleep" {
                CareCategoryIcon(category: .sleep, size: 16, tint: tint(.sleep))
            } else {
                Image(systemName: "figure.and.child.holdinghands")
                    .foregroundStyle(tint(.feed))
                    .accessibilityHidden(true)
            }
        }
        .widgetAccentable()
    }

    private func activeStatus(kind: String, startedAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                activeGlyph(kind)
                Text(kind == "sleep" ? "Sueño en curso" : "Lactancia en curso")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(captionInk)
            }
            Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit()
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                if let kind = snapshot.activeKind, let startedAt = snapshot.activeStartedAt {
                    activeGlyph(kind)
                    Text(startedAt, style: .timer)
                        .font(.system(size: 9, weight: .semibold, design: .rounded)).monospacedDigit()
                        .accessibilityLabel(kind == "sleep" ? "Sueño en curso" : "Lactancia en curso")
                        .accessibilityValue(Text(startedAt, style: .timer))
                } else {
                    CareCategoryIcon(category: .sleep, size: 16, tint: tint(.sleep)).widgetAccentable()
                    Text(shortSleepLabel).font(.caption2.bold())
                        .accessibilityLabel("Sueño, \(sleepLabel)")
                }
            }
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        if snapshot.activeKind != nil, snapshot.activeStartedAt != nil {
            rectangularSummary
        } else {
            ViewThatFits(in: .vertical) {
                rectangularSummary
                HStack(alignment: .top, spacing: 8) {
                    accessoryMetric(.sleep, value: shortSleepLabel)
                    Spacer(minLength: 0)
                    accessoryMetric(.feed, value: "\(snapshot.feeds)")
                    Spacer(minLength: 0)
                    accessoryMetric(.diaper, value: "\(snapshot.diapers)")
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Nido, \(snapshot.babyName)")
            }
        }
    }

    private func accessoryMetric(_ category: CareCategory, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title(category)).font(.caption2).foregroundStyle(captionInk)
            Text(value).font(.caption.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title(category)), \(category == .sleep ? sleepLabel : value)")
    }

    private var rectangularSummary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nido · \(snapshot.babyName)").font(.headline)
            if let kind = snapshot.activeKind, let startedAt = snapshot.activeStartedAt {
                HStack(spacing: 5) {
                    activeGlyph(kind)
                    Text(kind == "sleep" ? "Sueño" : "Lactancia")
                    Text(startedAt, style: .timer).monospacedDigit()
                }
                .font(.caption)
            } else {
                Text("\(sleepLabel) sueño · \(snapshot.feeds) tomas · \(snapshot.diapers) pañales")
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func title(_ category: CareCategory) -> String {
        switch category {
        case .sleep: "Sueño"
        case .feed: "Tomas"
        case .diaper: "Pañales"
        case .health: "Cuidados"
        }
    }

    private func duration(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    private var sleepLabel: String { duration(snapshot.sleepMinutes) }
    private var shortSleepLabel: String {
        shortDuration(snapshot.sleepMinutes)
    }
    private func shortDuration(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
    private var latestLabel: String? {
        guard let kind = snapshot.latestKind, let date = snapshot.latestDate else { return nil }
        let label = switch kind {
        case "sleep": "Sueño"
        case "feed": "Toma"
        case "diaper": "Pañal"
        default: "Cuidado"
        }
        return "Último: \(label) · \(date.formatted(date: .omitted, time: .shortened))"
    }
}
