// BookSearchService.swift (OpenLibraryService.swift)
// Leaf — Google Books + OpenLibrary paralel arama
//
// İkisi aynı anda başlar, Google hızlı gelince hemen gösterilir,
// OpenLibrary gelince (Türkçe kitaplarda daha kapsamlı) sonuçlar merge edilir.

import Foundation
import Supabase

// MARK: - Unified Model

struct BookSearchResult: Identifiable, Equatable {
    let id: String
    let title: String
    let authors: [String]
    let pageCount: Int?
    let coverURL: URL?          // liste için küçük kapak
    let highResCoverURL: URL?   // detay için büyük kapak
    let publisher: String?
    let publishedDate: String?
    let language: String?

    var authorsText: String { authors.joined(separator: ", ") }
}

// geriye dönük uyumluluk — AddBookView hâlâ bu tipname'i kullanıyor
typealias OpenLibraryResult = BookSearchResult

// MARK: - Google Books Decodable

private struct GBResponse: Decodable { let items: [GBItem]? }
private struct GBItem: Decodable {
    let id: String
    let volumeInfo: GBInfo?
    struct GBInfo: Decodable {
        let title: String?
        let authors: [String]?
        let pageCount: Int?
        let publisher: String?
        let publishedDate: String?
        let language: String?
        let imageLinks: GBImages?
        struct GBImages: Decodable {
            let thumbnail: String?
            let smallThumbnail: String?
        }
    }
}

// MARK: - OpenLibrary Decodable

private struct OLResponse: Decodable { let docs: [OLDoc]? }
private struct OLDoc: Decodable {
    let key: String?
    let title: String?
    let author_name: [String]?
    let number_of_pages_median: Int?
    let cover_i: Int?
    let publisher: [String]?
    let first_publish_year: Int?
    let language: [String]?
}

// MARK: - Shared URL Sessions (static → nonisolated'dan erişilebilir)

private enum Sessions {
    // Google: hızlı, kısa timeout
    static let google: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 8
        return URLSession(configuration: c)
    }()

    // OpenLibrary: daha toleranslı + agresif cache (aynı sorgu anında döner)
    static let openLibrary: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 15
        c.timeoutIntervalForResource = 20
        c.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity:  200 * 1024 * 1024
        )
        c.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: c)
    }()
}

// MARK: - Catalog Decodable

private struct CatalogRecord: Decodable {
    let id: String
    let title: String
    let author: String
    let page_count: Int?
    let language: String?
    let cover_url: String?
    let publisher: String?
    let published_year: String?
}

// MARK: - Combined Search Service

@MainActor
final class OpenLibraryService: ObservableObject {

    @Published var results: [BookSearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var searchTask: Task<Void, Never>?

    // 350ms debounce — çok kısa yazımlarda istek atmıyoruz
    func search(query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    func searchNow(query: String) async {
        await performSearch(query: query)
    }

    func clear() {
        searchTask?.cancel()
        results = []
        errorMessage = nil
        isLoading = false
    }

    // MARK: - 3 Aşamalı Arama

    private func performSearch(query: String) async {
        isLoading = true
        errorMessage = nil
        results = []

        // 1. Katalog — Supabase sorgusu, ~50ms, anında göster
        let catalogResults = await fetchCatalog(query: query)
        guard !Task.isCancelled else { isLoading = false; return }
        if !catalogResults.isEmpty { results = catalogResults }

        // 2 & 3. Google + OpenLibrary eş zamanlı başlat
        async let googleTask = Task { try await Self.fetchGoogle(query: query) }
        async let olTask     = Task { try await Self.fetchOpenLibrary(query: query) }

        do {
            // Google gelince merge et (katalog üste kalır)
            let google = try await googleTask.value
            guard !Task.isCancelled else { isLoading = false; return }
            results = Self.mergeAll(catalog: catalogResults, google: google, openLibrary: [])

            // OL gelince son merge
            let ol = try await olTask.value
            guard !Task.isCancelled else { isLoading = false; return }
            results = Self.mergeAll(catalog: catalogResults, google: google, openLibrary: ol)
        } catch {
            if results.isEmpty {
                // Sadece katalog da boşsa hatayı göster, yoksa olanları göster
                errorMessage = (error as? NetworkError)?.errorDescription ?? "Kitaplar aranırken bağlantı hatası oluştu. Lütfen tekrar deneyin."
            }
        }
        isLoading = false
    }

    // MARK: - Katalog Arama (Supabase, hızlı)

    private func fetchCatalog(query: String) async -> [BookSearchResult] {
        guard !query.isEmpty else { return [] }
        // title VEYA author içinde geçenleri getir
        let filter = "title.ilike.%\(query)%,author.ilike.%\(query)%"
        do {
            let records: [CatalogRecord] = try await supabase
                .from("book_catalog")
                .select()
                .or(filter)
                .order("added_count", ascending: false)
                .limit(10)
                .execute()
                .value
            return records.map { mapCatalog($0) }
        } catch {
            return []
        }
    }

    private func mapCatalog(_ r: CatalogRecord) -> BookSearchResult {
        let coverURL = r.cover_url.flatMap { URL(string: $0) }
        return BookSearchResult(
            id:             "cat_\(r.id)",
            title:          r.title,
            authors:        r.author.isEmpty ? [] : [r.author],
            pageCount:      r.page_count,
            coverURL:       coverURL,
            highResCoverURL: coverURL,
            publisher:      r.publisher,
            publishedDate:  r.published_year,
            language:       r.language
        )
    }

    // MARK: - Google Books (nonisolated → main actor'dan bağımsız çalışır)

    private static nonisolated func fetchGoogle(query: String) async throws -> [BookSearchResult] {
        var comps = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        let q = "inauthor:\"\(query)\" OR intitle:\"\(query)\""
        comps.queryItems = [
            .init(name: "q",          value: q),
            .init(name: "maxResults", value: "15"),
            .init(name: "printType",  value: "books")
        ]
        guard let url = comps.url else { return [] }

        return try await NetworkHelper.retry {
            let (data, resp) = try await Sessions.google.data(from: url)
            guard let httpResp = resp as? HTTPURLResponse else { throw NetworkError.invalidURL }
            guard httpResp.statusCode == 200 else { throw NetworkError.badResponse(statusCode: httpResp.statusCode) }
            
            let decoded = try JSONDecoder().decode(GBResponse.self, from: data)
            return (decoded.items ?? []).compactMap { mapGoogle($0) }
        }
    }

    private static nonisolated func mapGoogle(_ item: GBItem) -> BookSearchResult? {
        guard let info = item.volumeInfo, let title = info.title else { return nil }

        // Google bazen http:// döndürür — https'ye çeviriyoruz
        func toHTTPS(_ s: String?) -> URL? {
            guard let s else { return nil }
            return URL(string: s.replacingOccurrences(of: "http://", with: "https://"))
        }

        let small   = toHTTPS(info.imageLinks?.smallThumbnail)
        let thumb   = toHTTPS(info.imageLinks?.thumbnail)
        // zoom=1 → zoom=3 ile daha yüksek çözünürlük
        let highRes = toHTTPS(
            info.imageLinks?.thumbnail?
                .replacingOccurrences(of: "http://", with: "https://")
                .replacingOccurrences(of: "zoom=1", with: "zoom=3")
        )

        return BookSearchResult(
            id:             "gb_\(item.id)",
            title:          title,
            authors:        info.authors ?? [],
            pageCount:      info.pageCount,
            coverURL:       small ?? thumb,
            highResCoverURL: highRes ?? thumb,
            publisher:      info.publisher,
            publishedDate:  info.publishedDate,
            language:       info.language
        )
    }

    // MARK: - OpenLibrary (nonisolated → paralel)

    private static nonisolated func fetchOpenLibrary(query: String) async throws -> [BookSearchResult] {
        // q= her alanı tarıyor — yazar ve başlık ayrı ayrı, paralel aranıyor
        async let byAuthor = Task { try await fetchOL(field: "author", query: query) }
        async let byTitle  = Task { try await fetchOL(field: "title",  query: query) }

        // Hata olsa bile diğerini bekleyip (try?) boş liste ile devam edelim ki
        // biri fail ederse hepsi patlamasın. Fakat ikisi de fail ederse boş döner.
        let authorResults = (try? await byAuthor.value) ?? []
        let titleResults  = (try? await byTitle.value) ?? []

        // Yazar eşleşmeleri daha alakalı — önce o, sonra başlık
        var seen: Set<String> = []
        var merged: [BookSearchResult] = []
        for r in authorResults { if seen.insert(r.id).inserted { merged.append(r) } }
        for r in titleResults  { if seen.insert(r.id).inserted { merged.append(r) } }
        return merged
    }

    // Tek bir OL field sorgusu
    private static nonisolated func fetchOL(field: String, query: String) async throws -> [BookSearchResult] {
        var comps = URLComponents(string: "https://openlibrary.org/search.json")!
        comps.queryItems = [
            .init(name: field,         value: query),
            .init(name: "limit",       value: "10"),
            .init(name: "timeAllowed", value: "5000"),
            .init(name: "fields",      value: "key,title,author_name,number_of_pages_median,cover_i,publisher,first_publish_year,language")
        ]
        guard let url = comps.url else { return [] }

        return try await NetworkHelper.retry {
            let (data, resp) = try await Sessions.openLibrary.data(from: url)
            guard let httpResp = resp as? HTTPURLResponse else { throw NetworkError.invalidURL }
            guard httpResp.statusCode == 200 else { throw NetworkError.badResponse(statusCode: httpResp.statusCode) }
            
            let decoded = try JSONDecoder().decode(OLResponse.self, from: data)
            return (decoded.docs ?? []).compactMap { mapOL($0) }
        }
    }

    private static nonisolated func mapOL(_ doc: OLDoc) -> BookSearchResult? {
        guard let key = doc.key, let title = doc.title else { return nil }

        var small: URL? = nil
        var large: URL? = nil
        if let cid = doc.cover_i {
            small = URL(string: "https://covers.openlibrary.org/b/id/\(cid)-M.jpg")
            large = URL(string: "https://covers.openlibrary.org/b/id/\(cid)-L.jpg")
        }

        return BookSearchResult(
            id:             "ol_\(key)",
            title:          title,
            authors:        doc.author_name ?? [],
            pageCount:      doc.number_of_pages_median,
            coverURL:       small,
            highResCoverURL: large,
            publisher:      doc.publisher?.first,
            publishedDate:  doc.first_publish_year.map { String($0) },
            language:       doc.language?.first
        )
    }

    // MARK: - Merge & Deduplicate

    // Sıralama: Katalog (bizim veri) → Türkçe → OL → Google
    private static nonisolated func mergeAll(
        catalog: [BookSearchResult],
        google: [BookSearchResult],
        openLibrary: [BookSearchResult]
    ) -> [BookSearchResult] {
        var seen: Set<String> = []
        var merged: [BookSearchResult] = []

        // 1. Katalog her zaman üste — kendi verimiz, en güvenilir
        for r in catalog {
            let key = normalize(r.title + r.authorsText)
            if seen.insert(key).inserted { merged.append(r) }
        }

        // 2. Geri kalanları dil + kaynak sırasıyla ekle
        let rest = (openLibrary + google).sorted { a, b in
            let aIsOL      = a.id.hasPrefix("ol_")
            let bIsOL      = b.id.hasPrefix("ol_")
            let aIsTurkish = a.language == "tr" || a.language == "tur"
            let bIsTurkish = b.language == "tr" || b.language == "tur"
            if aIsTurkish != bIsTurkish { return aIsTurkish }
            if aIsOL != bIsOL { return aIsOL }
            return false
        }

        for r in rest {
            let key = normalize(r.title + r.authorsText)
            if seen.insert(key).inserted { merged.append(r) }
        }

        return merged
    }

    private static nonisolated func normalize(_ s: String) -> String {
        s.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .filter { $0.isLetter || $0.isNumber }
    }
}
