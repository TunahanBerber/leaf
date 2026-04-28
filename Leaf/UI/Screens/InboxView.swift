import SwiftUI

struct InboxView: View {
    @EnvironmentObject var socialService: SocialService
    @EnvironmentObject var auth: SupabaseAuthService
    @Environment(\.colorScheme) var colorScheme

    // kabul sonrası açılacak sohbet
    @State private var navigateToConvId: String?
    @State private var navigateToUsername: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                Group {
                    if socialService.isLoading {
                        ProgressView()
                            .tint(LeafColors.accent(for: colorScheme))
                    } else if socialService.pendingRequests.isEmpty && socialService.conversations.isEmpty {
                        emptyState
                    } else {
                        contentList
                    }
                }
            }
            .navigationTitle("Mesajlar")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await socialService.fetchPendingRequests()
                await socialService.fetchConversations()
            }
            .onDisappear {
                // Tab değiştirilince navigation state'ini sıfırla
                navigateToConvId = nil
                navigateToUsername = nil
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { notification in
                guard let convId = notification.userInfo?["conversationId"] as? String else { return }
                navigateToUsername = notification.userInfo?["username"] as? String ?? "Kullanıcı"
                navigateToConvId = convId
            }
            .navigationDestination(item: $navigateToConvId) { convId in
                ConversationView(
                    conversationId: convId,
                    otherUsername: navigateToUsername ?? "Kullanıcı"
                )
                .environmentObject(socialService)
                .environmentObject(auth)
            }
        }
    }

    // MARK: - Content List

    private var contentList: some View {
        List {
            // Bekleyen istekler
            if !socialService.pendingRequests.isEmpty {
                Section {
                    ForEach(socialService.pendingRequests) { request in
                        RequestRow(
                            request: request,
                            onAccepted: { convId, username in
                                navigateToUsername = username
                                navigateToConvId = convId
                            }
                        )
                        .environmentObject(socialService)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    sectionHeader("Sohbet İstekleri", badge: socialService.pendingRequests.count)
                }
            }

            // Aktif sohbetler
            if !socialService.conversations.isEmpty {
                Section {
                    ForEach(socialService.conversations) { conversation in
                        NavigationLink {
                            ConversationView(
                                conversationId: conversation.id,
                                otherUsername: conversation.otherUser?.username ?? "Kullanıcı"
                            )
                            .environmentObject(socialService)
                            .environmentObject(auth)
                        } label: {
                            ConversationRow(conversation: conversation)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await socialService.deleteConversation(conversation) }
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    sectionHeader("Sohbetler", badge: nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func sectionHeader(_ title: String, badge: Int?) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(LeafColors.textSecondary(for: colorScheme))

            if let count = badge {
                Text("\(count)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(LeafColors.accent(for: colorScheme))
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, LeafSpacing.xs)
        .padding(.top, LeafSpacing.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: LeafSpacing.md) {
            Image(systemName: "message.slash")
                .font(.system(size: 48))
                .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
            Text("Henüz mesajın yok")
                .font(.headline)
                .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
            Text("Keşfet ekranından\nkitap dostlarını bul.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
        }
        .padding(LeafSpacing.xxl)
    }
}

// MARK: - Request Row

struct RequestRow: View {
    let request: ConversationRequest
    let onAccepted: (String, String) -> Void   // convId, username

    @EnvironmentObject var socialService: SocialService
    @Environment(\.colorScheme) var colorScheme
    @State private var isActing = false

    var displayName: String {
        request.senderProfile?.username ?? String(request.senderId.prefix(8))
    }

    var body: some View {
        HStack(spacing: LeafSpacing.md) {
            // Avatar
            Circle()
                .fill(LeafColors.accent(for: colorScheme).opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(displayName.prefix(1).uppercased())
                        .font(.headline.bold())
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                }

            VStack(alignment: .leading, spacing: LeafSpacing.xxs) {
                Text(displayName)
                    .font(.headline)
                    .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                Text("Sohbet isteği gönderdi")
                    .font(.caption)
                    .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
            }

            Spacer()

            if isActing {
                ProgressView()
                    .tint(LeafColors.accent(for: colorScheme))
            } else {
                HStack(spacing: LeafSpacing.xs) {
                    // Reddet
                    Button {
                        isActing = true
                        Task {
                            await socialService.rejectRequest(request)
                            isActing = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                    }

                    // Kabul et
                    Button {
                        isActing = true
                        Task {
                            if let convId = await socialService.acceptRequest(request) {
                                onAccepted(convId, displayName)
                            }
                            isActing = false
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(LeafColors.accent(for: colorScheme))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(LeafSpacing.md)
        .background(LeafColors.surfacePrimary(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: LeafRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: LeafRadius.large)
                .stroke(LeafColors.accent(for: colorScheme).opacity(0.3))
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    @Environment(\.colorScheme) var colorScheme

    private var displayName: String {
        conversation.otherUser?.username ?? "Kullanıcı"
    }

    var body: some View {
        HStack(spacing: LeafSpacing.md) {
            Circle()
                .fill(LeafColors.accent(for: colorScheme).opacity(0.15))
                .frame(width: 52, height: 52)
                .overlay {
                    Text(displayName.prefix(1).uppercased())
                        .font(.title3.bold())
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                }

            VStack(alignment: .leading, spacing: LeafSpacing.xxs) {
                Text(displayName)
                    .font(.headline)
                    .foregroundStyle(LeafColors.textPrimary(for: colorScheme))

                if let last = conversation.lastMessage {
                    Text(last.content)
                        .font(.subheadline)
                        .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
                        .lineLimit(1)
                } else {
                    Text("Sohbete başla")
                        .font(.subheadline)
                        .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                }
            }

            Spacer()

            if let last = conversation.lastMessage {
                Text(last.createdAt.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
            }
        }
        .padding(LeafSpacing.md)
        .background(LeafColors.surfacePrimary(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: LeafRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: LeafRadius.large)
                .stroke(LeafColors.borderSubtle(for: colorScheme))
        }
    }
}
