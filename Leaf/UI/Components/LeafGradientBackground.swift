import SwiftUI

// her sayfanın arka planı bu — üst renkten alt renge sakin bir geçiş

struct LeafGradientBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(
            colors: [LeafColors.bgTop(for: scheme), LeafColors.bgBottom(for: scheme)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
