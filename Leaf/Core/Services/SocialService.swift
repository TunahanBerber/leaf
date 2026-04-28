// SocialService.swift
// Tüm sosyal işlemler buradan geçiyor — keşif, sohbet, mesajlaşma ve Realtime

import Foundation
import Supabase

// Supabase'den gelen profil kaydı (id string olarak geliyor)
private struct ProfileRecord: Codable {
    var id: String
    var username: String
    var avatarUrl: String?
    var bio: String?
    var age: Int?

    enum CodingKeys: String, CodingKey {
        case id, username, bio, age
        case avatarUrl = "avatar_url"
    }

    func toUserProfile() -> UserProfile {
        UserProfile(
            id: id,
            username: username,
            avatarUrl: avatarUrl,
            bio: bio,
            age: age,
            commonBookTitles: nil
        )
    }
}

@MainActor
final class SocialService: ObservableObject {

    // MARK: - State

    @Published var currentProfile: UserProfile?
    @Published var discoveredUsers: [UserProfile] = []
    @Published var conversations: [Conversation] = []
    @Published var pendingRequests: [ConversationRequest] = []  // gelen bekleyen istekler
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var error: String?

    // profil henüz yüklenmedi mi (nil) vs yüklendi ama yok (currentProfile == nil)
    @Published var profileLoaded = false
    @Published var unreadCount: Int = 0

    private var currentUserId: String = ""

    // 18 yaş altı sosyal özelliklere erişemez
    var isSocialAllowed: Bool {
        guard let age = currentProfile?.age else { return false }
        return age >= 18
    }

    private var realtimeChannel: RealtimeChannelV2?
    private var inboxChannel: RealtimeChannelV2?

    private struct MinimalMessage: Decodable { let id: String }

    // MARK: - Profil Yükleme

    func loadCurrentProfile() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else {
            profileLoaded = true
            return
        }

        do {
            let records: [ProfileRecord] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value

            currentProfile = records.first?.toUserProfile()
        } catch {
            currentProfile = nil
        }

        profileLoaded = true
    }

    // MARK: - Profil Oluşturma

    func createProfile(username: String, bio: String, age: Int) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return false }
        isLoading = true
        defer { isLoading = false }

        var entry: [String: AnyJSON] = [
            "id":       .string(userId),
            "username": .string(username),
            "age":      .double(Double(age))
        ]
        if !bio.isEmpty { entry["bio"] = .string(bio) }

        do {
            let saved: ProfileRecord = try await supabase
                .from("profiles")
                .insert(entry)
                .select()
                .single()
                .execute()
                .value

            currentProfile = saved.toUserProfile()
            return true
        } catch {
            self.error = "Profil oluşturulamadı. Kullanıcı adı zaten alınmış olabilir."
            return false
        }
    }

    // MARK: - Profil Güncelleme

    func updateProfile(username: String, bio: String) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return false }
        isLoading = true
        defer { isLoading = false }

        var entry: [String: AnyJSON] = ["username": .string(username)]
        if !bio.isEmpty { entry["bio"] = .string(bio) }

        do {
            let updated: ProfileRecord = try await supabase
                .from("profiles")
                .update(entry)
                .eq("id", value: userId)
                .select()
                .single()
                .execute()
                .value

            currentProfile = updated.toUserProfile()
            return true
        } catch {
            self.error = "Profil güncellenemedi."
            return false
        }
    }

    // MARK: - Keşif

    func discoverUsers() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let users: [UserProfile] = try await supabase
                .rpc("discover_users")
                .execute()
                .value

            discoveredUsers = users
        } catch {
            self.error = "Kullanıcılar yüklenemedi."
            print("[SocialService] discoverUsers error: \(error)")
        }
    }

    // MARK: - Conversation Request

    // karşı tarafa sohbet isteği gönder
    func sendConversationRequest(to receiverId: String) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return false }

        // Zaten aktif bir istek veya sohbet varsa tekrar gönderme
        let existing: [ConversationRequest]? = try? await supabase
            .from("conversation_requests")
            .select()
            .eq("sender_id", value: userId)
            .eq("receiver_id", value: receiverId)
            .limit(1)
            .execute()
            .value

        if existing?.isEmpty == false { return false }

        let entry: [String: AnyJSON] = [
            "sender_id":   .string(userId),
            "receiver_id": .string(receiverId),
            "status":      .string("pending")
        ]

        do {
            try await supabase
                .from("conversation_requests")
                .insert(entry)
                .execute()
            return true
        } catch {
            self.error = "İstek gönderilemedi."
            return false
        }
    }

    // gelen istekleri yükle (gönderen profilleriyle birlikte)
    func fetchPendingRequests() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        do {
            var requests: [ConversationRequest] = try await supabase
                .from("conversation_requests")
                .select()
                .eq("receiver_id", value: userId)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
                .value

            // Gönderen profilerini tek sorguda çek
            let senderIds = requests.map(\.senderId)
            if !senderIds.isEmpty {
                let profiles: [ProfileRecord] = (try? await supabase
                    .from("profiles")
                    .select()
                    .in("id", values: senderIds)
                    .execute()
                    .value) ?? []

                let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.toUserProfile()) })
                for i in requests.indices {
                    requests[i].senderProfile = profileMap[requests[i].senderId]
                }
            }

            pendingRequests = requests
        } catch {
            self.error = "İstekler yüklenemedi."
        }
    }

    // isteği kabul et → sohbet oluştur → isteği sil
    func acceptRequest(_ request: ConversationRequest) async -> String? {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return nil }

        // conversation oluştur
        let entry: [String: AnyJSON] = [
            "user_a_id": .string(request.senderId),
            "user_b_id": .string(userId)
        ]

        do {
            let conv: Conversation = try await supabase
                .from("conversations")
                .insert(entry)
                .select()
                .single()
                .execute()
                .value

            // isteği sil
            try? await supabase
                .from("conversation_requests")
                .delete()
                .eq("id", value: request.id)
                .execute()

            pendingRequests.removeAll { $0.id == request.id }
            return conv.id
        } catch {
            self.error = "İstek kabul edilemedi."
            return nil
        }
    }

    // isteği reddet → sil
    func rejectRequest(_ request: ConversationRequest) async {
        do {
            try await supabase
                .from("conversation_requests")
                .delete()
                .eq("id", value: request.id)
                .execute()

            pendingRequests.removeAll { $0.id == request.id }
        } catch {
            self.error = "İstek reddedilemedi."
        }
    }

    // bu kullanıcıya zaten istek gönderilmiş mi?
    func checkRequestStatus(to receiverId: String) async -> String? {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return nil }

        let result: [ConversationRequest]? = try? await supabase
            .from("conversation_requests")
            .select()
            .eq("sender_id", value: userId)
            .eq("receiver_id", value: receiverId)
            .limit(1)
            .execute()
            .value

        return result?.first?.status
    }

    // MARK: - Conversation

    func fetchConversations() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }
        currentUserId = userId
        isLoading = true
        defer { isLoading = false }

        do {
            var convs: [Conversation] = try await supabase
                .from("conversations")
                .select()
                .or("user_a_id.eq.\(userId),user_b_id.eq.\(userId)")
                .order("created_at", ascending: false)
                .execute()
                .value

            let otherIds = convs.map { conv -> String in
                conv.userAId == userId ? conv.userBId : conv.userAId
            }

            if !otherIds.isEmpty {
                let profiles: [ProfileRecord] = (try? await supabase
                    .from("profiles")
                    .select()
                    .in("id", values: otherIds)
                    .execute()
                    .value) ?? []

                let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.toUserProfile()) })

                for i in convs.indices {
                    let otherId = convs[i].userAId == userId ? convs[i].userBId : convs[i].userAId
                    convs[i].otherUser = profileMap[otherId]
                }
            }

            // her sohbetin son mesajını çek
            if !convs.isEmpty {
                let convIds = convs.map { $0.id }
                let allMessages: [Message] = (try? await supabase
                    .from("messages")
                    .select()
                    .in("conversation_id", values: convIds)
                    .order("created_at", ascending: false)
                    .execute()
                    .value) ?? []

                var latestByConv: [String: Message] = [:]
                for msg in allMessages {
                    if latestByConv[msg.conversationId] == nil {
                        latestByConv[msg.conversationId] = msg
                    }
                }
                for i in convs.indices {
                    convs[i].lastMessage = latestByConv[convs[i].id]
                }
            }

            conversations = convs

            // toplam okunmamış mesaj sayısını DB'den çek
            let convIds = convs.map { $0.id }
            if !convIds.isEmpty {
                let unread: [MinimalMessage] = (try? await supabase
                    .from("messages")
                    .select("id")
                    .in("conversation_id", values: convIds)
                    .neq("sender_id", value: userId)
                    .eq("is_read", value: false)
                    .execute()
                    .value) ?? []
                unreadCount = unread.count
            } else {
                unreadCount = 0
            }

            if inboxChannel == nil { await subscribeToInboxUpdates() }
        } catch {
            self.error = "Sohbetler yüklenemedi."
        }
    }

    // hızlı count query — scenePhase ve logout dışında çağrılır
    func refreshUnreadCount() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        var convIds = conversations.map { $0.id }
        if convIds.isEmpty {
            let convs: [Conversation] = (try? await supabase
                .from("conversations")
                .select()
                .or("user_a_id.eq.\(userId),user_b_id.eq.\(userId)")
                .execute()
                .value) ?? []
            convIds = convs.map { $0.id }
        }
        guard !convIds.isEmpty else { unreadCount = 0; return }

        let unread: [MinimalMessage] = (try? await supabase
            .from("messages")
            .select("id")
            .in("conversation_id", values: convIds)
            .neq("sender_id", value: userId)
            .eq("is_read", value: false)
            .execute()
            .value) ?? []
        unreadCount = unread.count
    }

    // gelen mesajları global olarak dinle — unreadCount'u real-time günceller
    private func subscribeToInboxUpdates() async {
        let channel = supabase.channel("inbox-\(currentUserId)")
        let insertions = channel.postgresChange(InsertAction.self, schema: "public", table: "messages")
        await channel.subscribe()
        inboxChannel = channel

        Task { [weak self] in
            for await insertion in insertions {
                guard let self else { break }
                let record = insertion.record
                guard
                    let senderId = record["sender_id"]?.stringValue,
                    senderId != self.currentUserId,
                    let convId = record["conversation_id"]?.stringValue,
                    self.conversations.contains(where: { $0.id == convId })
                else { continue }

                guard
                    let id      = record["id"]?.stringValue,
                    let content = record["content"]?.stringValue
                else { continue }

                let createdAtStr = record["created_at"]?.stringValue ?? ""
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let createdAt = formatter.date(from: createdAtStr) ?? Date()

                await MainActor.run {
                    self.unreadCount += 1
                    if let idx = self.conversations.firstIndex(where: { $0.id == convId }) {
                        self.conversations[idx].lastMessage = Message(
                            id: id, conversationId: convId, senderId: senderId,
                            content: content, isRead: false, createdAt: createdAt
                        )
                    }
                }
            }
        }
    }

    func unsubscribeInbox() async {
        await inboxChannel?.unsubscribe()
        inboxChannel = nil
    }

    // sadece mevcut sohbeti döner, yoksa nil — yeni sohbet OLUŞTURMAZ
    func fetchExistingConversationId(with otherUserId: String) async -> String? {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return nil }

        let existing: [Conversation]? = try? await supabase
            .from("conversations")
            .select()
            .or("and(user_a_id.eq.\(userId),user_b_id.eq.\(otherUserId)),and(user_a_id.eq.\(otherUserId),user_b_id.eq.\(userId))")
            .limit(1)
            .execute()
            .value

        return existing?.first?.id
    }

    // iki kullanıcı arasında sohbet başlatır, varsa mevcut olanı döner
    func startConversation(with otherUserId: String) async -> String? {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return nil }

        let existing: [Conversation]? = try? await supabase
            .from("conversations")
            .select()
            .or("and(user_a_id.eq.\(userId),user_b_id.eq.\(otherUserId)),and(user_a_id.eq.\(otherUserId),user_b_id.eq.\(userId))")
            .limit(1)
            .execute()
            .value

        if let conv = existing?.first { return conv.id }

        let entry: [String: AnyJSON] = [
            "user_a_id": .string(userId),
            "user_b_id": .string(otherUserId)
        ]

        let created: Conversation? = try? await supabase
            .from("conversations")
            .insert(entry)
            .select()
            .single()
            .execute()
            .value

        return created?.id
    }

    // MARK: - Mesajlar

    func fetchMessages(conversationId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let msgs: [Message] = try await supabase
                .from("messages")
                .select()
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: true)
                .execute()
                .value

            messages = msgs
            await markAsRead(conversationId: conversationId)
        } catch {
            self.error = "Mesajlar yüklenemedi."
        }
    }

    func sendMessage(conversationId: String, content: String) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        let entry: [String: AnyJSON] = [
            "conversation_id": .string(conversationId),
            "sender_id":       .string(userId),
            "content":         .string(content)
        ]

        do {
            let sent: Message = try await supabase
                .from("messages")
                .insert(entry)
                .select()
                .single()
                .execute()
                .value

            messages.append(sent)
        } catch {
            self.error = "Mesaj gönderilemedi."
        }
    }

    func deleteConversation(_ conversation: Conversation) async {
        do {
            try await supabase
                .from("conversations")
                .delete()
                .eq("id", value: conversation.id)
                .execute()

            conversations.removeAll { $0.id == conversation.id }
        } catch {
            self.error = "Sohbet silinemedi."
        }
    }

    func deleteMessage(_ message: Message) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased(),
              message.senderId == userId else { return }

        do {
            try await supabase
                .from("messages")
                .delete()
                .eq("id", value: message.id)
                .execute()

            messages.removeAll { $0.id == message.id }
        } catch {
            self.error = "Mesaj silinemedi."
        }
    }

    private func markAsRead(conversationId: String) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        try? await supabase
            .from("messages")
            .update(["is_read": AnyJSON.bool(true)])
            .eq("conversation_id", value: conversationId)
            .neq("sender_id", value: userId)
            .eq("is_read", value: false)
            .execute()

        if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[idx].lastMessage?.isRead = true
        }
        await refreshUnreadCount()
    }

    // MARK: - Realtime

    func subscribeToMessages(conversationId: String) async {
        await unsubscribe()

        let channel = supabase.channel("messages:\(conversationId)")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(conversationId)"
        )

        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(conversationId)"
        )

        await channel.subscribe()
        realtimeChannel = channel

        Task { [weak self] in
            for await insertion in insertions {
                guard let self else { break }
                let record = insertion.record

                guard
                    let id           = record["id"]?.stringValue,
                    let convId       = record["conversation_id"]?.stringValue,
                    let senderId     = record["sender_id"]?.stringValue,
                    let content      = record["content"]?.stringValue,
                    let createdAtStr = record["created_at"]?.stringValue
                else { continue }

                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let createdAt = formatter.date(from: createdAtStr) ?? Date()

                let msg = Message(
                    id: id,
                    conversationId: convId,
                    senderId: senderId,
                    content: content,
                    isRead: false,
                    createdAt: createdAt
                )

                await MainActor.run {
                    guard !(self.messages.contains { $0.id == msg.id }) else { return }
                    self.messages.append(msg)
                }
            }
        }

        Task { [weak self] in
            for await deletion in deletions {
                guard let self else { break }
                guard let id = deletion.oldRecord["id"]?.stringValue else { continue }
                await MainActor.run {
                    self.messages.removeAll { $0.id == id }
                }
            }
        }
    }

    func unsubscribe() async {
        if let channel = realtimeChannel {
            await supabase.removeChannel(channel)
            realtimeChannel = nil
        }
    }
}
