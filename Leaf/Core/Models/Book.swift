import Foundation

// kitap modeli — SwiftData yok, tek kaynak Supabase

struct Book: Identifiable, Hashable {
    var id: String
    var userId: String?
    var title: String
    var author: String
    var coverImageUrl: String?   // Storage path'i: {userId}/{bookId} formatında
    var totalPages: Int
    var currentPage: Int
    var isWishlist: Bool
    var createdAt: Date
    var updatedAt: Date
    var notes: [BookNote]

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
    var hasStarted: Bool { currentPage > 0 }
    var isCompleted: Bool { totalPages > 0 && currentPage >= totalPages }

    init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        title: String,
        author: String,
        coverImageUrl: String? = nil,
        totalPages: Int = 0,
        currentPage: Int = 0,
        isWishlist: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        notes: [BookNote] = []
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.author = author
        self.coverImageUrl = coverImageUrl
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.isWishlist = isWishlist
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.notes = notes
    }
}
