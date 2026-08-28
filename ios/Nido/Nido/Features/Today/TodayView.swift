import SwiftUI

struct TodayView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var profile: Profile {
        store.profile ?? Profile(caregiverName: "", babyName: "Bebé", birthDate: "")
    }

    private var todayEntries: [Entry] {
        NidoMetrics.entries(on: .now, from: store.entries)
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    pageHeader
                    SleepCard()
                        .padding(.top, 24)
                    if store.activeFeedStartedAt != nil {
                        ActiveFeedCard()
                            .padding(.top, 12)
                    }
                    storyHeader
                    timeline
                        .padding(.bottom, 36)
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
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.system(.subheadline, design: .serif, weight: .medium))
                .italic()
                .foregroundStyle(NidoTheme.secondaryInk)
                .textCase(.lowercase)
            Text("Hoy con \(profile.babyName)")
                .nidoTitle(.hero)
                .lineLimit(2)
        }
        .padding(.top, 18)
    }

    private var storyHeader: some View {
        HStack(spacing: 14) {
            Text("Actividad de hoy")
                .font(.system(.subheadline, design: .serif, weight: .medium))
                .italic()
                .foregroundStyle(NidoTheme.secondaryInk)
            Rectangle()
                .fill(NidoTheme.secondaryInk.opacity(0.24))
                .frame(height: 0.5)
        }
        .padding(.top, 42)
        .padding(.bottom, 26)
    }

    @ViewBuilder
    private var timeline: some View {
        if todayEntries.isEmpty {
            EmptyStoryView()
        } else {
            LazyVStack(spacing: 0) {
                ForEach(todayEntries) { entry in
                    TimelineEntryRow(entry: entry, isLast: entry.id == todayEntries.last?.id)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.22, extraBounce: 0), value: todayEntries.map(\.id))
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
                EntryGlyph(kind: .sleep, size: 28)

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
            .background(NidoTheme.sleep, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
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
                    EntryGlyph(kind: .sleep, size: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sueño")
                            .font(.caption)
                            .foregroundStyle(NidoTheme.secondaryInk)
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

private struct EmptyStoryView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(NidoTheme.moss)
                    .frame(width: 32, height: 32)
                Rectangle()
                    .fill(NidoTheme.secondaryInk.opacity(0.2))
                    .frame(width: 1, height: 92)
            }
            Text("Todavía no hay registros de hoy.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(NidoTheme.secondaryInk)
                .lineSpacing(5)
                .padding(.top, 6)
        }
    }
}

private struct TimelineEntryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: Entry
    let isLast: Bool

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityLayout
        } else {
            standardLayout
        }
    }

    private var standardLayout: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(NidoTheme.secondaryInk)
                .frame(width: 44, alignment: .leading)
                .padding(.top, 4)

            VStack(spacing: 0) {
                EntryGlyph(kind: entry.kind, size: 19)
                    .frame(width: 30, height: 30)
                if !isLast {
                    Rectangle()
                        .fill(NidoTheme.secondaryInk.opacity(0.2))
                        .frame(width: 1)
                        .frame(minHeight: 58)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(NidoTheme.ink)
                Text(entry.summary)
                    .font(.subheadline)
                    .foregroundStyle(NidoTheme.secondaryInk)
                    .lineLimit(2)
                if let caregiverName = entry.caregiverName {
                    Text("Por \(caregiverName)")
                        .font(.caption)
                        .foregroundStyle(NidoTheme.secondaryInk.opacity(0.82))
                }
            }
            .padding(.top, 3)
            Spacer()
        }
        .frame(minHeight: 82, alignment: .top)
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                EntryGlyph(kind: entry.kind, size: 19)
                    .frame(width: 34, height: 34)
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(NidoTheme.ink)
                Spacer(minLength: 8)
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
            if !entry.summary.isEmpty {
                Text(entry.summary)
                    .font(.body)
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
            if let caregiverName = entry.caregiverName {
                Text("Por \(caregiverName)")
                    .font(.caption)
                    .foregroundStyle(NidoTheme.secondaryInk)
            }
            if !isLast {
                Divider()
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 8)
    }
}

private extension TimeInterval {
    var durationLabel: String {
        let total = max(0, Int(self))
        return String(format: "%02d:%02d:%02d", total / 3_600, (total % 3_600) / 60, total % 60)
    }
}

extension Entry {
    var summary: String {
        let pieces: [String?] = [
            durationMinutes.map { "\($0) min" },
            amountMl.map { "\($0) ml" },
            detail.isEmpty ? nil : detail,
        ]
        return pieces.compactMap { $0 }.joined(separator: " · ")
    }
}
