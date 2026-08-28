import SwiftUI

struct SleepDurationPicker: View {
    @Binding var totalMinutes: Int

    private let maximumHours = 12

    private var hours: Binding<Int> {
        Binding(
            get: { min(totalMinutes / 60, maximumHours) },
            set: { newHours in
                let currentMinutes = newHours == maximumHours ? 0 : totalMinutes % 60
                totalMinutes = (newHours * 60) + currentMinutes
            }
        )
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { totalMinutes % 60 },
            set: { newMinutes in
                let currentHours = min(totalMinutes / 60, maximumHours)
                totalMinutes = currentHours == maximumHours
                    ? maximumHours * 60
                    : (currentHours * 60) + newMinutes
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            Picker("Horas", selection: hours) {
                ForEach(0...maximumHours, id: \.self) { hour in
                    Text("\(hour) h")
                        .tag(hour)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityLabel("Horas")

            Picker("Minutos", selection: minutes) {
                ForEach(0..<60, id: \.self) { minute in
                    Text("\(minute.formatted(.number.precision(.integerLength(2)))) min")
                        .tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityLabel("Minutos")
        }
        .frame(height: 136)
    }
}

#Preview {
    @Previewable @State var durationMinutes = 45

    Form {
        Section("Duración") {
            SleepDurationPicker(totalMinutes: $durationMinutes)
        }
    }
}
