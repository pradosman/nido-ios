import SwiftUI

struct SleepEvolutionRecordsView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.locale) private var locale
    @Environment(\.floatingNavigationClearance) private var floatingNavigationClearance

    let recordIDs: [String]
    let period: SleepEvolutionPeriod
    private let previewEntries: [Entry]?
    private let previewCalendar: Calendar?

    init(recordIDs: [String], period: SleepEvolutionPeriod) {
        self.recordIDs = recordIDs
        self.period = period
        previewEntries = nil
        previewCalendar = nil
    }

    init(entries: [Entry], recordIDs: [String], period: SleepEvolutionPeriod, calendar: Calendar) {
        self.recordIDs = recordIDs
        self.period = period
        previewEntries = entries
        previewCalendar = calendar
    }

    private var isLive: Bool { previewEntries == nil }

    private var calendar: Calendar {
        if let previewCalendar { return previewCalendar }
        return BabyCareMetrics.calendar(for: store.babyCareState, locale: locale)
    }

    private var sourceEntries: [Entry] { previewEntries ?? store.entries }

    private var canEditRecords: Bool {
        guard isLive,
              store.phase == .ready,
              let caregiver = store.currentCaregiver else { return false }
        return caregiver.status == .active
    }

    private var records: [Entry] {
        let identifiers = Set(recordIDs)
        return sourceEntries
            .filter { entry in
                guard identifiers.contains(entry.id),
                      entry.kind == .sleep,
                      let duration = entry.durationMinutes,
                      duration > 0 else { return false }
                let start = entry.date.addingTimeInterval(-TimeInterval(duration * 60))
                return start < period.end && entry.date > period.start
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            List {
                Section {
                    if records.isEmpty {
                        ContentUnavailableView(
                            "Sin registros",
                            systemImage: "moon.zzz",
                            description: Text("No hay registros de sueño guardados en este intervalo.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(records) { entry in
                            recordRow(entry)
                        }
                    }
                } header: {
                    Text(periodLabel)
                        .textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, floatingNavigationClearance, for: .scrollContent)
        }
        .navigationTitle("Registros de sueño")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("sleep-evolution-records")
    }

    private var periodLabel: String {
        "\(SleepEvolutionDateFormatting.recordDate(for: period.start, calendar: calendar, locale: locale)) – \(SleepEvolutionDateFormatting.recordDate(for: period.end.addingTimeInterval(-1), calendar: calendar, locale: locale))"
    }

    @ViewBuilder
    private func recordRow(_ entry: Entry) -> some View {
        if canEditRecords {
            Button {
                guard canEditRecords else { return }
                store.editingEntry = entry
            } label: {
                recordContent(entry)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    guard canEditRecords else { return }
                    store.editingEntry = entry
                } label: {
                    Label("Editar", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    guard canEditRecords else { return }
                    Task { await store.deleteEntry(entry) }
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            }
            .accessibilityIdentifier("sleep-evolution-record-\(entry.id)")
        } else {
            recordContent(entry)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("sleep-evolution-record-\(entry.id)")
        }
    }

    private func recordContent(_ entry: Entry) -> some View {
        let end = entry.date
        let start = end.addingTimeInterval(-TimeInterval((entry.durationMinutes ?? 0) * 60))
        return VStack(alignment: .leading, spacing: 6) {
            Text(SleepEvolutionDateFormatting.recordDate(for: end, calendar: calendar, locale: locale))
                .font(.headline)
                .foregroundStyle(NidoTheme.ink)
            HStack(alignment: .firstTextBaseline) {
                Text("\(SleepEvolutionDateFormatting.time(for: start, calendar: calendar, locale: locale)) – \(SleepEvolutionDateFormatting.time(for: end, calendar: calendar, locale: locale))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(NidoTheme.readableSupportingInk)
                Spacer(minLength: 8)
                Text(DurationLabel.minutes(entry.durationMinutes ?? 0))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(NidoTheme.sleep)
            }
            if !calendar.isDate(start, inSameDayAs: end) {
                Text("Empezó el día anterior")
                    .font(.caption)
                    .foregroundStyle(NidoTheme.readableSupportingInk)
            }
        }
        .padding(.vertical, 7)
        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.88))
    }
}
