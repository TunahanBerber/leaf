import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @EnvironmentObject var social: SocialService
    @Environment(\.colorScheme) var colorScheme

    @State private var username = ""
    @State private var bio = ""
    @State private var ageText = ""
    @State private var showUnderageAlert = false

    // Eşleşme amaçlı alanlar — sadece 18 yaş üzeri onboarding'de gösteriliyor,
    // reşit olmayanlardan bu veriler hiç toplanmıyor. Fotoğraf opsiyonel: onboarding'i
    // fotoğrafsız da tamamlayabilirsin, sonradan Ayarlar'dan eklersin.
    @State private var photo: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var selectedGender: Gender?
    @State private var selectedInterests: Set<Gender> = []
    @State private var selectedCity: String?
    @State private var showCityPicker = false

    private var age: Int? { Int(ageText) }
    private var isAdult: Bool { (age ?? 0) >= 18 }

    private var isFormValid: Bool {
        guard username.trimmingCharacters(in: .whitespaces).count >= 3, (age ?? 0) >= 1 else {
            return false
        }
        guard isAdult else { return true }
        return selectedGender != nil && !selectedInterests.isEmpty && selectedCity != nil
    }

    var body: some View {
        ZStack {
            LeafGradientBackground()

            ScrollView {
                VStack(spacing: LeafSpacing.xl) {
                    header
                    if isAdult { photoPicker }
                    formCard
                    createButton
                    Spacer(minLength: LeafSpacing.xxl)
                }
                .padding(.horizontal, LeafSpacing.md)
                .padding(.top, LeafSpacing.xxxl)
                .animation(.easeInOut(duration: 0.25), value: isAdult)
            }
        }
        .alert("Yaş Sınırı", isPresented: $showUnderageAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("Sosyal özellikler 18 yaş ve üzeri kullanıcılara açıktır.\nYine de kitap takibine devam edebilirsin.")
        }
        .onChange(of: photo) { _, newValue in
            Task { @MainActor in
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
        .sheet(isPresented: $showCityPicker) {
            CityPickerSheet(selectedCity: $selectedCity)
        }
    }

    // MARK: - Photo Picker (WhatsApp tarzı, sadece 18+ onboarding'de)

    private var photoPicker: some View {
        let s = colorScheme
        let data = photoData
        return PhotosPicker(selection: $photo, matching: .images) {
            ZStack {
                Circle()
                    .fill(LeafColors.accent(for: s).opacity(0.15))
                    .frame(width: 108, height: 108)

                if let data, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 108, height: 108)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(LeafColors.accent(for: s))
                }

                Circle()
                    .stroke(LeafColors.borderSubtle(for: s), lineWidth: 1)
                    .frame(width: 108, height: 108)
            }
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

            if isAdult {
                genderSection
                interestsSection
                citySection
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

    // MARK: - Cinsiyet

    private var genderSection: some View {
        VStack(alignment: .leading, spacing: LeafSpacing.xs) {
            Label("Cinsiyet", systemImage: "person.fill")
                .font(.caption.bold())
                .foregroundStyle(LeafColors.textSecondary(for: colorScheme))

            Picker("Cinsiyet", selection: $selectedGender) {
                Text("Seç").tag(Gender?.none)
                ForEach(Gender.allCases) { g in
                    Text(g.displayName).tag(Gender?.some(g))
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - İlgi Alanı

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: LeafSpacing.xs) {
            Label("Kimlerle Eşleşmek İstersin", systemImage: "heart.fill")
                .font(.caption.bold())
                .foregroundStyle(LeafColors.textSecondary(for: colorScheme))

            HStack(spacing: LeafSpacing.sm) {
                ForEach(Gender.allCases) { g in
                    let isSelected = selectedInterests.contains(g)
                    Button {
                        if isSelected { selectedInterests.remove(g) } else { selectedInterests.insert(g) }
                    } label: {
                        Text(g.displayName)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, LeafSpacing.md)
                            .padding(.vertical, LeafSpacing.sm)
                            .background(
                                isSelected
                                    ? LeafColors.accent(for: colorScheme)
                                    : LeafColors.surfacePrimary(for: colorScheme)
                            )
                            .foregroundStyle(isSelected ? .white : LeafColors.textPrimary(for: colorScheme))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule().stroke(LeafColors.borderSubtle(for: colorScheme))
                            }
                    }
                }
            }
        }
    }

    // MARK: - Şehir

    private var citySection: some View {
        VStack(alignment: .leading, spacing: LeafSpacing.xs) {
            Label("Şehir", systemImage: "mappin.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(LeafColors.textSecondary(for: colorScheme))

            Button {
                showCityPicker = true
            } label: {
                HStack {
                    Text(selectedCity ?? "Şehir seç")
                        .foregroundStyle(
                            selectedCity == nil
                                ? LeafColors.textTertiary(for: colorScheme)
                                : LeafColors.textPrimary(for: colorScheme)
                        )
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                }
                .padding(LeafSpacing.md)
                .background(LeafColors.surfacePrimary(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: LeafRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: LeafRadius.medium)
                        .stroke(LeafColors.borderSubtle(for: colorScheme))
                }
            }
            .buttonStyle(.plain)
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
                    age: userAge,
                    gender: isAdult ? selectedGender : nil,
                    interestedIn: isAdult ? Array(selectedInterests) : nil,
                    city: isAdult ? selectedCity : nil,
                    photoData: isAdult ? photoData : nil
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
