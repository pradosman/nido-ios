import SwiftUI

struct GrowthSyncStatus: View {
    let store: NidoStore

    private var message: String {
        if store.babyCareHasConflict { return "Hay cambios en conflicto. Tus mediciones siguen guardadas en este dispositivo." }
        if let error = store.babyCareError { return error }
        if store.babyCareNeedsSync { return "Guardado en este dispositivo · pendiente de sincronizar" }
        if store.isSavingBabyCare { return "Sincronizando mediciones…" }
        return "Mediciones sincronizadas"
    }

    private var symbol: String {
        if store.babyCareHasConflict { return "exclamationmark.icloud.fill" }
        if store.babyCareError != nil { return "exclamationmark.icloud.fill" }
        if store.babyCareNeedsSync { return "icloud.slash" }
        return "checkmark.icloud.fill"
    }

    private var tint: Color {
        if store.babyCareHasConflict || store.babyCareError != nil { return NidoTheme.warning }
        if store.babyCareNeedsSync { return NidoTheme.secondaryInk }
        return NidoTheme.moss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: symbol)
                .font(.footnote)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("growth.sync.status")

            if store.babyCareHasConflict {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Conservar mis cambios") {
                        Task { await store.resolveBabyCareConflict(keepLocal: true) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier("growth.sync.keepLocal")

                    Button("Usar cambios compartidos") {
                        Task { await store.resolveBabyCareConflict(keepLocal: false) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier("growth.sync.useShared")
                }
                .buttonStyle(.bordered)
            } else if store.babyCareNeedsSync {
                Button {
                    Task { await store.retryBabyCareSync() }
                } label: {
                    Label("Volver a sincronizar", systemImage: "arrow.clockwise.icloud")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(store.isSavingBabyCare)
                .accessibilityIdentifier("growth.sync.retry")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
