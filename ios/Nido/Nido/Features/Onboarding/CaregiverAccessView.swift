import SwiftUI

struct CaregiverAccessView: View {
    @Environment(NidoStore.self) private var store
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @FocusState private var isCodeFocused: Bool

    private var cleanCode: String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
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
                    .padding(.bottom, 46)

                    Text("Este nido ya está\nen familia.")
                        .editorialTitle(46)
                        .lineSpacing(-4)

                    Text("Introduce el código que te ha enviado otro cuidador para compartir el día a día de \(store.profile?.babyName ?? "vuestro bebé").")
                        .foregroundStyle(NidoTheme.secondaryInk)
                        .lineSpacing(4)
                        .padding(.top, 18)
                        .padding(.bottom, 34)

                    VStack(alignment: .leading, spacing: 9) {
                        Text("Código de invitación")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NidoTheme.secondaryInk)
                        TextField("XXXX-XXXX-XXXX", text: $code)
                            .font(.system(.title2, design: .monospaced, weight: .semibold))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isCodeFocused)
                            .onChange(of: code) { _, value in
                                let characters = value.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(12)
                                let raw = String(characters)
                                if raw.count > 8 {
                                    code = "\(raw.prefix(4))-\(raw.dropFirst(4).prefix(4))-\(raw.dropFirst(8))"
                                } else if raw.count > 4 {
                                    code = "\(raw.prefix(4))-\(raw.dropFirst(4))"
                                } else {
                                    code = raw
                                }
                            }
                    }
                    .padding(18)
                    .paperCard(cornerRadius: 18)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(NidoTheme.care)
                            .padding(.top, 14)
                    }

                    Button {
                        isCodeFocused = false
                        isJoining = true
                        errorMessage = nil
                        Task {
                            do {
                                store.dismissNotice()
                                try await store.joinCaregiver(code: code)
                            } catch {
                                errorMessage = error.localizedDescription
                                isJoining = false
                            }
                        }
                    } label: {
                        HStack {
                            Text(isJoining ? "Abriendo vuestro espacio…" : "Unirme al nido")
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
                    .disabled((cleanCode.count != 8 && cleanCode.count != 12) || isJoining)
                    .opacity(cleanCode.count == 8 || cleanCode.count == 12 ? 1 : 0.55)
                    .padding(.top, 22)

                    Label("Solo las personas invitadas pueden registrar y consultar información.", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(NidoTheme.secondaryInk)
                        .padding(.top, 20)
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
