import SwiftUI
import SwiftData

@main
struct LeafApp: App {
    // tema tercihi: "system", "light", "dark"
    @AppStorage("appTheme") private var appTheme: String = "system"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(resolvedScheme)
        }
        .modelContainer(for: [Book.self, BookNote.self])
    }

    // nil döndüğünde sistem ayarına uyar
    private var resolvedScheme: ColorScheme? {
        switch appTheme {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}
