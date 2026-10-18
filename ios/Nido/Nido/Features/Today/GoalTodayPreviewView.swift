#if DEBUG
import SwiftUI

/// Native design checkpoint. Sample targets remain isolated from household data.
struct GoalTodayPreviewView: View {
    @Environment(NidoStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var sleepGoal: Int?
    @State private var feedGoal: Int?
    @State private var diaperGoal: Int?
    @State private var isEditingGoals = false
    private let scenario: String

    init(scenario: String) {
        self.scenario = scenario
        let unset = scenario == "goal-design-unset"
        _sleepGoal = State(initialValue: unset ? nil : 720)
        _feedGoal = State(initialValue: unset ? nil : 8)
        _diaperGoal = State(initialValue: unset ? nil : 6)
    }

    private var sleep: Int { scenario == "goal-design-over" ? 780 : 558 }
    private var feeds: Int { scenario == "goal-design-over" ? 10 : 5 }
    private var diapers: Int { scenario == "goal-design-over" ? 7 : 4 }
    private var summaryLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
    }

    var body: some View {
        GeometryReader { viewport in
            let ringSize = min(max(viewport.size.width - 80, 200), 294)
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        HStack {
                            Text("Objetivos de hoy")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NidoTheme.readableSupportingInk)
                            Spacer()
                            Button { isEditingGoals = true } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 17, weight: .medium))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(NidoTheme.moss)
                            .accessibilityLabel("Ajustar objetivos")
                        }
                        .padding(.top, 10)

                        GoalRingsView(
                            sleep: Double(sleep), sleepGoal: sleepGoal.map(Double.init),
                            feed: Double(feeds), feedGoal: feedGoal.map(Double.init),
                            diaper: Double(diapers), diaperGoal: diaperGoal.map(Double.init),
                            size: ringSize
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .accessibilityIdentifier("goal-rings-preview")

                        summaryLayout {
                            metric(.sleep, value: sleep, goal: sleepGoal)
                            metric(.feed, value: feeds, goal: feedGoal)
                            metric(.diaper, value: diapers, goal: diaperGoal)
                        }
                        .padding(.bottom, 16)

                        recentActivity
                        Text("Datos y objetivos de ejemplo")
                            .font(.caption)
                            .foregroundStyle(NidoTheme.readableSupportingInk)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isEditingGoals) {
            GoalPreviewEditor(sleep: $sleepGoal, feeds: $feedGoal, diapers: $diaperGoal)
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("sábado, 17 de octubre")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NidoTheme.readableSupportingInk)
                Text("Hoy con Marco")
                    .nidoTitle(.hero)
                    .foregroundStyle(NidoTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button { store.selectedTab = .settings } label: {
                Text("M")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(NidoTheme.moss)
                    .frame(width: 46, height: 46)
                    .background(NidoTheme.surface.opacity(0.75), in: Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Abrir ajustes de Marco")
        }
        .padding(.top, 14)
    }

    private func metric(_ kind: EntryKind, value: Int, goal: Int?) -> some View {
        Button { isEditingGoals = true } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    CareCategoryIcon(category: kind.careCategory, size: 16, tint: NidoTheme.color(for: kind))
                    Text(kind == .sleep ? "Sueño" : kind == .feed ? "Tomas" : "Pañales")
                        .foregroundStyle(NidoTheme.ink)
                }
                .font(.subheadline.weight(.semibold))
                quantity(kind, value: value)
                    .font(.system(.largeTitle, design: .rounded, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(NidoTheme.ink)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Text(goal.map { kind == .sleep ? "de \($0 / 60) h" : "de \($0)" } ?? "Sin objetivo")
                    .font(.subheadline)
                    .foregroundStyle(NidoTheme.readableSupportingInk)
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.title)
        .accessibilityValue(spokenValue(kind, value: value, goal: goal))
        .accessibilityHint("Ajustar los objetivos de Marco")
        .accessibilityIdentifier("goal-summary-\(kind.rawValue)")
    }

    private func quantity(_ kind: EntryKind, value: Int) -> Text {
        guard kind == .sleep else { return Text("\(value)") }
        return Text("\(value / 60)")
            + Text(" h ").font(.subheadline)
            + Text(String(format: "%02d", value % 60))
            + Text(" min").font(.caption)
    }

    private func spokenValue(_ kind: EntryKind, value: Int, goal: Int?) -> String {
        if kind == .sleep {
            let amount = "\(value / 60) horas y \(value % 60) minutos"
            return goal.map { "\(amount) de \($0 / 60) horas" } ?? "\(amount), sin objetivo"
        }
        return goal.map { "\(value) de \($0) \(kind == .feed ? "tomas" : "pañales")" }
            ?? "\(value) \(kind == .feed ? "tomas" : "pañales"), sin objetivo"
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lo último de Marco")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(NidoTheme.ink)
                Spacer()
                Button("Ver todo") { store.showHistory(on: store.now) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NidoTheme.moss)
                    .frame(minWidth: 44, minHeight: 44)
            }
            VStack(spacing: 0) {
                activityRow(.feed, title: "Toma de biberón", detail: "120 ml · Fórmula", time: "14:10")
                activityRow(.diaper, title: "Pañal cambiado", detail: "Pis y caca", time: "13:35")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            .paperCard(cornerRadius: 24)
        }
    }

    private func activityRow(_ kind: EntryKind, title: String, detail: String, time: String) -> some View {
        HStack(alignment: .center, spacing: 13) {
            CareCategoryIcon(category: kind.careCategory, size: 18, tint: NidoTheme.color(for: kind))
                .frame(width: 38, height: 38)
                .background(NidoTheme.chartAccent(for: kind).opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(NidoTheme.ink)
                Text(detail).font(.caption).foregroundStyle(NidoTheme.readableSupportingInk)
            }
            Spacer(minLength: 4)
            Text(time).font(.caption.monospacedDigit()).foregroundStyle(NidoTheme.readableSupportingInk)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

private struct GoalPreviewEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sleep: Int?
    @Binding var feeds: Int?
    @Binding var diapers: Int?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Sueño · \((sleep ?? 720) / 60) h", value: value($sleep, fallback: 720), in: 60...1_440, step: 60)
                        .accessibilityIdentifier("goal-editor-sleep")
                    Stepper("Tomas · \(feeds ?? 8)", value: value($feeds, fallback: 8), in: 1...30)
                        .accessibilityIdentifier("goal-editor-feed")
                    Stepper("Pañales · \(diapers ?? 6)", value: value($diapers, fallback: 6), in: 1...30)
                        .accessibilityIdentifier("goal-editor-diaper")
                } footer: {
                    Text("Objetivos de ejemplo para esta vista previa. Todavía no se guardan en el perfil del bebé.")
                }
            }
            .navigationTitle("Objetivos de Marco")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .accessibilityIdentifier("goal-editor-done")
                }
            }
        }
        .tint(NidoTheme.moss)
    }

    private func value(_ source: Binding<Int?>, fallback: Int) -> Binding<Int> {
        Binding(get: { source.wrappedValue ?? fallback }, set: { source.wrappedValue = $0 })
    }
}
#endif
