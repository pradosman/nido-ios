import SwiftUI

struct HistoryView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filter: EntryKind?
    @State private var selectedDay: Date?
    @State private var isPresentingCalendar = false

    private var calendar: Calendar { .current }
    private var today: Date { calendar.startOfDay(for: store.now) }
    private var selection: Date { selectedDay ?? today }
    private var summary: HistoryPresentation.DaySummary {
        HistoryPresentation.summary(on: selection, entries: store.entries, now: store.now, calendar: calendar)
    }
    private var selectedEntries: [Entry] {
        HistoryPresentation.entries(on: selection, entries: store.entries, filter: filter, calendar: calendar)
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    dayPicker
                    weekStrip
                    SelectedDaySummary(date: selection, summary: summary)
                    filterBar
                    records
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .refreshable { await store.refresh() }
        }
        .navigationTitle("Historia")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $isPresentingCalendar) {
            HistoryCalendarSheet(
                selectedDay: selection,
                today: today,
                entries: store.entries,
                onSelect: select
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var dayPicker: some View {
        Button {
            isPresentingCalendar = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(NidoTheme.moss)
                    .frame(width: 44, height: 44)
                    .background(NidoTheme.moss.opacity(0.11), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Día seleccionado")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NidoTheme.secondaryInk)
                    Text(dayTitle(selection))
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(NidoTheme.ink)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NidoTheme.secondaryInk)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperCard(cornerRadius: 20)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Elegir día, \(accessibleDayTitle(selection))")
        .accessibilityHint("Abre el calendario mensual")
        .accessibilityIdentifier("history-day-picker")
    }

    private var weekStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 4) {
                ForEach(HistoryPresentation.sevenDayDates(around: selection, through: today, calendar: calendar), id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selection)
                    let daySummary = HistoryPresentation.summary(on: date, entries: store.entries, now: store.now, calendar: calendar)
                    Button { select(date) } label: {
                        VStack(spacing: 7) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(NidoTheme.secondaryInk)
                            CompactHistoryRings(summary: daySummary, size: 35, lineWidth: 4)
                                .overlay {
                                    Text(date.formatted(.dateTime.day()))
                                        .font(.caption2.weight(.bold).monospacedDigit())
                                        .foregroundStyle(NidoTheme.ink)
                                }
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.caption2)
                                .foregroundStyle(isSelected ? NidoTheme.moss : .clear)
                                .accessibilityHidden(true)
                        }
                        .frame(minWidth: 44)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                        .background(isSelected ? NidoTheme.moss.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(isSelected ? NidoTheme.moss : .clear, lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44)
                    .accessibilityLabel(dayAccessibilityLabel(date, summary: daySummary, isSelected: isSelected))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("history-week-day-\(dateIdentifier(date))")
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 7)
        }
        .defaultScrollAnchor(.trailing)
        .accessibilityIdentifier("history-week-strip")
        .paperCard(cornerRadius: 20)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton(title: "Todo", kind: nil)
                ForEach(EntryKind.allCases) { kind in
                    filterButton(title: kind.title, kind: kind)
                }
            }
        }
    }

    private var records: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Registros del día")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                Spacer()
                Text("\(selectedEntries.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(NidoTheme.secondaryInk)
            }

            if selectedEntries.isEmpty {
                ContentUnavailableView(
                    filter == nil ? "Sin registros este día" : "Sin registros de \(filter?.title.lowercased() ?? "este tipo")",
                    systemImage: "book.closed",
                    description: Text("Los registros guardados para este día aparecerán aquí.")
                )
                .foregroundStyle(NidoTheme.secondaryInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 38)
                .paperCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(selectedEntries) { entry in
                        Button { store.editingEntry = entry } label: {
                            HistoryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("history-entry-\(entry.id)")
                        .contextMenu {
                            Button { store.editingEntry = entry } label: { Label("Editar", systemImage: "pencil") }
                            Button(role: .destructive) { Task { await store.deleteEntry(entry) } } label: { Label("Eliminar", systemImage: "trash") }
                        }
                        if entry.id != selectedEntries.last?.id {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .paperCard()
            }
        }
    }

    private func filterButton(title: String, kind: EntryKind?) -> some View {
        let isSelected = filter == kind
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.16, extraBounce: 0)) { filter = kind }
        } label: {
            HStack(spacing: 6) {
                if let kind { Image(systemName: kind.symbolName).symbolRenderingMode(.hierarchical) }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? .white : NidoTheme.secondaryInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? NidoTheme.moss : NidoTheme.surface, in: Capsule())
            .overlay { Capsule().stroke(isSelected ? .clear : NidoTheme.separator.opacity(0.5), lineWidth: 0.5) }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select(_ date: Date) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22, extraBounce: 0)) {
            selectedDay = HistoryPresentation.select(date, through: today, calendar: calendar)
            isPresentingCalendar = false
        }
    }

    private func dayTitle(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return "Hoy, \(date.formatted(.dateTime.day().month(.wide)))" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func accessibleDayTitle(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    private func dayAccessibilityLabel(_ date: Date, summary: HistoryPresentation.DaySummary, isSelected: Bool) -> String {
        let selectionLabel = isSelected ? ", seleccionado" : ""
        return "\(accessibleDayTitle(date))\(selectionLabel), \(DurationLabel.minutes(summary.sleepMinutes)) de sueño, \(summary.feedCount) tomas, \(summary.diaperCount) pañales"
    }

    private func dateIdentifier(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    }
}

private struct SelectedDaySummary: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let date: Date
    let summary: HistoryPresentation.DaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 14) { rings; metrics }
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 18) { rings; metrics }
                }
            }
            Text("Escala visual: los anillos no representan objetivos médicos.")
                .font(.caption2)
                .foregroundStyle(NidoTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(dynamicTypeSize.isAccessibilitySize ? 20 : 16)
        .frame(maxWidth: .infinity)
        .paperCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide).day().month(.wide))), \(DurationLabel.minutes(summary.sleepMinutes)) de sueño, \(summary.feedCount) tomas, \(summary.diaperCount) pañales. Los anillos usan una escala visual y no representan objetivos médicos.")
        .accessibilityIdentifier("history-selected-day-summary")
    }

    private var rings: some View {
        CompactHistoryRings(summary: summary, size: dynamicTypeSize.isAccessibilitySize ? 142 : 138, lineWidth: 11)
            .overlay {
                VStack(spacing: 2) {
                    Text(date.formatted(.dateTime.day()))
                        .font(.system(.largeTitle, design: .serif, weight: .semibold).monospacedDigit())
                    Text(date.formatted(.dateTime.month(.abbreviated)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NidoTheme.secondaryInk)
                }
            }
            .accessibilityHidden(true)
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 8) {
            metric(kind: .sleep, value: DurationLabel.minutes(summary.sleepMinutes), note: "duración registrada")
            metric(kind: .feed, value: "\(summary.feedCount)", note: summary.feedCount == 1 ? "toma registrada" : "tomas registradas")
            metric(kind: .diaper, value: "\(summary.diaperCount)", note: summary.diaperCount == 1 ? "pañal registrado" : "pañales registrados")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(kind: EntryKind, value: String, note: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(NidoTheme.color(for: kind)).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title).font(.caption.weight(.semibold)).foregroundStyle(NidoTheme.secondaryInk)
                Text(value).font(.headline.monospacedDigit())
                Text(note).font(.caption2).foregroundStyle(NidoTheme.secondaryInk)
            }
        }
    }
}

private struct CompactHistoryRings: View {
    let summary: HistoryPresentation.DaySummary
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            ring(fraction: summary.sleepFillFraction, color: NidoTheme.sleep, inset: 0)
            ring(fraction: summary.feedFillFraction, color: NidoTheme.feed, inset: lineWidth * 1.25)
            ring(fraction: summary.diaperFillFraction, color: NidoTheme.diaper, inset: lineWidth * 2.5)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func ring(fraction: Double, color: Color, inset: CGFloat) -> some View {
        ZStack {
            Circle().inset(by: inset).stroke(color.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .inset(by: inset)
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct HistoryCalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var visibleMonth: Date
    let selectedDay: Date
    let today: Date
    let entries: [Entry]
    let onSelect: (Date) -> Void

    private var calendar: Calendar { .current }
    private var month: HistoryPresentation.Month {
        HistoryPresentation.month(containing: visibleMonth, through: today, calendar: calendar)
    }

    init(selectedDay: Date, today: Date, entries: [Entry], onSelect: @escaping (Date) -> Void) {
        self.selectedDay = selectedDay
        self.today = today
        self.entries = entries
        self.onSelect = onSelect
        _visibleMonth = State(initialValue: selectedDay)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    monthControls
                    weekdayHeader
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 14) {
                        ForEach(month.cells) { cell in
                            calendarCell(cell)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("history-calendar-grid")
                    Text("Cada día muestra sueño, tomas y pañales con la escala visual de Historia.")
                        .font(.footnote)
                        .foregroundStyle(NidoTheme.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .background(PaperBackground())
            .navigationTitle("Elegir día")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
            }
        }
    }

    private var monthControls: some View {
        HStack {
            Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel("Mes anterior")
            Spacer()
            Text(month.monthStart.formatted(.dateTime.month(.wide).year()))
                .font(.system(.title2, design: .serif, weight: .semibold))
            Spacer()
            Button { moveMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .accessibilityLabel("Mes siguiente")
                .disabled(!canMoveToNextMonth)
        }
        .foregroundStyle(NidoTheme.moss)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(calendar.veryShortWeekdaySymbols.shifted(by: calendar.firstWeekday - 1), id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(NidoTheme.secondaryInk)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func calendarCell(_ cell: HistoryPresentation.DayCell) -> some View {
        if let date = cell.date {
            let summary = HistoryPresentation.summary(on: date, entries: entries, now: today, calendar: calendar)
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDay)
            Button {
                guard cell.isSelectable else { return }
                onSelect(date)
            } label: {
                VStack(spacing: 5) {
                    CompactHistoryRings(summary: summary, size: 38, lineWidth: 4)
                        .overlay {
                            Text(date.formatted(.dateTime.day()))
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(cell.isSelectable ? NidoTheme.ink : NidoTheme.secondaryInk)
                        }
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? NidoTheme.moss : .clear)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(isSelected ? NidoTheme.moss.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(isSelected ? NidoTheme.moss : .clear, lineWidth: 1.5) }
                .opacity(cell.isSelectable ? 1 : 0.42)
            }
            .buttonStyle(.plain)
            .disabled(!cell.isSelectable)
            .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide).day().month(.wide))), \(DurationLabel.minutes(summary.sleepMinutes)) de sueño, \(summary.feedCount) tomas, \(summary.diaperCount) pañales")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("history-calendar-day-\(date.formatted(.iso8601.year().month().day().dateSeparator(.dash)))")
        } else {
            Color.clear.frame(height: 55).accessibilityHidden(true)
        }
    }

    private var canMoveToNextMonth: Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: month.monthStart) else { return false }
        let currentMonth = HistoryPresentation.month(containing: today, through: today, calendar: calendar).monthStart
        return nextMonth <= currentMonth
    }

    private func moveMonth(_ offset: Int) {
        guard let date = calendar.date(byAdding: .month, value: offset, to: month.monthStart) else { return }
        visibleMonth = date
    }
}

private struct HistoryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: Entry

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize { accessibilityLayout } else { standardLayout }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityHint("Toca para editar este registro")
    }

    private var standardLayout: some View {
        HStack(spacing: 10) {
            EntryGlyph(kind: entry.kind, size: 19)
            details
            Spacer()
            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.caption.monospacedDigit())
                .foregroundStyle(NidoTheme.secondaryInk)
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                EntryGlyph(kind: entry.kind, size: 19)
                Text(entry.title).font(.headline)
                Spacer(minLength: 8)
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
            if !entry.summary.isEmpty { Text(entry.summary).font(.body).foregroundStyle(NidoTheme.secondaryInk) }
            if let caregiverName = entry.caregiverName {
                Text("Registrado por \(caregiverName)").font(.caption).foregroundStyle(NidoTheme.secondaryInk)
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.title).font(.headline)
            if !entry.summary.isEmpty { Text(entry.summary).font(.subheadline).foregroundStyle(NidoTheme.secondaryInk) }
            if let caregiverName = entry.caregiverName {
                Label("Registrado por \(caregiverName)", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
        }
    }
}

private extension Array {
    func shifted(by offset: Int) -> [Element] {
        guard !isEmpty else { return self }
        let index = offset % count
        return Array(self[index...]) + Array(self[..<index])
    }
}
