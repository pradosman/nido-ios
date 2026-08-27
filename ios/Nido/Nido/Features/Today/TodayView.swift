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
                        .padding(.top, 34)
                    if store.activeFeedStartedAt != nil {
                        ActiveFeedCard()
                            .padding(.top, 12)
                    }
                    storyHeader
                    timeline
                        .padding(.bottom, 126)
                }
                .padding(.horizontal, 24)
            }
            .refreshable { await store.refresh() }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                QuickCaptureBar()
                    .padding(.bottom, 8)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.selectedTab = .settings } label: {
                    Text(profile.initials)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(NidoTheme.moss, in: Circle())
                }
                .accessibilityLabel("Abrir ajustes de \(profile.babyName)")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.system(.subheadline, design: .serif, weight: .medium))
                .italic()
                .foregroundStyle(NidoTheme.secondaryInk)
                .textCase(.lowercase)
            Text("Hoy con \(profile.babyName)")
                .editorialTitle(44)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
            Text(todayEntries.isEmpty ? "Un día nuevo, todavía por escribir." : "Cada pequeño momento va encontrando su lugar.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(NidoTheme.secondaryInk)
        }
        .padding(.top, 18)
    }

    private var storyHeader: some View {
        HStack(spacing: 14) {
            Text("La historia de hoy")
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

    var body: some View {
        if let start = store.activeFeedStartedAt {
            Button {
                Task { await store.finishFeed() }
            } label: {
                HStack(spacing: 14) {
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
}

private struct SleepCard: View {
    @Environment(NidoStore.self) private var store

    var body: some View {
        Button {
            Task { await store.toggleSleep() }
        } label: {
            HStack(spacing: 14) {
                EntryGlyph(kind: .sleep, size: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(store.activeSleepStartedAt == nil ? "Primer descanso" : "El sueño está en curso")
                        .font(.caption)
                        .foregroundStyle(store.activeSleepStartedAt == nil ? NidoTheme.secondaryInk : .white.opacity(0.72))
                    if let start = store.activeSleepStartedAt {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(context.date.timeIntervalSince(start).durationLabel)
                                .font(.headline.monospacedDigit())
                        }
                    } else {
                        Text("Empezar sueño")
                            .font(.headline)
                    }
                }
                .foregroundStyle(store.activeSleepStartedAt == nil ? NidoTheme.ink : .white)

                Spacer(minLength: 8)

                Text(store.activeSleepStartedAt == nil ? "Iniciar" : "Terminar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(store.activeSleepStartedAt == nil ? .white : .black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(store.activeSleepStartedAt == nil ? NidoTheme.moss : .white, in: Capsule())
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(store.activeSleepStartedAt == nil ? .white.opacity(0.48) : NidoTheme.sleep, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 0.7)
            }
            .shadow(color: NidoTheme.ink.opacity(0.05), radius: 16, y: 7)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityHint(store.activeSleepStartedAt == nil ? "Inicia el temporizador de sueño" : "Finaliza y guarda el sueño")
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
            Text("El primer registro aparecerá aquí como un momento del día, no como una cifra en un panel.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(NidoTheme.secondaryInk)
                .lineSpacing(5)
                .padding(.top, 6)
        }
    }
}

private struct TimelineEntryRow: View {
    let entry: Entry
    let isLast: Bool

    var body: some View {
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
}

private struct QuickCaptureBar: View {
    @Environment(NidoStore.self) private var store

    var body: some View {
        HStack(spacing: 2) {
            captureButton(.feed)
            captureButton(.diaper)
            captureButton(.health)
            captureButton(.sleep)
        }
        .padding(8)
        .frame(width: 320, height: 68)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.72), lineWidth: 0.7))
        .shadow(color: NidoTheme.ink.opacity(0.14), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
    }

    private func captureButton(_ kind: EntryKind) -> some View {
        Button { store.presentedEntryKind = kind } label: {
            VStack(spacing: 1) {
                EntryGlyph(kind: kind, size: 20)
                    .frame(height: 30)
                Text(kind.title).font(.caption2)
            }
            .foregroundStyle(NidoTheme.secondaryInk)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Registrar \(kind.title.lowercased())")
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
