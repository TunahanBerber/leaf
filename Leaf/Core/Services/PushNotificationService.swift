import UIKit
import UserNotifications
import Supabase

extension Notification.Name {
    static let navigateToConversation = Notification.Name("navigateToConversation")
}

@MainActor
final class PushNotificationService: NSObject, ObservableObject {

    static let shared = PushNotificationService()

    @Published var isPermissionGranted = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - İzin & Kayıt

    func requestPermissionAndRegister() {
        Task {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            isPermissionGranted = granted
            print("[Push] İzin durumu: \(granted)")
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Token Kaydetme (AppDelegate'ten çağrılır)

    func registerToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        print("[Push] APNs token alındı: \(token.prefix(20))...")

        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else {
            print("[Push] Oturum bulunamadı, token kaydedilemedi")
            return
        }
        print("[Push] Token Supabase'e yazılıyor — user: \(userId.prefix(8))...")

        do {
            try await supabase
                .from("device_tokens")
                .upsert(
                    ["user_id": AnyJSON.string(userId), "token": AnyJSON.string(token)],
                    onConflict: "user_id"
                )
                .execute()
            print("[Push] Token başarıyla kaydedildi")
        } catch {
            print("[Push] Token kaydedilemedi: \(error)")
        }
    }

    // MARK: - Token Silme (çıkış yapılınca)

    func removeToken() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }
        try? await supabase
            .from("device_tokens")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Badge Sıfırlama

    func clearBadge() {
        Task { @MainActor in
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {

    // Uygulama ön plandayken de bildirimi göster
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Bildirime tıklandığında ilgili sohbete git
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let conversationId = userInfo["conversation_id"] as? String {
            let username = userInfo["sender_username"] as? String ?? "Kullanıcı"
            NotificationCenter.default.post(
                name: .navigateToConversation,
                object: nil,
                userInfo: ["conversationId": conversationId, "username": username]
            )
        }
        completionHandler()
    }
}
