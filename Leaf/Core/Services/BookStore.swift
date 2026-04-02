// BookStore.swift
// Leaf — Tek veri kaynağı: Supabase
//
// SwiftData tamamen kaldırıldı.
// Tüm CRUD işlemleri doğrudan Supabase'e gider,
// UI state bu store'daki @Published books dizisinden beslenir.

import Foundation
import UIKit
import Supabase

// MARK: - Supabase Codable Records (DB ↔ App köprüsü)

private struct BookRecord: Codable {
    var id: String?
    var userId: String?
    var title: String
    var author: String
    var coverImageUrl: String?
    var totalPages: Int
    var currentPage: Int
    var isWishlist: Bool
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId        = "user_id"
        case title, author
        case coverImageUrl = "cover_image_url"
        case totalPages    = "total_pages"
        case currentPage   = "current_page"
        case isWishlist    = "is_wishlist"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }

    func toBook(notes: [BookNote] = []) -> Book {
        Book(
            id: id ?? UUID().uuidString,
            userId: userId,
            title: title,
            author: author,
            coverImageUrl: coverImageUrl,
            totalPages: totalPages,
            currentPage: currentPage,
            isWishlist: isWishlist,
            createdAt: createdAt ?? .now,
            updatedAt: updatedAt ?? .now,
            notes: notes
        )
    }
}

private struct BookNoteRecord: Codable {
    var id: String?
    var userId: String?
    var bookId: String
    var title: String
    var content: String
    var pageNumber: Int?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case bookId     = "book_id"
        case title, content
        case pageNumber = "page_number"
        case createdAt  = "created_at"
        case updatedAt  = "updated_at"
    }

    func toBookNote() -> BookNote {
        BookNote(
            id: id ?? UUID().uuidString,
            userId: userId,
            bookId: bookId,
            title: title,
            content: content,
            pageNumber: pageNumber,
            createdAt: createdAt ?? .now,
            updatedAt: updatedAt ?? .now
        )
    }
}

// MARK: - Book Store

@MainActor
final class BookStore: ObservableObject {

    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var error: String?

    private let bucketName = "book-covers"

    var library:  [Book] { books.filter { !$0.isWishlist } }
    var wishlist: [Book] { books.filter {  $0.isWishlist } }

    // MARK: - Fetch All

    func fetchAll() async {
        guard (try? await supabase.auth.session) != nil else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let records: [BookRecord] = try await supabase
                .from("books")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            books = records.map { $0.toBook() }
        } catch {
            self.error = "Kitaplar yüklenemedi: \(error.localizedDescription)"
        }
    }

    // MARK: - Fetch Notes

    func fetchNotes(for bookId: String) async {
        do {
            let records: [BookNoteRecord] = try await supabase
                .from("book_notes")
                .select()
                .eq("book_id", value: bookId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let notes = records.map { $0.toBookNote() }
            if let idx = books.firstIndex(where: { $0.id == bookId }) {
                books[idx].notes = notes
            }
        } catch {
            self.error = "Notlar yüklenemedi: \(error.localizedDescription)"
        }
    }

    // MARK: - Add Book

    func addBook(
        title: String,
        author: String,
        coverImageData: Data?,
        totalPages: Int,
        isWishlist: Bool,
        language: String? = nil,
        publisher: String? = nil,
        publishedYear: String? = nil
    ) async {
        // lowercased — PostgreSQL auth.uid()::text küçük harf döndürür, eşleşme şart
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        let bookId = UUID().uuidString
        var coverUrl: String? = nil

        if let data = coverImageData {
            coverUrl = await uploadCover(data: data, path: "\(userId)/\(bookId)")
        }

        let record = BookRecord(
            id: bookId,
            userId: userId,
            title: title,
            author: author,
            coverImageUrl: coverUrl,
            totalPages: totalPages,
            currentPage: 0,
            isWishlist: isWishlist,
            createdAt: .now,
            updatedAt: .now
        )

        do {
            let saved: BookRecord = try await supabase
                .from("books")
                .insert(record)
                .select()
                .single()
                .execute()
                .value

            books.insert(saved.toBook(), at: 0)

            // Kataloğa da ekle — aynı kitap varsa atla (ON CONFLICT DO NOTHING)
            await addToCatalog(
                title: title,
                author: author,
                pageCount: totalPages > 0 ? totalPages : nil,
                language: language,
                coverUrl: coverUrl,
                publisher: publisher,
                publishedYear: publishedYear
            )
        } catch {
            self.error = "Kitap eklenemedi: \(error.localizedDescription)"
        }
    }

    // MARK: - Catalog Upsert (dahili, kullanıcıya görünmez)

    private func addToCatalog(
        title: String,
        author: String,
        pageCount: Int?,
        language: String?,
        coverUrl: String?,
        publisher: String?,
        publishedYear: String?
    ) async {
        // Supabase Storage path değil, public URL oluştur
        var publicCoverUrl: String? = nil
        if let path = coverUrl {
            publicCoverUrl = "https://qowvamowkmysdjrnhkkb.supabase.co/storage/v1/object/public/book-covers/\(path)"
        }

        let entry: [String: AnyJSON] = [
            "title":          .string(title),
            "author":         .string(author),
            "page_count":     pageCount.map { .double(Double($0)) } ?? .null,
            "language":       language.map { .string($0) } ?? .null,
            "cover_url":      publicCoverUrl.map { .string($0) } ?? .null,
            "publisher":      publisher.map { .string($0) } ?? .null,
            "published_year": publishedYear.map { .string($0) } ?? .null
        ]

        // Aynı title+author kombinasyonu varsa atla
        try? await supabase
            .from("book_catalog")
            .insert(entry, returning: .minimal)
            .execute()
    }

    // MARK: - Update Book

    func updateBook(_ book: Book, newCoverData: Data? = nil) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        var coverUrl = book.coverImageUrl

        if let data = newCoverData {
            coverUrl = await uploadCover(data: data, path: "\(userId)/\(book.id)")
        }

        let record = BookRecord(
            id: book.id,
            userId: userId,
            title: book.title,
            author: book.author,
            coverImageUrl: coverUrl,
            totalPages: book.totalPages,
            currentPage: book.currentPage,
            isWishlist: book.isWishlist,
            createdAt: book.createdAt,
            updatedAt: .now
        )

        do {
            try await supabase
                .from("books")
                .update(record)
                .eq("id", value: book.id)
                .execute()

            if let idx = books.firstIndex(where: { $0.id == book.id }) {
                var updated = book
                updated.coverImageUrl = coverUrl
                updated.updatedAt = .now
                // Notları koru
                updated.notes = books[idx].notes
                books[idx] = updated
            }
        } catch {
            self.error = "Kitap güncellenemedi: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete Book

    func deleteBook(_ book: Book) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        do {
            try await supabase
                .from("books")
                .delete()
                .eq("id", value: book.id)
                .execute()

            // Önce Supabase başarılıysa yerelden de kaldır
            books.removeAll { $0.id == book.id }

            // Storage'dan kapak sil (hata olsa da devam)
            try? await supabase.storage
                .from(bucketName)
                .remove(paths: ["\(userId)/\(book.id)"])
        } catch {
            self.error = "Kitap silinemedi: \(error.localizedDescription)"
        }
    }

    // MARK: - Add Note

    func addNote(title: String, content: String, pageNumber: Int?, to bookId: String) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        let record = BookNoteRecord(
            id: UUID().uuidString,
            userId: userId,
            bookId: bookId,
            title: title,
            content: content,
            pageNumber: pageNumber,
            createdAt: .now,
            updatedAt: .now
        )

        do {
            let saved: BookNoteRecord = try await supabase
                .from("book_notes")
                .insert(record)
                .select()
                .single()
                .execute()
                .value

            if let idx = books.firstIndex(where: { $0.id == bookId }) {
                books[idx].notes.insert(saved.toBookNote(), at: 0)
            }
        } catch {
            self.error = "Not eklenemedi: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete Note

    func deleteNote(_ note: BookNote) async {
        do {
            try await supabase
                .from("book_notes")
                .delete()
                .eq("id", value: note.id)
                .execute()

            if let bookIdx = books.firstIndex(where: { $0.id == note.bookId }) {
                books[bookIdx].notes.removeAll { $0.id == note.id }
            }
        } catch {
            self.error = "Not silinemedi: \(error.localizedDescription)"
        }
    }

    // MARK: - Cover Image

    func loadCoverIfNeeded(for bookId: String) async {
        guard let idx = books.firstIndex(where: { $0.id == bookId }),
              books[idx].coverImageData == nil,
              let path = books[idx].coverImageUrl else { return }

        if let data = await downloadCover(path: path) {
            books[idx].coverImageData = data
        }
    }

    func uploadCover(data: Data, path: String) async -> String? {
        do {
            let compressed = UIImage(data: data)?.jpegData(compressionQuality: 0.75) ?? data
            _ = try await supabase.storage
                .from(bucketName)
                .upload(
                    path,
                    data: compressed,
                    options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
                )
            print("✅ Kapak yüklendi: \(path)")
            return path
        } catch {
            print("❌ Kapak yüklenemedi [\(path)]: \(error)")
            return nil
        }
    }

    func downloadCover(path: String) async -> Data? {
        // Bucket public — direkt URL ile indir, auth gerekmez, çok daha hızlı
        let publicURL = "https://qowvamowkmysdjrnhkkb.supabase.co/storage/v1/object/public/\(bucketName)/\(path)"
        guard let url = URL(string: publicURL) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            print("✅ Kapak indirildi: \(path), boyut: \(data.count) byte")
            return data
        } catch {
            print("❌ Kapak indirilemedi [\(path)]: \(error)")
            return nil
        }
    }
}
