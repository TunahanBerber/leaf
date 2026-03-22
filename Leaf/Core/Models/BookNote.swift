import Foundation
import SwiftData

// kitaba bağlı not modeli
// başlık + içerik + opsiyonel sayfa numarası

@Model
final class BookNote {
    var title: String
    var content: String
    var pageNumber: Int?
    var createdAt: Date
    var updatedAt: Date
    var book: Book?

    init(title: String, content: String, pageNumber: Int? = nil, book: Book? = nil) {
        self.title = title
        self.content = content
        self.pageNumber = pageNumber
        self.book = book
        self.createdAt = .now
        self.updatedAt = .now
    }
}
