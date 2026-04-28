import SwiftUI

// yarı şeffaf cam kartı — web'deki .glass utility class'larının SwiftUI karşılığı
// ultraThinMaterial üstüne yüzey rengi ve çok katmanlı gölge bindiriyorum

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: LeafRadius.large, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: LeafRadius.large, style: .continuous)
                            .fill(LeafColors.surfacePrimary(for: scheme))
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: LeafRadius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LeafRadius.large, style: .continuous)
                    .strokeBorder(LeafColors.borderSubtle(for: scheme), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
            .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
    }
}
