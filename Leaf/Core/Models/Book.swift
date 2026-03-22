import Foundation
import SwiftData

// kitap modeli — SwiftData ile kalıcı depolama
// kapak görseli, okuma ilerlemesi ve notlar taşıyor

@Model
final class Book {
    var title: String
    var author: String
    var coverImageData: Data?
    var totalPages: Int
    var currentPage: Int
    var createdAt: Date
    var updatedAt: Date

    // kitaba bağlı notlar
    @Relationship(deleteRule: .cascade, inverse: \BookNote.book)
    var notes: [BookNote] = []

    // okuma yüzdesi
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }

    var hasStarted: Bool { currentPage > 0 }
    var isCompleted: Bool { totalPages > 0 && currentPage >= totalPages }

    init(title: String, author: String, coverImageData: Data? = nil, totalPages: Int = 0, currentPage: Int = 0) {
        self.title = title
        self.author = author
        self.coverImageData = coverImageData
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.createdAt = .now
        self.updatedAt = .now
    }
}
