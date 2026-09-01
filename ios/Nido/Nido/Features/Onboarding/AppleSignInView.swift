import AuthenticationServices
import SwiftUI

struct AppleSignInView: View {
    @Environment(NidoStore.self) private var store
    @State private var isCompleting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    NidoMark().frame(width: 42, height: 42)
                    Text("Nido").font(.headline)
                }
                .padding(.bottom, 32)

                Text("El cuidado familiar, en privado.")
                    .nidoTitle(.hero)

                Text("Inicia sesión con Apple para proteger el acceso al espacio de tu familia y mantener tus datos separados de otras cuentas.")
                    .foregroundStyle(NidoTheme.secondaryInk)
                    .lineSpacing(4)
                    .padding(.top, 14)

                Spacer()

                if let message = errorMessage ?? store.notice {
                    Label(message, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(NidoTheme.error)
                        .padding(.bottom, 14)
                }

                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = []
                    if let challenge = store.appleSignInChallenge {
                        request.nonce = AppleSignInChallenge.requestNonce(for: challenge.nonce)
                    }
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                              let identityToken = credential.identityToken
                        else {
                            errorMessage = "Apple no ha devuelto una credencial válida."
                            return
                        }
                        isCompleting = true
                        Task {
                            defer { isCompleting = false }
                            do {
                                try await store.completeAppleSignIn(
                                    identityToken: identityToken,
                                    appleUserID: credential.user
                                )
                            } catch {
                                errorMessage = error.localizedDescription
                                await store.prepareAppleSignIn()
                            }
                        }
                    case .failure(let error):
                        if (error as? ASAuthorizationError)?.code != .canceled {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(store.appleSignInChallenge == nil || store.isPreparingAppleSignIn || isCompleting)
                .opacity(store.appleSignInChallenge == nil || isCompleting ? 0.55 : 1)

                if store.isPreparingAppleSignIn || isCompleting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .task {
            guard store.appleSignInChallenge == nil else { return }
            await store.prepareAppleSignIn()
        }
    }
}
