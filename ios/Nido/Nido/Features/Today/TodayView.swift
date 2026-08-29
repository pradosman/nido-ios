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

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    prioritizedContent
                }
                .padding(.horizontal, 24)
            }
            .refreshable { await store.refresh() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    ForEach(EntryKind.allCases) { kind in
                        Button {
                            store.presentedEntryKind = kind
                        } label: {
                            Label("Registrar \(kind.title.lowercased())", systemImage: kind.symbolName)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Registrar una actividad")

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
    private var prioritizedContent: some View {
        pageHeader
        SleepCard()
            .padding(.top, 12)
        if !dynamicTypeSize.isAccessibilitySize {
            storyHeader
        }
        dayPager
        todayStatusCards
    }

    @ViewBuilder
    private var todayStatusCards: some View {
        if isTodaySelected {
            if store.activeFeedStartedAt != nil {
                ActiveFeedCard()
                    .padding(.top, 10)
            }
        }
        Color.clear.frame(height: 28)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isTodaySelected ? selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)) : "El día de \(profile.babyName)")
                .font(.system(.subheadline, design: .serif, weight: .medium))
                .italic()
                .foregroundStyle(NidoTheme.secondaryInk)
                .textCase(.lowercase)
            Text(isTodaySelected ? "Hoy con \(profile.babyName)" : selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .nidoTitle(.hero)
                .lineLimit(2)
                .accessibilityIdentifier("timeline-day-heading")
        }
        .padding(.top, 10)
    }

    private var storyHeader: some View {
        HStack(spacing: 14) {
            Text(isTodaySelected ? "Actividad de hoy" : "Actividad del día")
                .font(.system(.subheadline, design: .serif, weight: .medium))
                .italic()
                .foregroundStyle(NidoTheme.secondaryInk)
            Rectangle()
                .fill(NidoTheme.secondaryInk.opacity(0.24))
                .frame(height: 0.5)
        }
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var dayPager: some View {
        VStack(spacing: 4) {
            dayControls
            TabView(selection: $selectedDay) {
                ForEach(dayDates, id: \.self) { date in
                    CircularTimelineDayView(
                        day: CircularTimeline.day(
                            on: date,
                            entries: store.entries,
                            activeSleepStartedAt: store.activeSleepStartedAt,
                            now: store.now
                        ),
                        selectedEntryID: $selectedEntryID,
                        expandedClusterID: $expandedClusterID
                    )
                    .tag(date)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 510 : 326)
        }
    }

    private var dayControls: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    moveDay(by: -1)
                } label: {
                    Label("Día anterior", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                }
                .disabled(dayDates.first == selectedDay)
                .accessibilityLabel("Día anterior")
                .opacity(dayDates.first == selectedDay ? 0.28 : 1)

                Spacer()
                Text(isTodaySelected ? "Hoy" : selectedDay.formatted(.dateTime.day().month(.wide)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NidoTheme.secondaryInk)
                Spacer()

                Button {
                    moveDay(by: 1)
                } label: {
                    Label("Día siguiente", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                }
                .disabled(isTodaySelected)
                .accessibilityLabel("Día siguiente")
                .opacity(isTodaySelected ? 0.28 : 1)
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

private struct ActiveFeedCard: View {
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
                            .foregroundStyle(.white.opacity(0.75))
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
                .background(NidoTheme.feed, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityHint("Finaliza y guarda la lactancia")
        }
    }

    private var adaptiveLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 14))
    }
}

private struct SleepCard: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isEditingStart = false

    var body: some View {
        if let start = store.activeSleepStartedAt {
            adaptiveLayout {
                if !dynamicTypeSize.isAccessibilitySize {
                    EntryGlyph(kind: .sleep, size: 28)
                }

                Button {
                    isEditingStart = true
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                    Text("\(store.profile?.babyName ?? "El bebé") está durmiendo")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(context.date.timeIntervalSince(start).durationLabel)
                                .font(.headline.monospacedDigit())
                        }
                        .id(start)
                        Label(
                            "Desde \(start.formatted(date: .abbreviated, time: .shortened))",
                            systemImage: "pencil"
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
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
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityHint("Finaliza y guarda el sueño")
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(NidoTheme.sleep)
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
                                .foregroundStyle(NidoTheme.secondaryInk)
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
                        .background(NidoTheme.moss, in: Capsule())
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
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
