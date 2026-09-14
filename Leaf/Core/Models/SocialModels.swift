import Foundation

// MARK: - UserProfile

struct UserProfile: Identifiable, Hashable, Codable {
    var id: String
    var username: String
    var avatarUrl: String?
    var bio: String?
    var age: Int?
    // Eşleşme amaçlı alanlar — sadece 18 yaş üzeri kullanıcılarda dolu olur.
    var gender: String?
    var interestedIn: [String]?
    var city: String?
    var commonBookTitles: [String]?
    var sameCity: Bool?
    // Keşfet/Mesajlar sekmelerini gösterip göstermeme tercihi — hesaba bağlı,
    // cihazlar arası senkron olsun diye burada tutuyoruz (eskiden lokal UserDefaults'taydı).
    // discover_users RPC'si bu kolonu döndürmüyor, o yüzden optional.
    var socialEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "profile_id"
        case username
        case avatarUrl       = "avatar_url"
        case bio, age, gender, city
        case interestedIn     = "interested_in"
        case commonBookTitles = "common_book_titles"
        case sameCity          = "same_city"
        case socialEnabled    = "social_enabled"
    }
}

// MARK: - Gender

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male, female, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Erkek"
        case .female: return "Kadın"
        case .other: return "Diğer"
        }
    }
}

// MARK: - Photo Reveal

enum PhotoRevealStage: String, Codable {
    case hidden    // henüz eşleşme yok — kart aşaması
    case none      // fotoğraf hiç yüklenmemiş
    case blurred   // eşleşme var, ikisi de onaylamamış
    case revealed  // kendi fotoğrafın ya da her iki taraf da onayladı
}

struct PhotoReveal: Codable {
    var stage: PhotoRevealStage
    var url: URL?
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
    // "text" (normal mesaj) veya "book_share" (kitap kartı) — kolon DB'de
    // NOT NULL DEFAULT 'text' olduğu için eski satırlar da her zaman dolu gelir.
    var messageType: String = "text"
    // Sadece messageType == "book_share" iken dolu. content o durumda
    // kartın altına eklenen isteğe bağlı alt yazı olarak kullanılıyor.
    var sharedBook: SharedBookPayload?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId       = "sender_id"
        case content
        case isRead         = "is_read"
        case createdAt      = "created_at"
        case messageType    = "message_type"
        case sharedBook     = "shared_book"
    }

    // InboxView'daki sohbet listesi son mesaj önizlemesi için — book_share'de
    // content boşsa (kullanıcı alt yazı yazmadıysa) ham boş metin yerine
    // anlamlı bir özet gösteriyoruz.
    var previewText: String {
        guard messageType == "book_share" else { return content }
        let title = sharedBook?.title ?? "bir kitap"
        return content.isEmpty ? "📚 \(title) paylaştı" : content
    }
}

// Sohbette paylaşılan kitap kartının verisi — messages.shared_book jsonb
// kolonuna bu şekilde yazılıp aynı şekilde okunuyor.
struct SharedBookPayload: Codable, Hashable {
    var title: String
    var author: String
    var coverImageUrl: String?
    var currentPage: Int
    var totalPages: Int
    // İkisi de doluysa kartın altında bir not alıntısı gösteriliyor —
    // "sadece ilerleme" paylaşımında ikisi de nil kalıyor.
    var noteTitle: String?
    var noteContent: String?

    enum CodingKeys: String, CodingKey {
        case title, author
        case coverImageUrl = "cover_image_url"
        case currentPage   = "current_page"
        case totalPages    = "total_pages"
        case noteTitle     = "note_title"
        case noteContent   = "note_content"
    }

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(Double(currentPage) / Double(totalPages), 1)
    }
}
