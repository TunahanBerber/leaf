// SupabaseAuthService.swift
// tüm auth işlemleri buradan geçiyor — kayıt, giriş, çıkış, Google OAuth, şifre sıfırlama

import Foundation
import Supabase

// MARK: - Auth Service

@MainActor
final class SupabaseAuthService: ObservableObject {

    // aktif kullanıcı bilgisi
    @Published var currentUser: User?

    // view'larda auth kontrolü için kullanıyoruz
    @Published var isAuthenticated = false

    // yükleniyor ve hata durumları
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        // uygulama açıldığında hemen dinlemeye başla — daha önce giriş yapıldıysa otomatik algılar
        Task { await listenToAuthChanges() }
    }

    // MARK: - Auth State

    // auth durumunu canlı dinliyor — giriş, çıkış ve token yenileme hepsini yakalıyor
    private func listenToAuthChanges() async {
        for await (_, session) in supabase.auth.authStateChanges {
            currentUser = session?.user
            isAuthenticated = session != nil
        }
    }

    // MARK: - Sign Up

    // yeni hesap oluşturuyor — Supabase email doğrulama açıksa onay maili gidiyor
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.auth.signUp(email: email, password: password)
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - Sign In

    // email + şifre ile giriş
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - Sign Out

    // oturumu kapatıyor
    func signOut() async {
        errorMessage = nil
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - Google Sign In (OAuth Web Flow)

    // Google OAuth için Supabase'in web akışını kullanıyorum — nonce ve güvenlik Supabase'de halloluyor
    func getOAuthLoginURL() async -> URL? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            // Leaf uygulamasının dönüş şeması Info.plist içinde tanımlı: com.tunahan.leaf
            let redirectURL = URL(string: "com.tunahan.leaf://login-callback")!
            return try await supabase.auth.getOAuthSignInURL(provider: .google, redirectTo: redirectURL)
        } catch {
            errorMessage = mapAuthError(error)
            return nil
        }
    }

    // MARK: - Deep Link Handler

    // LeafApp'ten çağrılıyor — OAuth dönüş URL'ini yakalıyor
    func handleDeepLink(_ url: URL) async {
        do {
            try await supabase.auth.session(from: url)
        } catch {
            // deep link hatası olursa sessizce geç, kullanıcıya gösterme
        }
    }

    // MARK: - Password Reset

    // şifre sıfırlama maili gönderiyor
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.auth.resetPasswordForEmail(email)
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - Error Mapping

    // Supabase'den gelen kaba hata mesajlarını Türkçe'ye çeviriyorum
    private func mapAuthError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("invalid login credentials") || message.contains("invalid_credentials") {
            return "Email veya şifre hatalı."
        } else if message.contains("email already registered") || message.contains("user_already_exists") {
            return "Bu email adresi zaten kayıtlı."
        } else if message.contains("password should be") {
            return "Şifre en az 6 karakter olmalı."
        } else if message.contains("network") || message.contains("connection") {
            return "İnternet bağlantısı kurulamadı."
        }
        return "Bir hata oluştu: \(error.localizedDescription)"
    }
}
