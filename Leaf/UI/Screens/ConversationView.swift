import SwiftUI

// MARK: - ConversationView

struct ConversationView: View {
    let conversationId: String
    let otherUsername: String

    @EnvironmentObject var socialService: SocialService
    @EnvironmentObject var auth: SupabaseAuthService
    @Environment(\.colorScheme) var colorScheme

    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool

    private var currentUserId: String {
        auth.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        ZStack {
            LeafGradientBackground()

            messageListView
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    inputArea
                }
        }
        .navigationTitle(otherUsername)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await socialService.fetchMessages(conversationId: conversationId)
            await socialService.subscribeToMessages(conversationId: conversationId)
            PushNotificationService.shared.clearBadge()
        }
        .onDisappear {
            Task {
                await socialService.unsubscribe()
                await socialService.fetchConversations()
            }
        }
    }

    // MARK: - Mesaj Listesi

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(socialService.messages) { message in
                        let isOwn = message.senderId == currentUserId
                        MessageBubble(message: message, isOwn: isOwn) {
                            Task { await socialService.deleteMessage(message) }
                        }
                        .id(message.id)
                    }
                }
                .padding(.horizontal, LeafSpacing.md)
                .padding(.vertical, LeafSpacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isTextFieldFocused = false
            }
            .onChange(of: socialService.messages.count) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = socialService.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.4)

            inputBar
                .padding(.horizontal, LeafSpacing.sm)
                .padding(.vertical, LeafSpacing.xs)
                .padding(.bottom, 4)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: LeafSpacing.xs) {
            TextField("Mesaj yaz...", text: $messageText, axis: .vertical)
                .lineLimit(1...5)
                .focused($isTextFieldFocused)
                .font(.body)
                .padding(.horizontal, LeafSpacing.sm)
                .padding(.vertical, LeafSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: LeafRadius.xlarge)
                        .fill(LeafColors.surfacePrimary(for: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: LeafRadius.xlarge)
                                .stroke(LeafColors.borderSubtle(for: colorScheme), lineWidth: 1)
                        )
                )

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        messageText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? LeafColors.textTertiary(for: colorScheme)
                            : LeafColors.accent(for: colorScheme)
                    )
                    .animation(LeafMotion.fast, value: messageText.isEmpty)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.bottom, 2)
        }
    }

    // MARK: - Gönder

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messageText = ""
        Task {
            await socialService.sendMessage(conversationId: conversationId, content: text)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isOwn: Bool
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .bottom, spacing: LeafSpacing.xxs) {
            if isOwn { Spacer(minLength: 56) }

            VStack(alignment: isOwn ? .trailing : .leading, spacing: 3) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(isOwn ? .white : LeafColors.textPrimary(for: colorScheme))
                    .padding(.horizontal, LeafSpacing.sm)
                    .padding(.vertical, 9)
                    .background(
                        isOwn
                            ? LeafColors.accent(for: colorScheme)
                            : LeafColors.surfacePrimary(for: colorScheme)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: LeafRadius.large))
                    .overlay {
                        if !isOwn {
                            RoundedRectangle(cornerRadius: LeafRadius.large)
                                .stroke(LeafColors.borderSubtle(for: colorScheme), lineWidth: 1)
                        }
                    }
                    .contextMenu {
                        if isOwn {
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Mesajı Sil", systemImage: "trash")
                            }
                        }
                    }

                Text(message.createdAt.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                    .padding(.horizontal, LeafSpacing.xxs)
            }

            if !isOwn { Spacer(minLength: 56) }
        }
    }
}
