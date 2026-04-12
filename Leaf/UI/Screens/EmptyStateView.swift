import SwiftUI

// boş durum ekranı — ikon, başlık, açıklama ve aksiyon butonu içeriyor
// kütüphane ve istek listesi boşken gösteriliyor

struct EmptyStateView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var visible = false
    
    var icon: String = "book"
    var title: String = "Kitaplığınız şu anda boş"
    var message: String = "Kitaplığınız boş — ve bu da iyi.\nİlk kitabınızı ekleyerek onu oluşturun."
    var buttonText: String = "Kitap Ekle"
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // cam efektli ikon kutusu
            GlassCard {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(LeafColors.accent(for: scheme))
                    .opacity(0.9)
                    .frame(width: 88, height: 88)
            }
            .padding(.bottom, LeafSpacing.xl)

            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(LeafColors.textPrimary(for: scheme))
                .tracking(-0.3)
                .padding(.bottom, LeafSpacing.xs)

            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(LeafColors.textSecondary(for: scheme))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, LeafSpacing.xxl)

            // aksiyon butonu
            Button(action: onAdd) {
                Text(buttonText)
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
