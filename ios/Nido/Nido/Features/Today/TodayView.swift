import SwiftUI

struct TodayView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var selectedEntryID: String?
    @State private var expandedClusterID: String?
    @State private var isHeaderOutsideViewport = false
    @State private var pageHeadingSize = CGSize.zero
    @State private var dateHeadingSize = CGSize.zero
    @State private var isEditingGoals = false
    private var calendar: Calendar { BabyCareMetrics.calendar(for: store.babyCareState) }

    private var profile: Profile {
        store.profile ?? Profile(caregiverName: "", babyName: "Bebé", birthDate: "")
    }

    private var dayDates: [Date] {
        let birthDate = ISO8601DateFormatter.nidoDay.date(from: profile.birthDate)
        let entryStarts = store.entries.map { entry in
            guard entry.kind == .sleep, let duration = entry.durationMinutes else { return entry.date }
            return entry.date.addingTimeInterval(-TimeInterval(duration * 60))
        }
        let earliest = ([birthDate].compactMap { $0 } + entryStarts).min() ?? store.now
        return CircularTimeline.availableDates(earliest: earliest, through: store.now, calendar: calendar)
    }

    private var isTodaySelected: Bool {
        calendar.isDate(selectedDay, inSameDayAs: store.now)
    }

    private var selectedTimelineDay: CircularTimeline.Day {
        CircularTimeline.day(
            on: selectedDay,
            entries: store.entries,
            activeSleepStartedAt: store.activeSleepStartedAt,
            now: store.now,
            calendar: calendar
        )
    }

    @ViewBuilder
    var body: some View {
        #if DEBUG
        if let scenario = store.goalDesignPreviewScenario {
            GoalTodayPreviewView(scenario: scenario)
        } else {
            timelineBody
        }
        #else
        timelineBody
        #endif
    }

    private var timelineBody: some View {
        GeometryReader { viewport in
            // Use the available viewport, but preserve multiline layouts for accessibility text sizes.
            let compactHeight = viewport.size.height < 560 && !dynamicTypeSize.isAccessibilitySize
            ZStack {
                PaperBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        prioritizedContent(
                            compactHeight: compactHeight,
                            availableWidth: viewport.size.width - 48,
                            viewportTop: viewport.frame(in: .global).minY + viewport.safeAreaInsets.top
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, compactHeight ? -12 : 0)
                .refreshable { await store.refresh() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedDay = calendar.startOfDay(for: store.now)
        }
        .sheet(isPresented: $isEditingGoals) {
            CareGoalEditor(state: store.babyCareState, now: store.now)
        }
        .onChange(of: selectedDay) { _, _ in
            selectedEntryID = nil
            expandedClusterID = nil
        }
    }

    @ViewBuilder
    private func prioritizedContent(compactHeight: Bool, availableWidth: CGFloat, viewportTop: CGFloat) -> some View {
        pageHeader(compactHeight: compactHeight, viewportTop: viewportTop)
        HStack {
            Text(isTodaySelected ? "Objetivos de hoy" : "Objetivos de este día")
                .font(.subheadline.weight(.semibold)).foregroundStyle(NidoTheme.readableSupportingInk)
            Spacer()
            if !compactHeight {
                dayNavigationButton(offset: -1)
                dayNavigationButton(offset: 1)
            }
            if store.canEditGoals {
                Button { isEditingGoals = true } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                }
                .foregroundStyle(NidoTheme.moss)
                .accessibilityLabel("Ajustar objetivos")
                .accessibilityIdentifier("today-edit-goals")
            }
        }
        .padding(.top, 10)
        if !isTodaySelected && !compactHeight {
            Button(action: returnToToday) {
                Label("Volver a hoy", systemImage: "arrow.uturn.forward")
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            }
            .foregroundStyle(NidoTheme.moss)
            .accessibilityIdentifier("timeline-return-today")
        }
        dayPager(compactHeight: compactHeight, availableWidth: availableWidth)
        BabyCareSyncStatus()
        if let selectedEntryID,
           let item = selectedTimelineDay.items.first(where: { $0.entry.id == selectedEntryID }) {
            selectedRecord(item)
                .padding(.top, 12)
        } else if isTodaySelected {
            if store.activeFeedStartedAt != nil {
                ActiveFeedCard()
                    .padding(.top, 12)
            }
            SleepCard(compactHeight: compactHeight)
                .padding(.top, store.activeFeedStartedAt == nil ? 12 : 10)
        }
        DayTimelineActivity(
            day: selectedTimelineDay,
            isToday: isTodaySelected,
            selectedEntryID: $selectedEntryID,
            onEdit: { store.editingEntry = $0 },
            onShowAll: { store.showHistory(on: selectedDay) }
        )
        .padding(.top, 20)
        Color.clear.frame(height: 28)
    }

    private func selectedRecord(_ item: CircularTimeline.Item) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label {
                    Text(item.entry.title)
                } icon: {
                    CareCategoryIcon(
                        category: item.entry.kind.careCategory,
                        size: 16,
                        tint: NidoTheme.color(for: item.entry.kind)
                    )
                }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NidoTheme.color(for: item.entry.kind))
                Spacer(minLength: 8)
                Button {
                    selectedEntryID = nil
                    expandedClusterID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NidoTheme.readableSupportingInk)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Volver al estado actual")
                .accessibilityIdentifier("today-clear-selection")
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.entry.summary.isEmpty ? item.entry.title : item.entry.summary)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(NidoTheme.ink)
                        .contentTransition(.opacity)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: item.entry.id)
                    Text(selectedRecordTime(item))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(NidoTheme.readableSupportingInk)
                    if let caregiver = item.entry.caregiverName, !caregiver.isEmpty {
                        Text(caregiver)
                            .font(.caption)
                            .foregroundStyle(NidoTheme.readableSupportingInk)
                    }
                }
                Spacer(minLength: 8)
                Button("Editar") { store.editingEntry = item.entry }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NidoTheme.moss)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(NidoTheme.moss.opacity(0.08), in: Capsule())
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .paperCard(cornerRadius: 23)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today-selected-record")
    }

    private func selectedRecordTime(_ item: CircularTimeline.Item) -> String {
        guard item.presentation == .sleepSegment else {
            return item.entry.date.formatted(date: .omitted, time: .shortened)
        }
        func clock(_ minute: Int) -> String {
            let bounded = min(max(minute, 0), 1_440)
            return String(format: "%02d:%02d", bounded / 60, bounded % 60)
        }
        return "\(clock(item.startMinute))–\(clock(item.endMinute))"
    }

    private func pageHeader(compactHeight: Bool, viewportTop: CGFloat) -> some View {
        return VStack(alignment: .leading, spacing: 6) {
            if compactHeight {
                HStack(spacing: 0) {
                    if isHeaderOutsideViewport, pageHeadingSize != .zero {
                        Color.clear.frame(width: pageHeadingSize.width, height: pageHeadingSize.height)
                    } else {
                        Text(isTodaySelected ? "Hoy con \(profile.babyName)" : selectedDay.formatted(.dateTime.day().month(.abbreviated)))
                            .nidoTitle(.screen)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .accessibilityLabel(isTodaySelected ? "Hoy con \(profile.babyName)" : selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .accessibilityIdentifier("timeline-day-heading")
                            .onGeometryChange(for: CGSize.self) { $0.size } action: { pageHeadingSize = $0 }
                    }

                    Spacer(minLength: 4)
                    dayNavigationButton(offset: -1)
                    dayNavigationButton(offset: 1)
                    if !isTodaySelected {
                        Button(action: returnToToday) {
                            Image(systemName: "arrow.uturn.forward")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Volver a hoy")
                        .accessibilityIdentifier("timeline-return-today")
                        .foregroundStyle(NidoTheme.moss)
                    }
                }
            } else {
                if !dynamicTypeSize.isAccessibilitySize {
                    if isHeaderOutsideViewport, dateHeadingSize != .zero {
                        Color.clear.frame(width: dateHeadingSize.width, height: dateHeadingSize.height)
                    } else {
                        Text(isTodaySelected ? selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)) : "El día de \(profile.babyName)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(NidoTheme.ink.opacity(0.9))
                            .textCase(.lowercase)
                            .accessibilityIdentifier("timeline-date-heading")
                            .onGeometryChange(for: CGSize.self) { $0.size } action: { dateHeadingSize = $0 }
                    }
                }
                if isHeaderOutsideViewport, pageHeadingSize != .zero {
                    Color.clear.frame(width: pageHeadingSize.width, height: pageHeadingSize.height)
                } else {
                    Text(isTodaySelected ? "Hoy con \(profile.babyName)" : selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .nidoTitle(.hero)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .accessibilityIdentifier("timeline-day-heading")
                        .accessibilityValue(
                            (dynamicTypeSize.isAccessibilitySize || store.activeSleepStartedAt != nil) && isTodaySelected
                                ? selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide))
                                : ""
                        )
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { pageHeadingSize = $0 }
                }
            }
        }
        .padding(.top, compactHeight ? 0 : 10)
        .padding(.trailing, compactHeight ? 0 : 52)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            if !compactHeight && !isHeaderOutsideViewport {
                Button { store.selectedTab = .settings } label: {
                    Text(String(profile.babyName.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(NidoTheme.moss)
                        .frame(width: 44, height: 44)
                        .background(NidoTheme.surface, in: Circle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Abrir ajustes de \(profile.babyName)")
                .padding(.top, 10)
            }
        }
        .accessibilityHidden(isHeaderOutsideViewport)
        .onGeometryChange(for: Bool.self) { geometry in
            geometry.frame(in: .global).maxY <= viewportTop
        } action: { isOutside in
            isHeaderOutsideViewport = isOutside
        }
    }

    private func dayPager(compactHeight: Bool, availableWidth: CGFloat) -> some View {
        let ringSize = max(100, min(availableWidth, dynamicTypeSize.isAccessibilitySize ? 250 : 294))
        return
        VStack(spacing: compactHeight ? 0 : 4) {
            if dynamicTypeSize.isAccessibilitySize {
                timeline(for: selectedDay, size: ringSize)
            } else {
                TabView(selection: $selectedDay) {
                    ForEach(dayDates, id: \.self) { date in
                        timeline(for: date, size: ringSize)
                            .tag(date)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: ringSize + (dynamicTypeSize > .large ? 150 : 116))
            }
        }
    }

    private func timeline(for date: Date, size: CGFloat) -> some View {
        GoalDayPanel(date: date, size: size, summaryIdentifierPrefix: "day-goal-summary") { _ in store.showHistory(on: date) }
            .accessibilityIdentifier("today-goal-rings")
    }

    private var dayControls: some View {
        VStack(spacing: 0) {
            HStack {
                dayNavigationButton(offset: -1)

                Spacer()
                Text(isTodaySelected ? "Hoy" : selectedDay.formatted(.dateTime.day().month(.wide)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NidoTheme.sectionHeadingInk)
                Spacer()

                dayNavigationButton(offset: 1)
            }

            if !isTodaySelected {
                Button {
                    returnToToday()
                } label: {
                    Label("Volver a hoy", systemImage: "arrow.uturn.forward")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("timeline-return-today")
            }
        }
        .foregroundStyle(NidoTheme.moss)
    }

    private func dayNavigationButton(offset: Int) -> some View {
        let isDisabled = offset < 0 ? dayDates.first == selectedDay : isTodaySelected
        let title = offset < 0 ? "Día anterior" : "Día siguiente"
        return Button {
            moveDay(by: offset)
        } label: {
            Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
                .frame(width: 44, height: 44)
        }
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .opacity(isDisabled ? 0.28 : 1)
        .foregroundStyle(NidoTheme.moss)
    }

    private func moveDay(by offset: Int) {
        let navigation: CircularTimeline.Navigation = offset < 0 ? .previous : .next
        let destination = CircularTimeline.destination(
            for: navigation,
            from: selectedDay,
            availableDates: dayDates,
            through: store.now
        )
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24, extraBounce: 0)) {
            selectedDay = destination
        }
    }

    private func returnToToday() {
        selectedEntryID = nil
        expandedClusterID = nil
        let destination = CircularTimeline.destination(
            for: .today,
            from: selectedDay,
            availableDates: dayDates,
            through: store.now
        )
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24, extraBounce: 0)) {
            selectedDay = destination
        }
    }
}

struct DayTimelineActivity: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: CircularTimeline.Day
    let isToday: Bool
    @Binding var selectedEntryID: String?
    let onEdit: (Entry) -> Void
    let onShowAll: () -> Void

    private var items: [CircularTimeline.Item] {
        day.items.sorted { $0.startMinute < $1.startMinute }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            activityHeaderLayout {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Actividad del día")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(NidoTheme.ink)
                    let careCount = day.items.filter { $0.entry.kind == .health }.count
                    if careCount > 0 {
                        TimelineCareSummary(count: careCount)
                    }
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }
                Button(action: onShowAll) {
                    Text("Ver todo")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(NidoTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .tint(NidoTheme.ink)
            }

            VStack(spacing: 0) {
                if items.isEmpty {
                    Label("Sin registros este día", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(NidoTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .padding(.horizontal, 14)
                } else {
                    ForEach(items) { item in
                        HStack(spacing: 0) {
                            Button {
                                selectedEntryID = item.entry.id
                            } label: {
                                activityRow(item)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in onEdit(item.entry) }
                            )
                            .accessibilityLabel(activityAccessibilityLabel(item))
                            .accessibilityHint("Toca para seleccionar. Mantén pulsado para editar.")
                            .accessibilityIdentifier("timeline-activity-\(item.entry.id)")

                            Button { onEdit(item.entry) } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(NidoTheme.secondaryInk)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Editar \(item.entry.title)")
                            .accessibilityIdentifier("timeline-edit-activity-\(item.entry.id)")
                            .padding(.trailing, 8)
                        }

                        if item.id != items.last?.id {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
            }
            .paperCard(cornerRadius: 18)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Actividad del día, \(items.count) registros")
        .accessibilityIdentifier("timeline-day-activity-list")
    }

    private var activityHeaderLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout())
    }

    private func activityRow(_ item: CircularTimeline.Item) -> some View {
        HStack(spacing: 10) {
            EntryGlyph(kind: item.entry.kind, size: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.entry.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NidoTheme.ink)
                if !item.entry.summary.isEmpty {
                    Text(item.entry.summary)
                        .font(.caption)
                        .foregroundStyle(NidoTheme.secondaryInk)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(timeLabel(for: item))
                .font(.caption.monospacedDigit())
                .foregroundStyle(NidoTheme.secondaryInk)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private func activityAccessibilityLabel(_ item: CircularTimeline.Item) -> String {
        [item.entry.title, timeLabel(for: item), item.entry.summary]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func timeLabel(for item: CircularTimeline.Item) -> String {
        if item.presentation == .sleepSegment {
            return "\(clockLabel(item.startMinute))–\(clockLabel(item.endMinute))"
        }
        return clockLabel(item.startMinute)
    }

    private func clockLabel(_ minute: Int) -> String {
        let normalized = min(max(minute, 0), 1_440)
        if normalized == 1_440 { return "24:00" }
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }
}

struct ActiveFeedCard: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let start = store.activeFeedStartedAt {
            Button {
                Task { await store.finishFeed() }
            } label: {
                adaptiveLayout {
                    EntryGlyph(kind: .feed, size: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Lactancia en curso")
                            .font(.caption)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(context.date.timeIntervalSince(start).durationLabel)
                                .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                        }
                    }
                    .foregroundStyle(NidoTheme.ink)
                    Spacer()
                    Text("Terminar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NidoTheme.moss)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(NidoTheme.moss.opacity(0.08), in: Capsule())
                }
                .padding(14)
                .background(NidoTheme.surface, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityHint("Finaliza y guarda la lactancia")
            .accessibilityIdentifier("active-feed-card")
        }
    }

    private var adaptiveLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 14))
    }
}

struct SleepCard: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let compactHeight: Bool
    @State private var isEditingStart = false

    var body: some View {
        if let start = store.activeSleepStartedAt {
            adaptiveLayout {
                if !dynamicTypeSize.isAccessibilitySize && !compactHeight {
                    EntryGlyph(kind: .sleep, size: 28)
                }

                Button {
                    isEditingStart = true
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(store.profile?.babyName ?? "El bebé") está durmiendo")
                            .font(.caption)
                            .foregroundStyle(NidoTheme.ink)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(context.date.timeIntervalSince(start).durationLabel)
                                .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                        }
                        .id(start)
                        Label(
                            "Desde \(compactHeight ? start.formatted(.dateTime.day().month(.abbreviated).hour().minute()) : start.formatted(date: .abbreviated, time: .shortened))",
                            systemImage: "pencil"
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NidoTheme.readableSupportingInk)
                    }
                    .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(NidoTheme.ink)
                .accessibilityLabel("Editar hora de inicio, \(start.formatted(date: .abbreviated, time: .shortened))")
                .accessibilityHint("Abre el selector de fecha y hora")

                Spacer(minLength: 8)

                Button {
                    Task { await store.toggleSleep() }
                } label: {
                    Text("Terminar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NidoTheme.moss)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 45)
                        .background(NidoTheme.moss.opacity(0.08), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityHint("Finaliza y guarda el sueño")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, compactHeight ? 6 : 14)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(NidoTheme.surface)
                    .accessibilityElement()
                    .accessibilityLabel("Estado del sueño de hoy")
                    .accessibilityIdentifier("sleep-status-card")
            }
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(NidoTheme.separator.opacity(0.35), lineWidth: 0.5)
            }
            .shadow(color: NidoTheme.ink.opacity(0.05), radius: 16, y: 7)
            .sheet(isPresented: $isEditingStart) {
                ActiveSleepStartEditor(startedAt: start)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        } else {
            Button {
                Task { await store.toggleSleep() }
            } label: {
                adaptiveLayout {
                    if !dynamicTypeSize.isAccessibilitySize {
                        EntryGlyph(kind: .sleep, size: 21)
                    }
                    Text("Iniciar sueño")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NidoTheme.ink)
                    Spacer(minLength: 8)
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NidoTheme.moss)
                        .frame(width: 32, height: 32)
                        .background(NidoTheme.moss.opacity(0.08), in: Circle())
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, compactHeight ? 6 : 9)
                .frame(maxWidth: .infinity)
                .background(NidoTheme.surface, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(NidoTheme.separator.opacity(0.35), lineWidth: 0.5)
                }
                .shadow(color: NidoTheme.ink.opacity(0.05), radius: 16, y: 7)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityHint("Inicia el temporizador de sueño")
            .accessibilityIdentifier("sleep-status-card")
        }
    }

    private var adaptiveLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 14))
    }
}

private struct ActiveSleepStartEditor: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var startedAt: Date

    init(startedAt: Date) {
        _startedAt = State(initialValue: startedAt)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                DatePicker(
                    "Inicio del sueño",
                    selection: $startedAt,
                    in: ...Date.now,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("Lleva durmiendo \(context.date.timeIntervalSince(startedAt).durationLabel)")
                        .font(.subheadline)
                        .foregroundStyle(NidoTheme.secondaryInk)
                }
            }
            .padding(.horizontal, 20)
            .navigationTitle("Hora de inicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            await store.updateActiveSleepStart(startedAt)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private extension TimeInterval {
    var durationLabel: String {
        let total = max(0, Int(self))
        return String(format: "%02d:%02d:%02d", total / 3_600, (total % 3_600) / 60, total % 60)
    }
}
