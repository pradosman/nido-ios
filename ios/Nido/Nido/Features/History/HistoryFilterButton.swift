import SwiftUI

struct HistoryFilterButton: View {
    let title: String
    let kind: EntryKind?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let kind {
                    CareCategoryIcon(
                        category: kind.careCategory,
                        size: 15,
                        tint: isSelected ? NidoTheme.textOnMoss : NidoTheme.color(for: kind)
                    )
                }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? NidoTheme.textOnMoss : NidoTheme.secondaryInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? NidoTheme.moss : NidoTheme.surface, in: Capsule())
            .overlay {
                Capsule().stroke(isSelected ? .clear : NidoTheme.separator.opacity(0.5), lineWidth: 0.5)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
