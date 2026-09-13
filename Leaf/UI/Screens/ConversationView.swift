import SwiftUI

// MARK: - ConversationView

struct ConversationView: View {
    let conversationId: String
    let otherUsername: String

    @Environment(SocialService.self) var socialService
    @EnvironmentObject var auth: SupabaseAuthService
    @Environment(\.colorScheme) var colorScheme

    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showBlockConfirm  = false
    @State private var showReportSheet   = false
    @State private var showReportSuccess = false
    @State private var messageToReport: Message?   // context menüden mesaj bazlı şikayet
    @State private var filterWarning: String?

    private var currentUserId: String {
        auth.currentUser?.id.uuidString.lowercased() ?? ""
    }

    private var otherUserId: String? {
        guard let conv = socialService.conversations.first(where: { $0.id == conversationId }) else { return nil }
        return conv.userAId == currentUserId ? conv.userBId : conv.userAId
    }

    var body: some View {
        ZStack {
            LeafGradientBackground()

            messageListView
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    inputArea
                }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: LeafSpacing.xs) {
                    if let otherUserId {
                        RevealablePhotoView(userId: otherUserId, conversationId: conversationId, size: 32)
                    }
                    Text(otherUsername)
                        .font(.headline)
                        .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                }
            }
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
        .confirmationDialog(
            "\(otherUsername) adlı kullanıcıyı engellemek istediğine emin misin?",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Engelle", role: .destructive) {
                guard let uid = otherUserId else { return }
                Task { await socialService.blockUser(userId: uid) }
            }
            Button("İptal", role: .cancel) { }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheet(username: otherUsername) { reason, description in
                guard let uid = otherUserId else { return }
                Task {
                    let ok = await socialService.reportUser(userId: uid, reason: reason, description: description)
                    if ok { showReportSuccess = true }
                }
            }
        }
        .sheet(item: $messageToReport) { message in
            ReportSheet(username: otherUsername) { reason, description in
                Task {
                    let ok = await socialService.reportUser(
                        userId: message.senderId,
                        reason: reason,
                        messageId: message.id,
                        description: description
                    )
                    if ok { showReportSuccess = true }
                }
            }
        }
        .alert("Şikayet İletildi", isPresented: $showReportSuccess) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("Bildirimin alındı. En kısa sürede incelenecek.")
        }
        .alert("Mesaj Gönderilemedi", isPresented: Binding(get: { filterWarning != nil }, set: { if !$0 { filterWarning = nil } })) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(filterWarning ?? "")
        }
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
                        MessageBubble(
                            message: message,
                            isOwn: isOwn,
                            onDelete: { Task { await socialService.deleteMessage(message) } },
                            onReport: isOwn ? nil : { messageToReport = message }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, LeafSpacing.md)
                .padding(.vertical, LeafSpacing.md)
            }
            .defaultScrollAnchor(.bottom)
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

        guard ContentFilter.isAllowed(text) else {
            filterWarning = "Mesajın uygunsuz içerik barındırdığı için gönderilemedi."
            return
        }

        messageText = ""
        Task {
            await socialService.sendMessage(conversationId: conversationId, content: text)
        }
    }
}

// MARK: - Report Sheet

struct ReportSheet: View {
    let username: String
    let onSubmit: (_ reason: String, _ description: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedReason: String?
    @State private var description = ""
    @FocusState private var isDescriptionFocused: Bool

    private let reasons = [
        "Taciz",
        "Spam",
        "Uygunsuz İçerik",
        "Diğer"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                List {
                    Section {
                        ForEach(reasons, id: \.self) { reason in
                            Button {
                                selectedReason = reason
                            } label: {
                                HStack {
                                    Text(reason)
                                        .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                                    Spacer()
                                    if selectedReason == reason {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(LeafColors.accent(for: colorScheme))
                                    }
                                }
                            }
                            .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))
                        }
                    } header: {
                        Text("Sebep")
                    }

                    Section {
                        TextField("İsteğe bağlı, kısaca açıkla...", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                            .focused($isDescriptionFocused)
                            .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                            .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))
                    } header: {
                        Text("Açıklama")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("\(username) Şikayet Et")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Gönder") {
                        guard let reason = selectedReason else { return }
                        onSubmit(reason, description.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(selectedReason == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isOwn: Bool
    let onDelete: () -> Void
    let onReport: (() -> Void)?
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
                        } else if let onReport {
                            Button {
                                onReport()
                            } label: {
                                Label("Şikayet Et", systemImage: "flag")
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
