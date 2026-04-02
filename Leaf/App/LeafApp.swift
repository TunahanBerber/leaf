import SwiftUI
import Sentry

@main
struct LeafApp: App {
    // tema tercihi: "system", "light", "dark"
    @AppStorage("appTheme") private var appTheme: String = "system"

    // Auth servisi — deep link handler için uygulama seviyesinde yaşıyor
    @StateObject private var auth = SupabaseAuthService()

    // Tek veri kaynağı: BookStore. Supabase'e doğrudan yazar/okur.
    @StateObject private var store = BookStore()

    init() {
        let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String ?? ""
        if !dsn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            SentrySDK.start { options in
                options.dsn = dsn
                options.debug = false
                // Uygulama çökmelerini yakalayacak
                // Performance monitoring istersen: options.tracesSampleRate = 1.0
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(resolvedScheme)
                .environmentObject(auth)
                .environmentObject(store)
                // Google OAuth dönüş URL'ini yakala
                .onOpenURL { url in
                    Task { await auth.handleDeepLink(url) }
                }
        }
        // SwiftData kaldırıldı — modelContainer yok
    }

    // nil döndüğünde sistem ayarına uyar
    private var resolvedScheme: ColorScheme? {
        switch appTheme {
        case "light": .light
        case "dark":  .dark
        default:      nil
        }
    }
}
