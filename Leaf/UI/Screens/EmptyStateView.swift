import SwiftUI

// web'deki EmptyState bileşeninin SwiftUI karşılığı
// ikon + başlık + açıklama + aksiyon butonu

struct EmptyStateView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var visible = false
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // cam efektli kitap ikonu kutusu
            GlassCard {
                Image(systemName: "book")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(LeafColors.accent(for: scheme))
                    .opacity(0.9)
                    .frame(width: 88, height: 88)
            }
            .padding(.bottom, LeafSpacing.xl)

            Text("Kitaplığınız şu anda boş")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(LeafColors.textPrimary(for: scheme))
                .tracking(-0.3)
                .padding(.bottom, LeafSpacing.xs)

            Text("Kitaplığınız boş — ve bu da iyi.\nİlk kitabınızı ekleyerek onu oluşturun.")
                .font(.system(size: 15))
                .foregroundStyle(LeafColors.textSecondary(for: scheme))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, LeafSpacing.xxl)

            // "Kitap Ekle" butonu
            Button(action: onAdd) {
                Text("Kitap Ekle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, LeafSpacing.lg)
                    .frame(height: 44)
                    .background {
                        Capsule().fill(LeafColors.accent(for: scheme))
                    }
                    .shadow(color: LeafColors.primaryLight.opacity(0.25), radius: 12, y: 4)
            }
            .buttonStyle(PressStyle())
        }
        .padding(.horizontal, LeafSpacing.xl)
        .frame(maxWidth: 480)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 10)
        .onAppear {
            withAnimation(LeafMotion.fadeIn) { visible = true }
        }
    }
}
