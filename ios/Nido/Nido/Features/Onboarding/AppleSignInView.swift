import AuthenticationServices
import SwiftUI

struct AppleSignInView: View {
    @Environment(NidoStore.self) private var store
    @Environment(NidoDemoSessionCoordinator.self) private var demoCoordinator
    @State private var isCompleting = false
    @State private var isStartingDemo = false
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
                .disabled(store.appleSignInChallenge == nil || store.isPreparingAppleSignIn || isCompleting || isStartingDemo)
                .opacity(store.appleSignInChallenge == nil || store.isPreparingAppleSignIn || isCompleting || isStartingDemo ? 0.55 : 1)
                .accessibilityIdentifier("apple-sign-in")

                Button {
                    isStartingDemo = true
                    Task {
                        defer { isStartingDemo = false }
                        await demoCoordinator.enter()
                    }
                } label: {
                    if isStartingDemo {
                        ProgressView("Preparando la demostración…")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    } else {
                        Text("Explorar demostración")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                }
                .buttonStyle(.bordered)
                .tint(NidoTheme.moss)
                .disabled(isStartingDemo || demoCoordinator.isTransitioning || isCompleting)
                .accessibilityIdentifier("demo-start")
                .padding(.top, 12)

                if store.isPreparingAppleSignIn || isCompleting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                }

                #if DEBUG
                if store.isCompletingAppleSignInForUITest {
                    Text("Iniciando sesión con Apple")
                        .font(.footnote)
                        .accessibilityIdentifier("apple-auth-completing")
                }
                if store.isStartingDemoForUITest {
                    Text("Preparando la demostración")
                        .font(.footnote)
                        .accessibilityIdentifier("demo-start-in-progress")
                }
                #endif
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .task {
            guard store.appleSignInChallenge == nil else { return }
            await store.prepareAppleSignIn()
        }
        #if DEBUG
        .onAppear {
            if store.isCompletingAppleSignInForUITest { isCompleting = true }
            if store.isStartingDemoForUITest { isStartingDemo = true }
        }
        #endif
    }
}
