import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: SupabaseAuthService
    @EnvironmentObject private var social: SocialService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // Tema
    @AppStorage("appTheme") private var appTheme: String = "system"
    // Sosyal özellikler toggle
    @AppStorage("socialFeaturesEnabled") private var socialFeaturesEnabled: Bool = true

    // Profil düzenleme
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                List {
                    profileSection
                    socialSection
                    themeSection
                    accountSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(LeafColors.accent(for: colorScheme))
                        } else {
                            Text("Kaydet").fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(LeafColors.accent(for: colorScheme))
                    .disabled(isSaving || !profileChanged)
                }
            }
            .alert("Kaydedildi", isPresented: $showSaveSuccess) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text("Profil bilgilerin güncellendi.")
            }
            .confirmationDialog("Çıkış yapmak istediğine emin misin?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Çıkış Yap", role: .destructive) {
                    Task { await auth.signOut() }
                }
                Button("İptal", role: .cancel) { }
            }
            .onAppear { loadCurrentValues() }
        }
        .preferredColorScheme(resolvedScheme)
    }

    private var resolvedScheme: ColorScheme? {
        switch appTheme {
        case "light": .light
        case "dark":  .dark
        default:      nil
        }
    }

    // MARK: - Profil Bölümü

    private var profileSection: some View {
        Section {
            HStack(spacing: LeafSpacing.md) {
                Circle()
                    .fill(LeafColors.accent(for: colorScheme).opacity(0.15))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Text((social.currentProfile?.username ?? auth.currentUser?.email ?? "?").prefix(1).uppercased())
                            .font(.title2.bold())
                            .foregroundStyle(LeafColors.accent(for: colorScheme))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(social.currentProfile?.username ?? "Kullanıcı")
                        .font(.headline)
                        .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                    if let email = auth.currentUser?.email {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                    }
                }
            }
            .padding(.vertical, LeafSpacing.xs)
            .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))

            LabeledContent("Kullanıcı Adı") {
                TextField("kullanici_adi", text: $username)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))

            LabeledContent("Biyografi") {
                TextField("Kendini tanıt...", text: $bio)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
            }
            .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))

            if let age = social.currentProfile?.age {
                LabeledContent("Yaş") {
                    Text("\(age)")
                        .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                }
                .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))
            }
        } header: {
            Text("Profil")
        }
    }

    // MARK: - Sosyal Bölümü

    private var socialSection: some View {
        Section {
            Toggle(isOn: $socialFeaturesEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sosyal Özellikler")
                            .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                        Text("Keşfet ve Mesajlar sekmelerini göster")
                            .font(.caption)
                            .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                    }
                } icon: {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                }
            }
            .tint(LeafColors.accent(for: colorScheme))
            .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))
        } header: {
            Text("Sohbet")
        } footer: {
            Text("Kapatırsanız Keşfet ve Mesajlar sekmeleri gizlenir, sohbetleriniz silinmez.")
        }
    }

    // MARK: - Tema Bölümü

    private var themeSection: some View {
        Section {
            Picker("Tema", selection: $appTheme) {
                Label("Sistem", systemImage: "sparkles").tag("system")
                Label("Açık", systemImage: "sun.max").tag("light")
                Label("Koyu", systemImage: "moon").tag("dark")
            }
            .pickerStyle(.menu)
            .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
            .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))
        } header: {
            Text("Görünüm")
        }
    }

    // MARK: - Hesap Bölümü

    private var accountSection: some View {
        Section {
            Button(role: .destructive) {
                showSignOutConfirm = true
            } label: {
                Label("Çıkış Yap", systemImage: "arrow.right.circle.fill")
                    .foregroundStyle(.red)
            }
            .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))
        } header: {
            Text("Hesap")
        }
    }

    // MARK: - Helpers

    private var profileChanged: Bool {
        username != (social.currentProfile?.username ?? "") ||
        bio != (social.currentProfile?.bio ?? "")
    }

    private func loadCurrentValues() {
        username = social.currentProfile?.username ?? ""
        bio      = social.currentProfile?.bio ?? ""
    }

    private func saveProfile() async {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSaving = true
        let success = await social.updateProfile(username: username, bio: bio)
        isSaving = false
        if success { showSaveSuccess = true }
    }
}
