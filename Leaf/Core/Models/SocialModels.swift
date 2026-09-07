import Foundation

// MARK: - UserProfile

struct UserProfile: Identifiable, Hashable, Codable {
    var id: String
    var username: String
    var avatarUrl: String?
    var bio: String?
    var age: Int?
    var commonBookTitles: [String]?
    // Keşfet/Mesajlar sekmelerini gösterip göstermeme tercihi — hesaba bağlı,
    // cihazlar arası senkron olsun diye burada tutuyoruz (eskiden lokal UserDefaults'taydı).
    // discover_users RPC'si bu kolonu döndürmüyor, o yüzden optional.
    var socialEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "profile_id"
        case username
        case avatarUrl       = "avatar_url"
        case bio, age
        case commonBookTitles = "common_book_titles"
        case socialEnabled    = "social_enabled"
    }
}

// MARK: - Conversation

struct Conversation: Identifiable, Hashable, Codable {
    var id: String
    var userAId: String
    var userBId: String
    var createdAt: Date
    var otherUser: UserProfile?
    var lastMessage: Message?

    enum CodingKeys: String, CodingKey {
        case id
        case userAId   = "user_a_id"
        case userBId   = "user_b_id"
        case createdAt = "created_at"
    }
}

// MARK: - Conversation Request

struct ConversationRequest: Identifiable, Hashable, Codable {
    var id: String
    var senderId: String
    var receiverId: String
    var status: String   // "pending" | "accepted" | "rejected"
    var createdAt: Date
    var senderProfile: UserProfile?
    var receiverProfile: UserProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case senderId   = "sender_id"
        case receiverId = "receiver_id"
        case status
        case createdAt  = "created_at"
    }
}

// MARK: - Message

struct Message: Identifiable, Hashable, Codable {
    var id: String
    var conversationId: String
    var senderId: String
    var content: String
    var isRead: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId       = "sender_id"
        case content
        case isRead         = "is_read"
        case createdAt      = "created_at"
    }
}
