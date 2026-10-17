import AuthenticationServices
import SwiftUI

struct AppleAccountDeletionAuthorizationView: View {
    let refreshChallenge: () async throws -> AppleSignInChallenge
    let authorizeDeletion: (AppleAccountDeletionProof) async throws -> Void
    let onCancel: () -> Void

    @State private var currentChallenge: AppleSignInChallenge
    @State private var challengeForPendingAuthorization: AppleSignInChallenge?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var isRefreshingChallenge = false

    init(
        challenge: AppleSignInChallenge,
        refreshChallenge: @escaping () async throws -> AppleSignInChallenge,
        authorizeDeletion: @escaping (AppleAccountDeletionProof) async throws -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.refreshChallenge = refreshChallenge
        self.authorizeDeletion = authorizeDeletion
        self.onCancel = onCancel
        _currentChallenge = State(initialValue: challenge)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
              VStack(alignment: .leading, spacing: 20) {
                Text("Confirma tu identidad")
                    .font(.title2.weight(.semibold))
                Text("Apple te pedirá que confirmes tu identidad. Puedes cancelar antes de confirmar con Apple.")
                    .foregroundStyle(NidoTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(NidoTheme.error)
                        .accessibilityIdentifier("account-deletion-authorization-error")
                }

                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = []
                    challengeForPendingAuthorization = currentChallenge
                    request.nonce = AppleSignInChallenge.requestNonce(for: currentChallenge.nonce)
                } onCompletion: { result in
                    guard case .success(let authorization) = result else {
                        challengeForPendingAuthorization = nil
                        if case .failure(let error) = result,
                           (error as? ASAuthorizationError)?.code != .canceled {
                            errorMessage = error.localizedDescription
                        }
                        return
                    }
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let identityToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
                          !identityToken.isEmpty,
                          let authorizationCode = credential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }),
                          !authorizationCode.isEmpty
                    else {
                        challengeForPendingAuthorization = nil
                        errorMessage = "Apple no ha devuelto una credencial válida. Puedes volver a intentarlo."
                        return
                    }
                    guard let authorizationChallenge = challengeForPendingAuthorization else {
                        errorMessage = "La autorización ha caducado. Obtén una nueva y vuelve a intentarlo."
                        return
                    }
                    challengeForPendingAuthorization = nil

                    let proof = AppleAccountDeletionProof(
                        challengeID: authorizationChallenge.challengeID,
                        identityToken: identityToken,
                        authorizationCode: authorizationCode
                    )
                    isWorking = true
                    errorMessage = nil
                    Task {
                        defer { isWorking = false }
                        do {
                            try await authorizeDeletion(proof)
                        } catch {
                            let failureMessage = error.localizedDescription
                            do {
                                currentChallenge = try await refreshChallenge()
                                errorMessage = failureMessage
                            } catch {
                                errorMessage = "\(failureMessage) \(error.localizedDescription)"
                            }
                        }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(isWorking || isRefreshingChallenge)

                Button {
                    Task { await refreshForRetry() }
                } label: {
                    Text("Obtener una nueva autorización")
                        .font(.footnote.weight(.medium))
                        .frame(minHeight: 48, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isWorking || isRefreshingChallenge)
                .accessibilityIdentifier("account-deletion-refresh-challenge")

                Spacer(minLength: 0)
              }
              .padding(24)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Eliminar cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: onCancel)
                        .disabled(isWorking)
                        .accessibilityIdentifier("account-deletion-cancel")
                }
            }
            .overlay {
                if isWorking || isRefreshingChallenge {
                    ProgressView(isWorking ? "Comprobando con Apple…" : "Preparando autorización…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .interactiveDismissDisabled(isWorking || isRefreshingChallenge)
        }
    }

    @MainActor
    private func renewChallenge() async {
        do {
            currentChallenge = try await refreshChallenge()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func refreshForRetry() async {
        guard !isWorking, !isRefreshingChallenge else { return }
        isRefreshingChallenge = true
        defer { isRefreshingChallenge = false }
        await renewChallenge()
    }
}

enum AccountDeletionEntryPointStyle {
    case settings
    case accountMenu
}

struct AccountDeletionEntryPoint: View {
    @Environment(NidoStore.self) private var store

    let style: AccountDeletionEntryPointStyle

    @State private var isConfirmingDeletion = false
    @State private var isDeletingAccount = false
    @State private var isAuthorizingDeletion = false
    @State private var deletionChallenge: AppleSignInChallenge?
    @State private var preparationError: String?

    private var isOwner: Bool { store.currentCaregiver?.role == .owner }

    var body: some View {
        Group {
            switch style {
            case .settings:
                Button("Eliminar mi cuenta", role: .destructive) {
                    isConfirmingDeletion = true
                }
                .disabled(isDeletingAccount)
            case .accountMenu:
                Menu {
                    Button("Eliminar cuenta", role: .destructive) {
                        isConfirmingDeletion = true
                    }
                    .disabled(isDeletingAccount)
                } label: {
                    Label("Cuenta", systemImage: "person.crop.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NidoTheme.moss)
                        .padding(.horizontal, 14)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(.regularMaterial, in: Capsule())
                        .contentShape(Capsule())
                }
                .accessibilityIdentifier("account-actions-button")
            }
        }
        .alert(
            isOwner ? "¿Eliminar permanentemente el espacio familiar?" : "¿Eliminar tu cuenta?",
            isPresented: $isConfirmingDeletion
        ) {
            Button("Eliminar definitivamente", role: .destructive) {
                beginDeletionAuthorization()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
        .alert(
            "No se pudo preparar la autorización",
            isPresented: Binding(
                get: { preparationError != nil },
                set: { if !$0 { preparationError = nil } }
            )
        ) {
            Button("Aceptar", role: .cancel) { preparationError = nil }
        } message: {
            Text(preparationError ?? "Vuelve a intentarlo.")
        }
        .sheet(
            isPresented: $isAuthorizingDeletion,
            onDismiss: {
                deletionChallenge = nil
                store.cancelAccountDeletionAuthorization()
            }
        ) {
            if let deletionChallenge {
                AppleAccountDeletionAuthorizationView(
                    challenge: deletionChallenge,
                    refreshChallenge: { try await store.prepareAccountDeletionChallenge() },
                    authorizeDeletion: { proof in
                        try await store.deleteAccount(proof: proof)
                        isAuthorizingDeletion = false
                    },
                    onCancel: { isAuthorizingDeletion = false }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var confirmationMessage: String {
        if isOwner {
            return "Se eliminarán de forma permanente el perfil, todos los registros y el acceso de todos los familiares. Esta acción no se puede deshacer."
        }
        if store.currentCaregiver != nil {
            return "Se eliminarán tu identidad y tu acceso a este espacio familiar. Los datos compartidos permanecerán para el resto de familiares."
        }
        return "Se eliminará tu cuenta de Nido. Tendrás que confirmar tu identidad con Apple antes de continuar."
    }

    private func beginDeletionAuthorization() {
        isDeletingAccount = true
        preparationError = nil
        Task {
            defer { isDeletingAccount = false }
            do {
                deletionChallenge = try await store.prepareAccountDeletionChallenge()
                isAuthorizingDeletion = true
            } catch {
                preparationError = error.localizedDescription
            }
        }
    }
}
