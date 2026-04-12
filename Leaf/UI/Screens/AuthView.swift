// AuthView.swift
// giriş ve kayıt ekranı — email/şifre ve Google OAuth buradan çalışıyor

import SwiftUI

// MARK: - Auth View

struct AuthView: View {

    // ContentView'dan environmentObject olarak geliyor
    @EnvironmentObject private var auth: SupabaseAuthService
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL

    @State private var email    = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showResetAlert = false

    var body: some View {
        ZStack {
            LeafGradientBackground()

            ScrollView {
                VStack(spacing: 32) {

                    // logo ve başlık
                    VStack(spacing: 8) {
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 56))
                            // tema rengine göre değişiyor
                            .foregroundStyle(LeafColors.accent(for: scheme))

                        Text("Leaf")
                            .font(.largeTitle.bold())
                            .foregroundStyle(LeafColors.textPrimary(for: scheme))

                        Text(isSignUp ? "Hesap Oluştur" : "Hoş Geldin")
                            .font(.subheadline)
                            .foregroundStyle(LeafColors.textSecondary(for: scheme))
                    }
                    .padding(.top, 60)

                    // form kartı
                    GlassCard {
                        VStack(spacing: 16) {

                            AuthTextField(
                                placeholder: "Email",
                                text: $email,
                                keyboardType: .emailAddress,
                                icon: "envelope"
                            )

                            AuthTextField(
                                placeholder: "Şifre",
                                text: $password,
                                isSecure: true,
                                icon: "lock"
                            )

                            if let error = auth.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }

                            Button {
                                Task {
                                    if isSignUp {
                                        await auth.signUp(email: email, password: password)
                                    } else {
                                        await auth.signIn(email: email, password: password)
                                    }
                                }
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LeafColors.accent(for: scheme))
                                        .frame(height: 50)

                                    if auth.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text(isSignUp ? "Kayıt Ol" : "Giriş Yap")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .disabled(auth.isLoading || email.isEmpty || password.isEmpty)
                            
                            // "veya" ayracı
                            HStack {
                                VStack { Divider().background(LeafColors.borderPrimary(for: scheme)) }
                                Text("VEYA")
                                    .font(.caption2.bold())
                                    .foregroundStyle(LeafColors.textSecondary(for: scheme))
                                VStack { Divider().background(LeafColors.borderPrimary(for: scheme)) }
                            }
                            .padding(.vertical, 8)

                            // Google ile giriş butonu
                            Button {
                                Task {
                                    if let url = await auth.getOAuthLoginURL() {
                                        openURL(url)
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "g.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(LeafColors.textPrimary(for: scheme))
                                    
                                    Text("Google ile Devam Et")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(LeafColors.textPrimary(for: scheme))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                // temaya göre cam hissi
                                .background(LeafColors.surfacePrimary(for: scheme))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LeafColors.borderPrimary(for: scheme), lineWidth: 0.5)
                                )
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)

                    // kayıt/giriş geçiş butonu
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            isSignUp.toggle()
                            auth.errorMessage = nil
                        }
                    } label: {
                        Text(isSignUp
                             ? "Zaten hesabın var mı? **Giriş Yap**"
                             : "Hesabın yok mu? **Kayıt Ol**"
                        )
                        .font(.footnote)
                        .foregroundStyle(LeafColors.textSecondary(for: scheme))
                    }

                    // şifremi unuttum butonu — sadece giriş ekranında göster
                    if !isSignUp {
                        Button {
                            guard !email.isEmpty else {
                                auth.errorMessage = "Lütfen önce email adresinizi girin."
                                return
                            }
                            Task {
                                await auth.resetPassword(email: email)
                                showResetAlert = true
                            }
                        } label: {
                            Text("Şifremi Unuttum")
                                .font(.footnote)
                                .foregroundStyle(LeafColors.textTertiary(for: scheme))
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .alert("Sıfırlama Maili Gönderildi", isPresented: $showResetAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("\(email) adresine şifre sıfırlama bağlantısı gönderildi.")
        }
    }
}

// MARK: - Auth Text Field
// LeafTextField'dan farklı — ikon ve güvenli alan desteği var, sadece burada kullanıyorum

private struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(.password)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
