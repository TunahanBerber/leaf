import SwiftUI

// basıldığında hafifçe küçülüyor — native uygulama gibi hissettirmesi için
// web'deki .u-press:active { transform: scale(0.96) } ile aynı mantık

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? LeafMotion.pressScale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(LeafMotion.fast, value: configuration.isPressed)
    }
}

// cam efektli input alanı — Apple tasarım diline uymak için böyle yaptım
struct LeafTextField: View {
    @Environment(\.colorScheme) private var scheme

    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: LeafSpacing.xs) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LeafColors.textSecondary(for: scheme))

            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .keyboardType(keyboard)
                .padding(.horizontal, LeafSpacing.md)
                .padding(.vertical, LeafSpacing.sm)
                .background {
                    RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous)
                        .fill(LeafColors.surfacePrimary(for: scheme))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous)
                        .strokeBorder(LeafColors.borderSubtle(for: scheme), lineWidth: 0.5)
                }
        }
    }
}
