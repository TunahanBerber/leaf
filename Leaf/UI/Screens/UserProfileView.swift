import SwiftUI

struct UserProfileView: View {
    let profile: UserProfile
    @Environment(SocialService.self) var socialService
    @Environment(\.colorScheme) var colorScheme

    @State private var requestStatus: String? = nil   // nil | "pending" | "accepted"
    @State private var isLoading = false
    @State private var existingConvId: String?        // yüklenen mevcut sohbet ID'si (navigation tetiklemez)
    @State private var navigateToConvId: String?      // sadece kullanıcı butona basınca set edilir
    @State private var showSuccess = false
    @State private var showBlockConfirm  = false
    @State private var showReportSheet   = false
    @State private var showReportSuccess = false
    @State private var showBlockSuccess  = false

    var body: some View {
        ZStack {
            LeafGradientBackground()

            ScrollView {
                VStack(spacing: LeafSpacing.xl) {
                    profileHeader
                    commonBooksSection
                    actionButton
                }
                .padding(.horizontal, LeafSpacing.md)
                .padding(.top, LeafSpacing.lg)
            }
        }
        .navigationTitle(profile.username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showBlockConfirm = true
                    } label: {
                        Label("Engelle", systemImage: "hand.raised.fill")
                    }
                    Button {
                        showReportSheet = true
                    } label: {
                        Label("Şikayet Et", systemImage: "flag.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                }
            }
        }
        .task { await loadStatus() }
        .navigationDestination(item: $navigateToConvId) { convId in
            ConversationView(conversationId: convId, otherUsername: profile.username)
        }
        .alert("İstek Gönderildi", isPresented: $showSuccess) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("\(profile.username) isteği kabul ederse sohbet başlayacak.")
        }
        .confirmationDialog(
            "\(profile.username) adlı kullanıcıyı engellemek istediğine emin misin?",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Engelle", role: .destructive) {
                Task {
                    if await socialService.blockUser(userId: profile.id) {
                        showBlockSuccess = true
                    }
                }
            }
            Button("İptal", role: .cancel) { }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheet(username: profile.username) { reason, description in
                Task {
                    let ok = await socialService.reportUser(userId: profile.id, reason: reason, description: description)
                    if ok { showReportSuccess = true }
                }
            }
        }
        .alert("Şikayet İletildi", isPresented: $showReportSuccess) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("Bildirimin alındı. En kısa sürede incelenecek.")
        }
        .alert("Kullanıcı Engellendi", isPresented: $showBlockSuccess) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("\(profile.username) artık sana mesaj gönderemez.")
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: LeafSpacing.md) {
            RevealablePhotoView(userId: profile.id, conversationId: existingConvId, size: 96)

            VStack(spacing: LeafSpacing.xxs) {
                HStack(spacing: LeafSpacing.xs) {
                    Text(profile.username)
                        .font(.title2.bold())
                        .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                    if let age = profile.age {
                        Text("\(age)")
                            .font(.title3)
                            .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                    }
                }

                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(LeafSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(LeafColors.surfacePrimary(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: LeafRadius.xlarge))
        .overlay {
            RoundedRectangle(cornerRadius: LeafRadius.xlarge)
                .stroke(LeafColors.borderSubtle(for: colorScheme))
        }
    }

    // MARK: - Ortak Kitaplar

    @ViewBuilder
    private var commonBooksSection: some View {
        if let books = profile.commonBookTitles, !books.isEmpty {
            VStack(alignment: .leading, spacing: LeafSpacing.sm) {
                Text("Ortak Kitaplar")
                    .font(.headline)
                    .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                    .padding(.horizontal, LeafSpacing.xs)

                VStack(spacing: LeafSpacing.xs) {
                    ForEach(books, id: \.self) { title in
                        HStack(spacing: LeafSpacing.sm) {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(LeafColors.accent(for: colorScheme))
                                .font(.subheadline)
                            Text(title)
                                .font(.subheadline)
                                .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                            Spacer()
                        }
                        .padding(.horizontal, LeafSpacing.md)
                        .padding(.vertical, LeafSpacing.sm)
                        .background(LeafColors.surfacePrimary(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: LeafRadius.medium))
                        .overlay {
                            RoundedRectangle(cornerRadius: LeafRadius.medium)
                                .stroke(LeafColors.borderSubtle(for: colorScheme))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Aksiyon Butonu

    @ViewBuilder
    private var actionButton: some View {
        if requestStatus == "accepted" {
            // sohbet zaten var → kullanıcı butona basınca aç
            Button {
                Task {
                    isLoading = true
                    if let convId = existingConvId {
                        navigateToConvId = convId
                    } else {
                        navigateToConvId = await socialService.fetchExistingConversationId(with: profile.id)
                    }
                    isLoading = false
                }
            } label: {
                buttonLabel(
                    icon: "message.fill",
                    text: "Sohbeti Aç",
                    color: LeafColors.accent(for: colorScheme)
                )
            }
            .disabled(isLoading)

        } else if requestStatus == "pending" {
            // istek gönderildi, bekleniyor
            buttonLabel(
                icon: "clock.fill",
                text: "İstek Gönderildi",
                color: LeafColors.textTertiary(for: colorScheme).opacity(0.5)
            )

        } else {
            // istek gönder
            Button {
                Task {
                    isLoading = true
                    let success = await socialService.sendConversationRequest(to: profile.id)
                    if success {
                        requestStatus = "pending"
                        showSuccess = true
                    }
                    isLoading = false
                }
            } label: {
                buttonLabel(
                    icon: "paperplane.fill",
                    text: "Sohbet İsteği Gönder",
                    color: LeafColors.accent(for: colorScheme)
                )
            }
            .disabled(isLoading)
        }
    }

    private func buttonLabel(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: LeafSpacing.sm) {
            if isLoading {
                ProgressView().tint(.white)
            } else {
                Image(systemName: icon)
                Text(text).fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LeafSpacing.md)
        .background(color)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: LeafRadius.large))
    }

    // MARK: - Helpers

    private func loadStatus() async {
        // zaten kabul edilmiş sohbet var mı?
        if let convId = await socialService.fetchExistingConversationId(with: profile.id) {
            existingConvId = convId   // sadece sakla, navigation tetikleme
            requestStatus = "accepted"
            return
        }
        // pending istek var mı?
        requestStatus = await socialService.checkRequestStatus(to: profile.id)
    }
}
