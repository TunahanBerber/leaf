import Foundation

// MARK: - UserProfile

struct UserProfile: Identifiable, Hashable, Codable {
    var id: String
    var username: String
    var avatarUrl: String?
    var bio: String?
    var age: Int?
    var commonBookTitles: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "profile_id"
        case username
        case avatarUrl       = "avatar_url"
        case bio, age
        case commonBookTitles = "common_book_titles"
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
