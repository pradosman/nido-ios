import SwiftUI

struct OnboardingView: View {
    @Environment(NidoStore.self) private var store
    @State private var caregiverName = ""
    @State private var babyName = ""
    @State private var birthDate = Date.now
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case caregiver
        case baby
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        NidoMark().frame(width: 42, height: 42)
                        Text("Nido").font(.headline)
                    }
                    .padding(.bottom, 32)

                    Text("El día a día de vuestro bebé.")
                        .nidoTitle(.hero)

                    Text("Registra sueño, tomas, pañales y cuidados. Compartid la misma información entre cuidadores.")
                        .font(.body)
                        .foregroundStyle(NidoTheme.secondaryInk)
                        .lineSpacing(4)
                        .padding(.top, 14)
                        .padding(.bottom, 28)

                    VStack(spacing: 14) {
                        field(title: "Tu nombre", text: $caregiverName, field: .caregiver, contentType: .name)
                        field(title: "Nombre del bebé", text: $babyName, field: .baby, contentType: .name)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fecha de nacimiento")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(NidoTheme.secondaryInk)
                            DatePicker("Fecha de nacimiento", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                                .labelsHidden()
                                .tint(NidoTheme.moss)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .paperCard(cornerRadius: 18)
                    }

                    if let notice = store.notice {
                        Label(notice, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(NidoTheme.error)
                            .padding(.top, 14)
                    }

                    Button {
                        focusedField = nil
                        isSaving = true
                        store.dismissNotice()
                        Task {
                            await store.saveProfile(Profile(
                                caregiverName: caregiverName,
                                babyName: babyName,
                                birthDate: birthDate.formatted(.iso8601.year().month().day())
                            ))
                            isSaving = false
                        }
                    } label: {
                        HStack {
                            Text(isSaving ? "Creando espacio…" : "Crear espacio")
                            Spacer()
                            if isSaving { ProgressView().tint(.white) } else { Image(systemName: "arrow.right") }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .background(NidoTheme.moss, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .disabled(caregiverName.trimmingCharacters(in: .whitespaces).isEmpty || babyName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .opacity(caregiverName.isEmpty || babyName.isEmpty ? 0.55 : 1)
                    .padding(.top, 24)

                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            guard let profile = store.profile else { return }
            caregiverName = profile.caregiverName
            babyName = profile.babyName
            birthDate = ISO8601DateFormatter.nidoDay.date(from: profile.birthDate) ?? .now
        }
    }

    private func field(title: String, text: Binding<String>, field: Field, contentType: UITextContentType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(NidoTheme.secondaryInk)
            TextField(title, text: text)
                .font(.body.weight(.medium))
                .textContentType(contentType)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: field)
                .submitLabel(field == .caregiver ? .next : .done)
                .onSubmit { focusedField = field == .caregiver ? .baby : nil }
        }
        .padding(16)
        .paperCard(cornerRadius: 18)
    }
}
