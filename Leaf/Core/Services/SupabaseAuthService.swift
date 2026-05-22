// SupabaseAuthService.swift
// tüm auth işlemleri buradan geçiyor — kayıt, giriş, çıkış, Google OAuth, şifre sıfırlama

import Foundation
import Supabase
import AuthenticationServices
import CryptoKit

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

    // MARK: - Sign in with Apple

    // Apple isteği hazırlanırken çağrılır — raw nonce saklanır, hashed nonce Apple'a gönderilir
    private var currentAppleNonce: String?

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentAppleNonce = nonce
        return sha256(nonce)
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            let authError = error as? ASAuthorizationError
            if authError?.code != .canceled {
                errorMessage = "Apple ile giriş başarısız."
            }
            return
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData   = credential.identityToken,
                let idToken     = String(data: tokenData, encoding: .utf8),
                let nonce       = currentAppleNonce
            else {
                errorMessage = "Apple kimlik bilgisi alınamadı."
                return
            }

            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                try await supabase.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
                )
            } catch {
                errorMessage = "Apple ile giriş yapılamadı."
            }
        }
    }

    // MARK: - Hesap Silme

    // Supabase'de aşağıdaki RPC fonksiyonunu oluşturman gerekiyor:
    //
    // create or replace function delete_user_account()
    // returns void language plpgsql security definer as $$
    // begin
    //   delete from public.messages            where sender_id   = auth.uid()::text;
    //   delete from public.conversations       where user_a_id   = auth.uid()::text
    //                                             or user_b_id   = auth.uid()::text;
    //   delete from public.conversation_requests where sender_id = auth.uid()::text
    //                                               or receiver_id = auth.uid()::text;
    //   delete from public.device_tokens       where user_id     = auth.uid()::text;
    //   delete from public.profiles            where id          = auth.uid()::text;
    //   delete from auth.users                 where id          = auth.uid();
    // end; $$;
    func deleteAccount() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase.rpc("delete_user_account").execute()
            try? await supabase.auth.signOut()
            return true
        } catch {
            errorMessage = "Hesap silinemedi. Lütfen tekrar dene."
            return false
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
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
