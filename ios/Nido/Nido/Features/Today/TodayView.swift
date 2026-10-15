import SwiftUI

struct TodayView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var selectedEntryID: String?
    @State private var expandedClusterID: String?

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
        return CircularTimeline.availableDates(earliest: earliest, through: store.now)
    }

    private var isTodaySelected: Bool {
        Calendar.current.isDate(selectedDay, inSameDayAs: store.now)
    }

    private var selectedTimelineDay: CircularTimeline.Day {
        CircularTimeline.day(
            on: selectedDay,
            entries: store.entries,
            activeSleepStartedAt: store.activeSleepStartedAt,
            now: store.now
        )
    }

    var body: some View {
        GeometryReader { viewport in
            // Use the available viewport, but preserve multiline layouts for accessibility text sizes.
            let compactHeight = viewport.size.height < 560 && !dynamicTypeSize.isAccessibilitySize
            ZStack {
                PaperBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        prioritizedContent(compactHeight: compactHeight)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, compactHeight ? -12 : 0)
                .refreshable { await store.refresh() }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.selectedTab = .settings } label: {
                    Image(systemName: "person.crop.circle")
                }
                .accessibilityLabel("Abrir ajustes de \(profile.babyName)")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedDay = Calendar.current.startOfDay(for: store.now)
        }
        .onChange(of: selectedDay) { _, _ in
            selectedEntryID = nil
            expandedClusterID = nil
        }
    }

    @ViewBuilder
    private func prioritizedContent(compactHeight: Bool) -> some View {
        pageHeader(compactHeight: compactHeight)
        SleepCard(compactHeight: compactHeight)
            .padding(.top, compactHeight ? 0 : 12)
        if isTodaySelected, store.activeFeedStartedAt != nil {
            ActiveFeedCard()
                .padding(.top, 10)
        }
        storyHeader
        dayPager(compactHeight: compactHeight)
        DayTimelineActivity(
            day: selectedTimelineDay,
            isToday: isTodaySelected,
            selectedEntryID: $selectedEntryID,
            onEdit: { store.editingEntry = $0 },
            onShowAll: { store.selectedTab = .history }
        )
        .padding(.top, 24)
        Color.clear.frame(height: 28)
    }

    private func pageHeader(compactHeight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if compactHeight {
                HStack(spacing: 0) {
                    Text(isTodaySelected ? "Hoy con \(profile.babyName)" : selectedDay.formatted(.dateTime.day().month(.abbreviated)))
                        .nidoTitle(.screen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityLabel(isTodaySelected ? "Hoy con \(profile.babyName)" : selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .accessibilityIdentifier("timeline-day-heading")

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
                if !dynamicTypeSize.isAccessibilitySize && store.activeSleepStartedAt == nil {
                    Text(isTodaySelected ? selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)) : "El día de \(profile.babyName)")
                        .font(.system(.subheadline, design: .serif, weight: .medium))
                        .italic()
                        .foregroundStyle(NidoTheme.ink.opacity(0.9))
                        .textCase(.lowercase)
                }
                Text(isTodaySelected ? "Hoy con \(profile.babyName)" : selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .nidoTitle(.hero)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .accessibilityIdentifier("timeline-day-heading")
                    .accessibilityValue(
                        (dynamicTypeSize.isAccessibilitySize || store.activeSleepStartedAt != nil) && isTodaySelected
                            ? selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide))
                            : ""
                    )
            }
        }
        .padding(.top, compactHeight ? 0 : 10)
    }

    private var storyHeader: some View {
        HStack(spacing: 14) {
            Text(isTodaySelected ? "Actividad de hoy" : "Actividad del día")
                .font(.system(.subheadline, design: .serif, weight: .medium))
                .italic()
                .foregroundStyle(NidoTheme.sectionHeadingInk)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Rectangle()
                .fill(NidoTheme.secondaryInk.opacity(0.24))
                .frame(height: 0.5)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func dayPager(compactHeight: Bool) -> some View {
        VStack(spacing: compactHeight ? 0 : 4) {
            if !compactHeight {
                dayControls
            }
            if dynamicTypeSize.isAccessibilitySize {
                timeline(for: selectedDay)
            } else {
                TabView(selection: $selectedDay) {
                    ForEach(dayDates, id: \.self) { date in
                        timeline(for: date)
                            .tag(date)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 350)
            }
        }
    }

    private func timeline(for date: Date) -> some View {
        TimelineView(.everyMinute) { context in
            CircularTimelineDayView(
                day: CircularTimeline.day(
                    on: date,
                    entries: store.entries,
                    activeSleepStartedAt: store.activeSleepStartedAt,
                    now: store.currentDate(for: context.date)
                ),
                selectedEntryID: $selectedEntryID,
                expandedClusterID: $expandedClusterID
            )
        }
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
                    Text(isToday ? "Hoy" : day.date.formatted(.dateTime.day().month(.wide)))
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(NidoTheme.ink)
                    Text("Actividad del día")
                        .font(.caption)
                        .foregroundStyle(NidoTheme.readableSupportingInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }
                Button(action: onShowAll) {
                    Text("Ver todo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NidoTheme.moss)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }

            VStack(spacing: 0) {
                if items.isEmpty {
                    Label("Sin registros este día", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(NidoTheme.secondaryInk)
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
                            .foregroundStyle(.white)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(context.date.timeIntervalSince(start).durationLabel)
                                .font(.headline.monospacedDigit())
                        }
                    }
                    .foregroundStyle(.white)
                    Spacer()
                    Text("Terminar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                }
                .padding(14)
                .background(NidoTheme.activeFeedFill, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
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
                            .foregroundStyle(.white)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(context.date.timeIntervalSince(start).durationLabel)
                                .font(.headline.monospacedDigit())
                        }
                        .id(start)
                        Label(
                            "Desde \(compactHeight ? start.formatted(.dateTime.day().month(.abbreviated).hour().minute()) : start.formatted(date: .abbreviated, time: .shortened))",
                            systemImage: "pencil"
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                    }
                    .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("Editar hora de inicio, \(start.formatted(date: .abbreviated, time: .shortened))")
                .accessibilityHint("Abre el selector de fecha y hora")

                Spacer(minLength: 8)

                Button {
                    Task { await store.toggleSleep() }
                } label: {
                    Text("Terminar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 45)
                        .background(.white, in: Capsule())
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
                    .fill(NidoTheme.activeSleepFill)
                    .accessibilityElement()
                    .accessibilityLabel("Estado del sueño de hoy")
                    .accessibilityIdentifier("sleep-status-card")
            }
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 0.7)
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
                        EntryGlyph(kind: .sleep, size: 28)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        if !dynamicTypeSize.isAccessibilitySize {
                            Text("Sueño de hoy")
                                .font(.caption)
                                .foregroundStyle(NidoTheme.readableSupportingInk)
                        }
                        Text("Registrar sueño")
                            .font(.headline)
                            .foregroundStyle(NidoTheme.ink)
                    }
                    Spacer(minLength: 8)
                    Text("Iniciar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(NidoTheme.prominentActionFill, in: Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, compactHeight ? 9 : 14)
                .frame(maxWidth: .infinity)
                .background(NidoTheme.surface, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(.white.opacity(0.72), lineWidth: 0.7)
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
