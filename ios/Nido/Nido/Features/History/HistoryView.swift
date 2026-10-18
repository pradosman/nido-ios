import SwiftUI

struct HistoryView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var weekLabelLineHeight = 14
    @State private var filter: EntryKind?
    @State private var isPresentingCalendar = false
    @State private var selectedEntryID: String?
    @State private var expandedClusterID: String?
    @State private var selectedBins: [EntryKind: Date] = [:]
    @State private var displayedWeekOffset = 0
    @State private var readingContext = HistoryReadingContext()
    @State private var availableRingWidth: CGFloat = 294

    private var calendar: Calendar { BabyCareMetrics.calendar(for: store.babyCareState) }
    private var today: Date { calendar.startOfDay(for: store.now) }
    private var selection: Date { store.historySelectedDay ?? today }
    private var weekDates: [Date] {
        guard let shiftedDate = calendar.date(byAdding: .day, value: displayedWeekOffset * 7, to: selection) else { return [] }
        return HistoryPresentation.calendarWeekDates(containing: shiftedDate, calendar: calendar)
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            historyContent(now: store.currentDate(for: context.date))
        }
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            availableRingWidth = max(100, width - 40)
        }
    }

    @ViewBuilder private func historyContent(now: Date) -> some View {
        let snapshot = HistoryAnalytics.snapshot(
            on: selection,
            entries: store.entries,
            activeSleepStartedAt: store.activeSleepStartedAt,
            now: now,
            calendar: calendar
        )
        ZStack {
            PaperBackground()
            VStack(spacing: 0) {
                dayHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                weekStrip
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                if store.isOffline {
                    Text("Sin conexión. Mostrando lo guardado.")
                        .font(.caption)
                        .foregroundStyle(NidoTheme.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .accessibilityIdentifier("history-offline-status")
                }
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            dayClock(snapshot.day, onSelectCategory: { kind in
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                                    scrollProxy.scrollTo("history-section-\(kind.rawValue)", anchor: .top)
                                }
                            })
                            HistoryDayCharts(
                                snapshot: snapshot,
                                selectedBins: $selectedBins
                            )
                            filterBar
                            records(snapshot.entries)
                                .id("history-records")
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                    }
                    .coordinateSpace(name: "history-detail-scroll")
                    .accessibilityIdentifier("history-detail-scroll")
                    .onPreferenceChange(HistoryVisibleSectionPreferenceKey.self) { positions in
                        let frames = Dictionary(positions.map { ($0.kind, Double($0.minY)...Double($0.maxY)) }, uniquingKeysWith: { _, latest in latest })
                        readingContext.anchor = HistoryPresentation.readingAnchor(for: frames)
                    }
                    .onChange(of: selection) { _, _ in
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                            scrollProxy.scrollTo(readingContext.anchor, anchor: .top)
                        }
                    }
                    .refreshable { await store.refresh() }
                }
            }
        }
        .navigationTitle("Historia")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $isPresentingCalendar) {
            HistoryCalendarSheet(
                selectedDay: selection,
                today: today,
                now: store.now,
                activeSleepStartedAt: store.activeSleepStartedAt,
                entries: store.entries,
                calendar: calendar,
                onSelect: select
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selection) { _, _ in
            selectedEntryID = nil
            expandedClusterID = nil
            selectedBins = [:]
            displayedWeekOffset = 0
        }
    }

    private var dayHeader: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    dayDateLabel
                    navigationControls
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 6) {
                    dayDateLabel
                    Spacer(minLength: 2)
                    navigationControls
                }
            }
        }
        .foregroundStyle(NidoTheme.moss)
    }

    private var dayDateLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(dynamicTypeSize.isAccessibilitySize
                 ? selection.formatted(.dateTime.day().month(.abbreviated).year())
                 : selection.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.system(dynamicTypeSize.isAccessibilitySize ? .headline : .title3, design: .serif, weight: .semibold))
                .foregroundStyle(NidoTheme.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.88)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("history-detail-date")
                .accessibilityValue(dateIdentifier(selection))
                .accessibilityLabel(selection.formatted(date: .complete, time: .omitted))
            if !dynamicTypeSize.isAccessibilitySize {
                Text(selection.formatted(.dateTime.year()))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
        }
    }

    private var navigationControls: some View {
        HStack(spacing: 6) {
            Button { isPresentingCalendar = true } label: { Image(systemName: "calendar").font(dynamicTypeSize.isAccessibilitySize ? .system(size: 20) : .body).frame(width: 44, height: 44) }
                .accessibilityLabel("Elegir día, \(selection.formatted(date: .complete, time: .omitted))")
                .accessibilityHint("Abre el calendario mensual")
                .accessibilityIdentifier("history-day-picker")
            Button { select(today) } label: { Image(systemName: "calendar.badge.clock").font(dynamicTypeSize.isAccessibilitySize ? .system(size: 20) : .body).frame(width: 44, height: 44) }
                .disabled(calendar.isDate(selection, inSameDayAs: today))
                .accessibilityLabel("Ir a hoy")
                .accessibilityIdentifier("history-jump-today")
            Menu {
                Section("Día") {
                    Button("Día anterior", systemImage: "chevron.left") { stepDay(-1) }
                        .accessibilityIdentifier("history-previous-day")
                    Button("Día siguiente", systemImage: "chevron.right") { stepDay(1) }
                        .disabled(calendar.isDate(selection, inSameDayAs: today))
                        .accessibilityIdentifier("history-next-day")
                }
                Section("Semana") {
                    Button("Semana anterior", systemImage: "chevron.left") { displayedWeekOffset -= 1 }
                        .accessibilityIdentifier("history-previous-week")
                    Button("Semana siguiente", systemImage: "chevron.right") { displayedWeekOffset += 1 }
                        .disabled(!canShowNextWeek)
                        .accessibilityIdentifier("history-next-week")
                }
            } label: { Image(systemName: "ellipsis").font(dynamicTypeSize.isAccessibilitySize ? .system(size: 20) : .body).frame(width: 44, height: 44) }
                .accessibilityLabel("Más opciones de Historia")
                .accessibilityIdentifier("history-navigation-menu")
        }
    }

    private var weekStrip: some View {
        GeometryReader { geometry in
            ScrollViewReader { weekProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(weekDates, id: \.self) { date in
                        let isSelected = calendar.isDate(date, inSameDayAs: selection)
                        let day = CircularTimeline.day(on: date, entries: store.entries, activeSleepStartedAt: store.activeSleepStartedAt, now: store.now, calendar: calendar)
                        let isFuture = calendar.startOfDay(for: date) > today
                        Button { select(date) } label: {
                            VStack(spacing: 5) {
                                Text(date.formatted(.dateTime.weekday(.narrow)).uppercased())
                                    .font(.caption2.weight(.bold)).foregroundStyle(NidoTheme.secondaryInk)
                                HistoryMiniClock(day: day, size: 28, goals: BabyCareMetrics.goals(on: date, state: store.babyCareState))
                                Text(date.formatted(.dateTime.day()))
                                    .font(.caption.weight(isSelected ? .bold : .medium).monospacedDigit())
                                    .foregroundStyle(isSelected ? NidoTheme.moss : NidoTheme.ink)
                            }
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .contentShape(Rectangle())
                            .overlay(alignment: .bottom) {
                                Capsule().fill(isSelected ? NidoTheme.moss : .clear).frame(width: 18, height: 3).offset(y: 4)
                            }
                            .opacity(isFuture ? 0.4 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(isFuture)
                        .accessibilityLabel(weekAccessibilityLabel(date, day: day, selected: isSelected))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityIdentifier("history-week-day-\(dateIdentifier(date))")
                        .id(dateIdentifier(date))
                    }
                }
                .frame(width: max(geometry.size.width, 7 * (dynamicTypeSize.isAccessibilitySize ? max(44, weekLabelLineHeight * 1.8) : 44)), alignment: .leading)
                .padding(.vertical, 3)
            }
            .onAppear {
                if dynamicTypeSize.isAccessibilitySize {
                    weekProxy.scrollTo(dateIdentifier(selection), anchor: .center)
                }
            }
            .onChange(of: selection) { _, date in
                if dynamicTypeSize.isAccessibilitySize {
                    weekProxy.scrollTo(dateIdentifier(date), anchor: .center)
                }
            }
            }
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? weekLabelLineHeight * 2 + 44 : 62)
        .accessibilityIdentifier("history-week-strip")
    }

    private var canShowNextWeek: Bool {
        guard let first = weekDates.first,
              let nextWeek = calendar.date(byAdding: .day, value: 7, to: first) else { return false }
        return calendar.startOfDay(for: nextWeek) <= today
    }

    private func dayClock(_ day: CircularTimeline.Day, onSelectCategory: @escaping (EntryKind) -> Void) -> some View {
        VStack(spacing: 12) {
            GoalDayPanel(date: day.date, size: min(availableRingWidth, dynamicTypeSize.isAccessibilitySize ? 250 : 294), onSelect: onSelectCategory)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("history-goal-rings")
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 35).onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    stepDay(value.translation.width < 0 ? 1 : -1)
                })
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history-detail-day-\(dateIdentifier(day.date))")
        .id("history-detail-top")
    }


    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton(title: "Todo", kind: nil)
                ForEach(EntryKind.allCases) { kind in filterButton(title: kind.title, kind: kind) }
            }
        }
    }

    private func records(_ dayEntries: [Entry]) -> some View {
        let rows = dayEntries.filter { filter == nil || $0.kind == filter }
        let lastID = rows.last?.id
        let emptyTitle = filter == nil
            ? (store.isOffline ? "Sin registros guardados este día" : "Sin registros este día")
            : (store.isOffline ? "Sin registros guardados de este tipo" : "Sin registros de \(filter?.title.lowercased() ?? "este tipo")")
        let emptyDescription = store.isOffline
            ? "Al volver a conectar comprobaremos si hay más registros."
            : "Los registros guardados para este día aparecerán aquí."
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Registros del día").font(.system(.title3, design: .serif, weight: .semibold))
                Spacer()
                Text("\(rows.count)").font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(NidoTheme.secondaryInk)
            }
            if rows.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: "book.closed", description: Text(emptyDescription))
                    .foregroundStyle(NidoTheme.secondaryInk).frame(maxWidth: .infinity).padding(.vertical, 38).paperCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { entry in
                        Button { store.editingEntry = entry } label: { HistoryRow(entry: entry) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("history-entry-\(entry.id)")
                            .contextMenu {
                                Button { store.editingEntry = entry } label: { Label("Editar", systemImage: "pencil") }
                                Button(role: .destructive) { Task { await store.deleteEntry(entry) } } label: { Label("Eliminar", systemImage: "trash") }
                            }
                        if entry.id != lastID { Divider().padding(.leading, 54) }
                    }
                }
                .padding(.horizontal, 14).paperCard()
            }
        }
    }

    private func filterButton(title: String, kind: EntryKind?) -> some View {
        HistoryFilterButton(title: title, kind: kind, isSelected: filter == kind) {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.16, extraBounce: 0)) { filter = kind }
        }
    }

    private func stepDay(_ offset: Int) {
        guard let date = calendar.date(byAdding: .day, value: offset, to: selection) else { return }
        select(date)
    }

    private func select(_ date: Date) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22, extraBounce: 0)) {
            store.showHistory(on: HistoryPresentation.select(date, through: today, calendar: calendar))
            displayedWeekOffset = 0
            isPresentingCalendar = false
        }
    }

    private func dateIdentifier(_ date: Date) -> String {
        localDateIdentifier(date, calendar: calendar)
    }

    private func weekAccessibilityLabel(_ date: Date, day: CircularTimeline.Day, selected: Bool) -> String {
        let chosen = selected ? ", seleccionado" : ""
        let empty = day.items.isEmpty ? ", sin registros" : ""
        return "\(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))\(chosen)\(empty), \(duration(day.totalSleepSeconds)) de sueño, \(day.feedCount) tomas, \(day.diaperCount) pañales"
    }

    private func duration(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder) min" }
        if remainder == 0 { return "\(hours) h" }
        return "\(hours) h \(remainder) min"
    }


}

@MainActor
private final class HistoryReadingContext {
    // Navigation context is not rendered. Tracking scroll geometry must not redraw its producer.
    var anchor = "history-detail-top"
}

struct HistoryMiniClock: View {
    let day: CircularTimeline.Day
    let size: CGFloat
    var goals: CareGoalVersion? = nil

    var body: some View {
        GoalRingsView(sleep: Double(day.totalSleepSeconds) / 60, sleepGoal: goals?.sleepMinutes.map(Double.init),
            feed: Double(day.feedCount), feedGoal: goals?.feedCount.map(Double.init),
            diaper: Double(day.diaperCount), diaperGoal: goals?.diaperCount.map(Double.init), size: size)
        .accessibilityHidden(true)
    }
}

private struct HistoryCalendarSheet: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var viewportIsReady = false
    @State private var didInitialRequest = false
    @State private var visibleMonth: Date?
    let selectedDay: Date
    let today: Date
    let now: Date
    let activeSleepStartedAt: Date?
    let entries: [Entry]
    let onSelect: (Date) -> Void
    private let entriesByDay: [Date: [Entry]]
    private let calendar: Calendar

    init(selectedDay: Date, today: Date, now: Date, activeSleepStartedAt: Date?, entries: [Entry], calendar: Calendar = .current, onSelect: @escaping (Date) -> Void) {
        self.selectedDay = selectedDay
        self.today = today
        self.now = now
        self.activeSleepStartedAt = activeSleepStartedAt
        self.entries = entries
        self.calendar = calendar
        self.onSelect = onSelect
        self.entriesByDay = Self.index(entries, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: calendarSectionSpacing, pinnedViews: .sectionHeaders) {
                    ForEach(monthStarts, id: \.self) { monthStart in
                        Section {
                            monthPage(monthStart).padding(.bottom, calendarSectionSpacing)
                        } header: {
                            monthHeader(monthStart)
                        }
                        .id(monthStart)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 6)
                .padding(.vertical, calendarOuterPadding)
            }
            .scrollPosition(id: $visibleMonth, anchor: .top)
            .accessibilityIdentifier("history-calendar-scroll")
            .background(PaperBackground())
            .onGeometryChange(for: Bool.self) { geometry in
                let size = geometry.size
                return size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
            } action: { isReady in
                viewportIsReady = isReady
            }
            .onChange(of: viewportIsReady, initial: true) { _, isReady in
                guard isReady, !didInitialRequest else { return }
                didInitialRequest = true
                visibleMonth = monthStart(containing: selectedDay)
            }
            .navigationTitle("Elegir día")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.accessibilityIdentifier("history-calendar-close")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Hoy") { onSelect(today) }.accessibilityIdentifier("history-calendar-today")
                }
            }
        }
    }

    private let calendarSectionSpacing: CGFloat = 14
    private let calendarOuterPadding: CGFloat = 16

    private var monthStarts: [Date] {
        let firstRecordedDate = entries.compactMap { entry -> Date? in
            guard entry.kind == .sleep, let duration = entry.durationMinutes, duration > 0 else { return entry.date }
            return entry.date.addingTimeInterval(-TimeInterval(duration * 60))
        }.min()
        let fallback = calendar.date(byAdding: .year, value: -1, to: today) ?? selectedDay
        let earliest = min(firstRecordedDate ?? fallback, selectedDay)
        return HistoryPresentation.calendarMonths(from: earliest, through: today, calendar: calendar)
    }

    private func monthHeader(_ monthStartDate: Date) -> some View {
        VStack(spacing: 14) {
            Text(monthStartDate.formatted(.dateTime.month(.wide).year()))
                .font(.system(.title2, design: .serif, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .accessibilityIdentifier("history-calendar-month-\(monthIdentifier(monthStartDate))")
            HStack(spacing: 0) {
                ForEach(calendar.veryShortWeekdaySymbols.shifted(by: calendar.firstWeekday - 1), id: \.self) {
                    Text($0.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(NidoTheme.secondaryInk).frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 8)
        .foregroundStyle(NidoTheme.ink)
        .background(.regularMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history-calendar-header-\(monthIdentifier(monthStartDate))")
    }

    private func monthPage(_ monthStartDate: Date) -> some View {
        let month = HistoryPresentation.month(containing: monthStartDate, through: today, calendar: calendar)
        return VStack(spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 10) {
                ForEach(month.cells) { cell in calendarCell(cell) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(monthStartDate == monthStart(containing: selectedDay) ? "history-calendar-grid" : "history-calendar-grid-\(monthIdentifier(monthStartDate))")
            if monthStartDate == monthStarts.last {
                Text("Cada día muestra el progreso frente a los objetivos que tenía entonces. Los días sin objetivos conservan sus registros.")
                    .font(.footnote).foregroundStyle(NidoTheme.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
            }
        }
        .foregroundStyle(NidoTheme.ink)
    }

    private func monthStart(containing date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    }

    private func monthIdentifier(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    private static func index(_ entries: [Entry], calendar: Calendar) -> [Date: [Entry]] {
        var result: [Date: [Entry]] = [:]
        for entry in entries {
            let intervalStart: Date
            if entry.kind == .sleep, let duration = entry.durationMinutes, duration > 0 {
                intervalStart = entry.date.addingTimeInterval(-TimeInterval(duration * 60))
            } else {
                intervalStart = entry.date
            }
            var dayStart = calendar.startOfDay(for: intervalStart)
            while dayStart < entry.date || (entry.kind != .sleep && calendar.isDate(dayStart, inSameDayAs: entry.date)) {
                result[dayStart, default: []].append(entry)
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
                dayStart = nextDay
            }
        }
        return result
    }

    @ViewBuilder private func calendarCell(_ cell: HistoryPresentation.DayCell) -> some View {
        if let date = cell.date {
            let day = CircularTimeline.day(
                on: date,
                entries: entriesByDay[calendar.startOfDay(for: date)] ?? [],
                activeSleepStartedAt: activeSleepStartedAt,
                now: now,
                calendar: calendar
            )
            let selected = calendar.isDate(date, inSameDayAs: selectedDay)
            Button { if cell.isSelectable { onSelect(date) } } label: {
                VStack(spacing: 4) {
                    HistoryMiniClock(day: day, size: 37, goals: BabyCareMetrics.goals(on: date, state: store.babyCareState))
                    Text(date.formatted(.dateTime.day())).font(.caption2.weight(.medium).monospacedDigit()).foregroundStyle(NidoTheme.ink)
                }
                .frame(maxWidth: .infinity, minHeight: 57)
                .contentShape(Rectangle())
                .background(selected ? NidoTheme.moss.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? NidoTheme.moss : .clear, lineWidth: 1.5) }
                .opacity(cell.isSelectable ? 1 : 0.4)
            }
            .buttonStyle(.plain).disabled(!cell.isSelectable)
            .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide).day().month(.wide))), \(day.items.isEmpty ? "sin registros, " : "")\(DurationLabel.minutes(day.totalSleepSeconds / 60)) de sueño, \(day.feedCount) tomas, \(day.diaperCount) pañales")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("history-calendar-day-\(localDateIdentifier(date, calendar: calendar))")
        } else { Color.clear.frame(height: 57).accessibilityHidden(true) }
    }
}

private struct HistoryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: Entry
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        EntryGlyph(kind: entry.kind, size: 19)
                        Text(entry.title).font(.headline)
                    }
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption.monospacedDigit()).foregroundStyle(NidoTheme.secondaryInk)
                    if !entry.summary.isEmpty {
                        Text(entry.summary).font(.subheadline).foregroundStyle(NidoTheme.secondaryInk)
                    }
                    if let name = entry.caregiverName {
                        Label("Registrado por \(name)", systemImage: "person.fill")
                            .font(.caption).foregroundStyle(NidoTheme.secondaryInk)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
        HStack(spacing: 10) {
            EntryGlyph(kind: entry.kind, size: 19)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title).font(.headline)
                if !entry.summary.isEmpty { Text(entry.summary).font(.subheadline).foregroundStyle(NidoTheme.secondaryInk) }
                if let name = entry.caregiverName { Label("Registrado por \(name)", systemImage: "person.fill").font(.caption).foregroundStyle(NidoTheme.secondaryInk) }
            }
            Spacer(minLength: 8)
            Text(entry.date.formatted(date: .omitted, time: .shortened)).font(.caption.monospacedDigit()).foregroundStyle(NidoTheme.secondaryInk)
        }
            }
        }
        .padding(.vertical, 12).contentShape(Rectangle()).accessibilityHint("Toca para editar este registro")
    }
}

private func localDateIdentifier(_ date: Date, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
}

private extension Array {
    func shifted(by offset: Int) -> [Element] {
        guard !isEmpty else { return self }
        let index = offset % count
        return Array(self[index...]) + Array(self[..<index])
    }
}
