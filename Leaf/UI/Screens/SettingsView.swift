import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject private var auth: SupabaseAuthService
    @Environment(SocialService.self) private var social
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // Tema
    @AppStorage("appTheme") private var appTheme: String = "system"

    // Profil düzenleme
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm  = false
    @State private var showDeleteError    = false
    @State private var isDeleting         = false
    @State private var showPrivacyPolicy  = false

    // Fotoğraf ve şehir — sadece 18+ profillerde (eşleşme amaçlı alanlar)
    @State private var newPhoto: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var showCityPicker = false
    @State private var isSavingCity = false

    // Şehir ve sosyal özellikler switch'i gibi "seçince hemen kaydedilen" alanlar
    // için — üstteki "Kaydet" butonuna basmaya gerek yok ama kullanıcı bunu
    // anlamıyordu, o yüzden kısa bir "Kaydedildi" toast'ı + haptic ekliyoruz.
    @State private var showSavedToast = false

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                List {
                    profileSection
                    socialSection
                    themeSection
                    legalSection
                    accountSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)

                if showSavedToast {
                    VStack {
                        Spacer()
                        Label("Kaydedildi", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, LeafSpacing.md)
                            .padding(.vertical, LeafSpacing.sm)
                            .background(.black.opacity(0.85), in: Capsule())
                            .padding(.bottom, LeafSpacing.xl)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
                }
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
            .alert("Hesap Silinemedi", isPresented: $showDeleteError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text("Bir hata oluştu. Lütfen tekrar dene.")
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showCityPicker) {
                CityPickerSheet(selectedCity: cityBinding)
            }
            .onAppear { loadCurrentValues() }
            .onChange(of: newPhoto) { _, newValue in
                Task {
                    guard let data = try? await newValue?.loadTransferable(type: Data.self) else { return }
                    isUploadingPhoto = true
                    let success = await social.uploadProfilePhoto(data)
                    isUploadingPhoto = false
                    // avatarView artık social.myPhotoReveal'ı okuyor — uploadProfilePhoto
                    // başarılı olunca onu zaten günceller, burada ekstra bir şey gerekmiyor.
                }
            }
        }
        .preferredColorScheme(resolvedScheme)
    }

    private var isAdultProfile: Bool { (social.currentProfile?.age ?? 0) >= 18 }

    private var cityBinding: Binding<String?> {
        Binding(
            get: { social.currentProfile?.city },
            set: { newValue in
                guard let newValue else { return }
                isSavingCity = true
                Task {
                    let success = await social.updateCity(newValue)
                    isSavingCity = false
                    if success { flashSaved() }
                }
            }
        )
    }

    // Otomatik kaydedilen alanlar (şehir, sosyal özellikler switch'i) için kısa
    // bir onay — haptic + 1.2sn görünüp kaybolan toast.
    private func flashSaved() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeOut(duration: 0.2)) { showSavedToast = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeIn(duration: 0.3)) { showSavedToast = false }
        }
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
                avatarView

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

            if isAdultProfile {
                Button {
                    showCityPicker = true
                } label: {
                    LabeledContent("Şehir") {
                        HStack(spacing: LeafSpacing.xs) {
                            if isSavingCity { ProgressView() }
                            Text(social.currentProfile?.city ?? "Seç")
                                .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                        }
                    }
                    .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                }
                .buttonStyle(.plain)
                .disabled(isSavingCity)
                .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))
            }
        } header: {
            Text("Profil")
        }
    }

    // Sadece 18+ profillerde tıklanarak fotoğraf değiştirilebilir — reşit
    // olmayanlardan eşleşme fotoğrafı toplamıyoruz, düz baş harf avatarı kalıyor.
    @ViewBuilder
    private var avatarView: some View {
        if isAdultProfile {
            PhotosPicker(selection: $newPhoto, matching: .images) {
                ZStack {
                    // social.myPhotoReveal paylaşılan bir state — Kitaplığım'daki avatar
                    // ve burası aynı kaynağı okur, upload sonrası ikisi de anında güncellenir.
                    if case .revealed = social.myPhotoReveal?.stage, let url = social.myPhotoReveal?.url {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                            } else {
                                letterAvatar
                            }
                        }
                    } else {
                        letterAvatar
                    }

                    if isUploadingPhoto {
                        Circle()
                            .fill(.black.opacity(0.35))
                            .frame(width: 56, height: 56)
                        ProgressView().tint(.white)
                    } else {
                        Circle()
                            .stroke(LeafColors.borderSubtle(for: colorScheme), lineWidth: 1)
                            .frame(width: 56, height: 56)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(LeafColors.accent(for: colorScheme), in: Circle())
                            .offset(x: 20, y: 20)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isUploadingPhoto)
        } else {
            letterAvatar
        }
    }

    private var letterAvatar: some View {
        Circle()
            .fill(LeafColors.accent(for: colorScheme).opacity(0.15))
            .frame(width: 56, height: 56)
            .overlay {
                Text((social.currentProfile?.username ?? auth.currentUser?.email ?? "?").prefix(1).uppercased())
                    .font(.title2.bold())
                    .foregroundStyle(LeafColors.accent(for: colorScheme))
            }
    }

    // MARK: - Sosyal Bölümü

    private var socialFeaturesBinding: Binding<Bool> {
        Binding(
            get: { social.currentProfile?.socialEnabled ?? true },
            set: { newValue in
                Task {
                    let success = await social.updateSocialEnabled(newValue)
                    if success { flashSaved() }
                }
            }
        )
    }

    private var socialSection: some View {
        Section {
            Toggle(isOn: socialFeaturesBinding) {
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

            NavigationLink {
                BlockedUsersView()
            } label: {
                Label("Engellenen Kullanıcılar", systemImage: "hand.raised.fill")
                    .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
            }
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

    // MARK: - Yasal Bölüm

    private var legalSection: some View {
        Section {
            Button {
                showPrivacyPolicy = true
            } label: {
                Label("Gizlilik Politikası", systemImage: "lock.shield")
                    .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
            }
            .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))
        } header: {
            Text("Yasal")
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
            .confirmationDialog("Çıkış yapmak istediğine emin misin?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Çıkış Yap", role: .destructive) {
                    Task { await auth.signOut() }
                }
                Button("İptal", role: .cancel) { }
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                if isDeleting {
                    HStack {
                        ProgressView().tint(.red)
                        Text("Siliniyor...").foregroundStyle(.red)
                    }
                } else {
                    Label("Hesabı Sil", systemImage: "person.crop.circle.badge.minus")
                        .foregroundStyle(.red)
                }
            }
            .disabled(isDeleting)
            .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))
            .confirmationDialog(
                "Hesabını kalıcı olarak silmek istediğine emin misin?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Hesabı Sil", role: .destructive) {
                    isDeleting = true
                    Task {
                        let ok = await auth.deleteAccount()
                        isDeleting = false
                        if !ok { showDeleteError = true }
                    }
                }
                Button("İptal", role: .cancel) { }
            } message: {
                Text("Tüm verilerin, mesajların ve profilin kalıcı olarak silinecek. Bu işlem geri alınamaz.")
            }
        } header: {
            Text("Hesap")
        } footer: {
            Text("Hesabını silersen tüm veriler kalıcı olarak kaldırılır.")
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
