import SwiftUI

struct GrowthOverviewView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.calendar) private var environmentCalendar
    @Environment(\.timeZone) private var environmentTimeZone
    @Environment(\.locale) private var locale
    @State private var editingMeasurement: GrowthMeasurement?
    @State private var isAddingMeasurement = false
    @State private var measurementToDelete: GrowthMeasurement?

    private var measurements: [GrowthMeasurement] {
        BabyCareReconciliation.mergedMeasurements(state: store.babyCareState, entries: store.entries)
    }

    private var familyCalendar: Calendar {
        var calendar = BabyCareMetrics.calendar(for: store.babyCareState)
        calendar.locale = locale
        calendar.firstWeekday = environmentCalendar.firstWeekday
        calendar.minimumDaysInFirstWeek = environmentCalendar.minimumDaysInFirstWeek
        if TimeZone(identifier: store.babyCareState.timeZoneID) == nil {
            calendar.timeZone = environmentTimeZone
        }
        return calendar
    }

    private var latestWeight: GrowthMeasurement? {
        measurements.reversed().first { $0.weightGrams != nil }
    }

    private var latestHeight: GrowthMeasurement? {
        measurements.reversed().first { $0.heightMillimeters != nil }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if measurements.isEmpty {
                        emptyState
                    } else {
                        latestMeasurements
                        history
                    }

                    GrowthSyncStatus(store: store)
                        .padding(.horizontal, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.calendar, familyCalendar)
        .environment(\.timeZone, familyCalendar.timeZone)
        .environment(\.locale, locale)
        .navigationTitle("Crecimiento")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingMeasurement = true
                } label: {
                    Label("Añadir medición", systemImage: "plus")
                }
                .accessibilityIdentifier("growth.add")
            }
        }
        .sheet(isPresented: $isAddingMeasurement) {
            GrowthMeasurementEditorView(existing: nil)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingMeasurement) { measurement in
            GrowthMeasurementEditorView(existing: measurement)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "¿Eliminar esta medición?",
            isPresented: Binding(
                get: { measurementToDelete != nil },
                set: { if !$0 { measurementToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: measurementToDelete
        ) { measurement in
            Button("Eliminar medición", role: .destructive) {
                Task {
                    _ = await store.deleteGrowthMeasurement(id: measurement.id)
                    measurementToDelete = nil
                }
            }
            Button("Cancelar", role: .cancel) { measurementToDelete = nil }
        }
        .accessibilityIdentifier("growth.overview")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "ruler")
                .font(.system(size: 29, weight: .medium))
                .foregroundStyle(NidoTheme.moss)
                .frame(width: 54, height: 54)
                .background(NidoTheme.moss.opacity(0.12), in: Circle())
            Text("Un lugar para sus medidas")
                .font(.title2.weight(.semibold))
                .foregroundStyle(NidoTheme.ink)
            Text("Guarda el peso o la talla con su fecha. Cada medida conservará su propio día.")
                .font(.body)
                .foregroundStyle(NidoTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                isAddingMeasurement = true
            } label: {
                Label("Añadir primera medición", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(NidoTheme.prominentActionFill)
            .accessibilityIdentifier("growth.add")
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
        .accessibilityIdentifier("growth.empty")
    }

    private var latestMeasurements: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Últimas medidas")
                .font(.title2.weight(.semibold))
                .foregroundStyle(NidoTheme.ink)

            latestLayout {
                latestLink(.weight, measurement: latestWeight)
                latestLink(.height, measurement: latestHeight)
            }
        }
        .padding(20)
        .paperCard()
    }

    private var latestLayout: AnyLayout {
        textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
    }

    private func latestLink(_ metric: GrowthMetric, measurement: GrowthMeasurement?) -> some View {
        NavigationLink {
            GrowthSeriesDetailView(metric: metric)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                latestValue(metric, measurement: measurement)
                Spacer(minLength: 2)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("growth.series.\(metric.rawValue)")
    }

    private func latestValue(_ metric: GrowthMetric, measurement: GrowthMeasurement?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(metric.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(NidoTheme.secondaryInk)
            if let measurement, let amount = metric.formattedAmount(in: measurement) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(amount)
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(NidoTheme.ink)
                        .accessibilityIdentifier("growth.latest.\(metric.rawValue).value")
                    Text(metric.unit)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(NidoTheme.secondaryInk)
                }
                Text(Self.dateLabel(for: measurement, calendar: familyCalendar, locale: locale))
                    .font(.caption)
                    .foregroundStyle(NidoTheme.secondaryInk)
                    .accessibilityIdentifier("growth.latest.\(metric.rawValue).date")
            } else {
                Text("Sin mediciones")
                    .font(.subheadline)
                    .foregroundStyle(NidoTheme.secondaryInk)
                    .accessibilityLabel("\(metric.title): sin mediciones")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historial")
                .font(.title2.weight(.semibold))
                .foregroundStyle(NidoTheme.ink)
            VStack(spacing: 0) {
                ForEach(measurements.reversed()) { measurement in
                    GrowthRecordRow(measurement: measurement, calendar: familyCalendar) {
                        editingMeasurement = measurement
                    } onDelete: {
                        measurementToDelete = measurement
                    }
                    if measurement.id != measurements.first?.id {
                        Divider().overlay(NidoTheme.separator.opacity(0.55)).padding(.leading, 16)
                    }
                }
            }
            .padding(.horizontal, 16)
            .paperCard()
        }
    }

    static func dateLabel(for measurement: GrowthMeasurement, calendar: Calendar, locale: Locale) -> String {
        dateLabel(
            Date(timeIntervalSince1970: Double(measurement.measuredAt) / 1_000),
            calendar: calendar,
            locale: locale
        )
    }

    static func dateLabel(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
        style.locale = locale
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }
}

struct GrowthRecordRow: View {
    let measurement: GrowthMeasurement
    let calendar: Calendar
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        ViewThatFits(in: .horizontal) {
            rowContent(horizontal: true)
            rowContent(horizontal: false)
        }
        .padding(.vertical, 14)
    }

    private func rowContent(horizontal: Bool) -> some View {
        Group {
            if horizontal {
                HStack(alignment: .center, spacing: 10) {
                    dateAndValues
                    Spacer(minLength: 4)
                    actions
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    dateAndValues
                    actions
                }
            }
        }
    }

    private var dateAndValues: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(GrowthOverviewView.dateLabel(for: measurement, calendar: calendar, locale: locale))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NidoTheme.ink)
            let values = GrowthMetric.allCases.compactMap { metric in
                metric.formattedValue(in: measurement).map { "\(metric.title) \($0)" }
            }
            Text(values.joined(separator: " · "))
                .font(.footnote)
                .foregroundStyle(NidoTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            if !measurement.note.isEmpty {
                Text(measurement.note)
                    .font(.footnote)
                    .foregroundStyle(NidoTheme.secondaryInk)
                    .lineLimit(3)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button("Editar", systemImage: "pencil", action: onEdit)
                .labelStyle(.iconOnly)
                .accessibilityLabel("Editar medición del \(GrowthOverviewView.dateLabel(for: measurement, calendar: calendar, locale: locale))")
                .accessibilityIdentifier("growth.measurement.edit")
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .accessibilityLabel("Eliminar medición del \(GrowthOverviewView.dateLabel(for: measurement, calendar: calendar, locale: locale))")
            .accessibilityIdentifier("growth.measurement.delete")
        }
        .buttonStyle(.bordered)
    }
}
