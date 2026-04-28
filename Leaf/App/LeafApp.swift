import SwiftUI
import Sentry
import UIKit

// MARK: - App Delegate (APNs token alımı için)

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { await PushNotificationService.shared.registerToken(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Token alınamadı: \(error.localizedDescription)")
    }
}

// MARK: - App

@main
struct LeafApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // tema tercihi — "system", "light", "dark" arasında tutuluyor
    @AppStorage("appTheme") private var appTheme: String = "system"

    // auth servisi uygulama seviyesinde duruyor çünkü deep link'i burada yakalıyoruz
    @StateObject private var auth = SupabaseAuthService()

    // tek veri kaynağı bu store — tüm okuma/yazma Supabase üzerinden
    @StateObject private var store = BookStore()
    @StateObject private var social = SocialService()
    @StateObject private var pushService = PushNotificationService.shared

    init() {
        let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String ?? ""
        // DSN yoksa veya bozuksa Sentry'yi başlatmıyorum, crash yaşatmama gerek yok
        if dsn.hasPrefix("https://") {
            SentrySDK.start { options in
                options.dsn = dsn
                options.debug = false
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(resolvedScheme)
                .environmentObject(auth)
                .environmentObject(store)
                .environmentObject(social)
                .environmentObject(pushService)
                // Google OAuth'tan dönen URL'yi auth servisine iletiyorum
                .onOpenURL { url in
                    Task { await auth.handleDeepLink(url) }
                }
                .task(id: auth.isAuthenticated) {
                    if !auth.isAuthenticated {
                        // Çıkış yapılınca token'ı sil
                        await pushService.removeToken()
                    }
                }
        }
        // SwiftData tamamen kaldırdım, modelContainer gerekmiyor artık
    }

    // nil dönünce sistem temasına uyar, case'e girmezse default burası
    private var resolvedScheme: ColorScheme? {
        switch appTheme {
        case "light": .light
        case "dark":  .dark
        default:      nil
        }
    }
}
