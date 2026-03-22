import SwiftUI

// web'deki bg-gradient'in SwiftUI karşılığı
// sayfanın arkasında sakin bir geçiş oluşturuyor

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
