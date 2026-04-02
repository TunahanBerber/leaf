// SupabaseAuthService.swift
// Leaf — Kullanıcı kimlik doğrulama servisi
// Email/Password kayıt, giriş ve çıkış işlemlerini yönetir

import Foundation
import Supabase

// MARK: - Auth Service

@MainActor
final class SupabaseAuthService: ObservableObject {

    // Giriş yapmış kullanıcı bilgisi
    @Published var currentUser: User?

    // Giriş durumu — View'larda kullanmak için kolay erişim
    @Published var isAuthenticated = false

    // İşlem yüklenme ve hata durumları
    @Published var isLoading = false
    @Published var errorMessage: String?

    init() {
        // Uygulama açılır açılmaz oturum dinlemeye başla
        // Mevcut aktif oturum varsa otomatik tanır
        Task { await listenToAuthChanges() }
    }

    // MARK: - Auth State

    /// Supabase auth durumunu anlık dinler (sign in / sign out / token yenileme)
    private func listenToAuthChanges() async {
        for await (_, session) in supabase.auth.authStateChanges {
            currentUser = session?.user
            isAuthenticated = session != nil
        }
    }

    // MARK: - Sign Up

    /// Yeni kullanıcı kaydı oluşturur
    /// Supabase email doğrulama aktifse kullanıcıya onay maili gider
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

    /// Email ve şifre ile giriş yapar
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

    /// Mevcut oturumu kapatır
    func signOut() async {
        errorMessage = nil
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = mapAuthError(error)
        }
    }

    // MARK: - Google Sign In (OAuth Web Flow)

    /// Native SDK yerine, doğrudan Supabase'in güvenli Web Flow'unu kullanır (URL döndürür).
    /// Nonce akışı ve her türlü güvenlik önlemi Supabase Edge sunucularında otomatik yönetilir.
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

    /// LeafApp'ten çağrılır — gerekirse web OAuth fallback için
    func handleDeepLink(_ url: URL) async {
        do {
            try await supabase.auth.session(from: url)
        } catch {
            // deep link auth hatası — sessizce geç
        }
    }

    // MARK: - Password Reset

    /// Şifre sıfırlama maili gönderir
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

    /// Ham auth hatalarını kullanıcı dostu Türkçe mesajlara çevirir
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
