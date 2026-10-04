import SwiftUI

struct CaregiverAccessView: View {
    @Environment(NidoStore.self) private var store
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @FocusState private var isCodeFocused: Bool

    private var parsedCode: InvitationCode? {
        InvitationCode.parse(code)
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

                    Text("Únete al espacio familiar.")
                        .nidoTitle(.hero)

                    Text("Introduce el código que te ha enviado el administrador del hogar o un familiar.")
                        .foregroundStyle(NidoTheme.secondaryInk)
                        .lineSpacing(4)
                        .padding(.top, 14)
                        .padding(.bottom, 28)

                    VStack(alignment: .leading, spacing: 9) {
                        Text("Código de invitación")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NidoTheme.secondaryInk)
                        TextField("XXXX-XXXX-XXXX", text: $code)
                            .font(.system(.title2, design: .monospaced, weight: .semibold))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isCodeFocused)
                    }
                    .padding(18)
                    .paperCard(cornerRadius: 18)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(NidoTheme.error)
                            .padding(.top, 14)
                    }

                    Button {
                        guard let parsedCode else { return }
                        isCodeFocused = false
                        isJoining = true
                        errorMessage = nil
                        Task {
                            do {
                                store.dismissNotice()
                                try await store.joinCaregiver(code: parsedCode.submissionValue)
                            } catch {
                                errorMessage = error.localizedDescription
                                isJoining = false
                            }
                        }
                    } label: {
                        HStack {
                            Text(isJoining ? "Accediendo…" : "Unirme")
                            Spacer()
                            if isJoining { ProgressView().tint(.white) } else { Image(systemName: "person.2.fill") }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .background(NidoTheme.moss, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .disabled(parsedCode == nil || isJoining)
                    .opacity(parsedCode == nil ? 0.55 : 1)
                    .padding(.top, 22)

                    Button("Crear un espacio familiar") {
                        store.showOnboarding()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NidoTheme.moss)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.top, 10)

                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear { isCodeFocused = true }
    }
}
