import Foundation

// Not modeli — SwiftData yok, tek kaynak Supabase

struct BookNote: Identifiable, Hashable {
    var id: String
    var userId: String?
    var bookId: String
    var title: String
    var content: String
    var pageNumber: Int?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        bookId: String,
        title: String,
        content: String,
        pageNumber: Int? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.bookId = bookId
        self.title = title
        self.content = content
        self.pageNumber = pageNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
