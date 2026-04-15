import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var social: SocialService
    @Environment(\.colorScheme) var colorScheme

    @State private var username = ""
    @State private var bio = ""
    @State private var ageText = ""
    @State private var showUnderageAlert = false

    private var age: Int? { Int(ageText) }

    private var isFormValid: Bool {
        username.trimmingCharacters(in: .whitespaces).count >= 3 &&
        (age ?? 0) >= 1
    }

    var body: some View {
        ZStack {
            LeafGradientBackground()

            ScrollView {
                VStack(spacing: LeafSpacing.xl) {
                    header
                    formCard
                    createButton
                    Spacer(minLength: LeafSpacing.xxl)
                }
                .padding(.horizontal, LeafSpacing.md)
                .padding(.top, LeafSpacing.xxxl)
            }
        }
        .alert("Yaş Sınırı", isPresented: $showUnderageAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("Sosyal özellikler 18 yaş ve üzeri kullanıcılara açıktır.\nYine de kitap takibine devam edebilirsin.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: LeafSpacing.sm) {
            Circle()
                .fill(LeafColors.accent(for: colorScheme).opacity(0.15))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "person.fill.badge.plus")
                        .font(.system(size: 34))
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                }

            Text("Profilini Oluştur")
                .font(.title2.bold())
                .foregroundStyle(LeafColors.textPrimary(for: colorScheme))

            Text("Kitap dostlarını bulmak için\nbir profil oluştur.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(spacing: LeafSpacing.md) {

            // Kullanıcı adı
            VStack(alignment: .leading, spacing: LeafSpacing.xs) {
                Label("Kullanıcı Adı", systemImage: "at")
                    .font(.caption.bold())
                    .foregroundStyle(LeafColors.textSecondary(for: colorScheme))

                TextField("en az 3 karakter", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(LeafSpacing.md)
                    .background(LeafColors.surfacePrimary(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: LeafRadius.medium))
                    .overlay {
                        RoundedRectangle(cornerRadius: LeafRadius.medium)
                            .stroke(LeafColors.borderSubtle(for: colorScheme))
                    }
            }

            // Yaş
            VStack(alignment: .leading, spacing: LeafSpacing.xs) {
                Label("Yaş", systemImage: "calendar")
                    .font(.caption.bold())
                    .foregroundStyle(LeafColors.textSecondary(for: colorScheme))

                TextField("Yaşını gir", text: $ageText)
                    .keyboardType(.numberPad)
                    .padding(LeafSpacing.md)
                    .background(LeafColors.surfacePrimary(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: LeafRadius.medium))
                    .overlay {
                        RoundedRectangle(cornerRadius: LeafRadius.medium)
                            .stroke(LeafColors.borderSubtle(for: colorScheme))
                    }
            }

            // Bio
            VStack(alignment: .leading, spacing: LeafSpacing.xs) {
                Label("Hakkında (opsiyonel)", systemImage: "text.quote")
                    .font(.caption.bold())
                    .foregroundStyle(LeafColors.textSecondary(for: colorScheme))

                TextField("Kendini kısaca tanıt...", text: $bio, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(LeafSpacing.md)
                    .background(LeafColors.surfacePrimary(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: LeafRadius.medium))
                    .overlay {
                        RoundedRectangle(cornerRadius: LeafRadius.medium)
                            .stroke(LeafColors.borderSubtle(for: colorScheme))
                    }
            }

            if let errorMessage = social.error {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(LeafSpacing.lg)
        .background(LeafColors.surfacePrimary(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: LeafRadius.xlarge))
        .overlay {
            RoundedRectangle(cornerRadius: LeafRadius.xlarge)
                .stroke(LeafColors.borderSubtle(for: colorScheme))
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button {
            guard let userAge = age else { return }

            Task {
                let success = await social.createProfile(
                    username: username.trimmingCharacters(in: .whitespaces),
                    bio: bio.trimmingCharacters(in: .whitespaces),
                    age: userAge
                )
                // profil oluşturuldu — 18 yaş altıysa bilgilendirme göster
                if success && userAge < 18 {
                    showUnderageAlert = true
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: LeafRadius.large)
                    .fill(isFormValid
                          ? LeafColors.accent(for: colorScheme)
                          : LeafColors.textTertiary(for: colorScheme).opacity(0.3))
                    .frame(height: 54)

                if social.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Profili Oluştur")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        .disabled(!isFormValid || social.isLoading)
    }
}
