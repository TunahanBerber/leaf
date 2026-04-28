import SwiftUI

struct UserProfileView: View {
    let profile: UserProfile
    @EnvironmentObject var socialService: SocialService
    @Environment(\.colorScheme) var colorScheme

    @State private var requestStatus: String? = nil   // nil | "pending" | "accepted"
    @State private var isLoading = false
    @State private var existingConvId: String?        // yüklenen mevcut sohbet ID'si (navigation tetiklemez)
    @State private var navigateToConvId: String?      // sadece kullanıcı butona basınca set edilir
    @State private var showSuccess = false

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
        .task { await loadStatus() }
        .navigationDestination(item: $navigateToConvId) { convId in
            ConversationView(conversationId: convId, otherUsername: profile.username)
                .environmentObject(socialService)
        }
        .alert("İstek Gönderildi", isPresented: $showSuccess) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("\(profile.username) isteği kabul ederse sohbet başlayacak.")
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: LeafSpacing.md) {
            Circle()
                .fill(LeafColors.accent(for: colorScheme).opacity(0.15))
                .frame(width: 96, height: 96)
                .overlay {
                    Text(profile.username.prefix(1).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                }

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
