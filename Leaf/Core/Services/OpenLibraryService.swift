// OpenLibraryService.swift
// Google Books ve OpenLibrary'yi paralel çalıştırıyorum
// Google hızlı gelince hemen gösteriyorum, OpenLibrary gelince (Türkçe'de daha kapsamlı) sonuçları birleştiriyorum

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

// AddBookView hâlâ bu ismi kullanıyor, geriye dönük uyumluluk için tutuyorum
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

// MARK: - URL Session'ları (static çünkü nonisolated'dan erişiyorum)

private enum Sessions {
    // Google kısa timeout'lu — zaten hızlı, uzun beklemeye gerek yok
    static let google: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 8
        return URLSession(configuration: c)
    }()

    // OpenLibrary biraz daha yavaş olabiliyor, cache de ekledim
    static let openLibrary: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 6
        c.timeoutIntervalForResource = 8
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

    // 200ms debounce — her tuş vuruşunda istek atmamak için
    func search(query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            errorMessage = nil
            isLoading = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
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

        // üç kaynağı aynı anda başlatıyorum
        async let catalogFetch = fetchCatalog(query: query)
        async let olFetch      = Self.fetchOpenLibrary(query: query)
        async let googleFetch  = Self.fetchGoogle(query: query)

        // katalog en hızlı (~100ms civarı) — gelince hemen gösteriyorum
        let catalogResults = await catalogFetch
        guard !Task.isCancelled else { isLoading = false; return }
        if !catalogResults.isEmpty { results = catalogResults }

        // OpenLibrary daha doğru sonuç veriyor, onu bekleyip merge ediyorum
        let olResults = (try? await olFetch) ?? []
        guard !Task.isCancelled else { isLoading = false; return }
        results = Self.mergeAll(catalog: catalogResults, google: [], openLibrary: olResults)
        isLoading = false

        // Google arka planda geliyor — OL'u tamamlıyor
        let googleResults = (try? await googleFetch) ?? []
        guard !Task.isCancelled else { return }
        results = Self.mergeAll(catalog: catalogResults, google: googleResults, openLibrary: olResults)
    }

    // MARK: - Katalog Arama (Supabase, en hızlısı)

    private func fetchCatalog(query: String) async -> [BookSearchResult] {
        guard !query.isEmpty else { return [] }
        // başlık veya yazar isminde geçen her şeyi çek
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

    // MARK: - Google Books (nonisolated — main actor'ı beklemeden çalışıyor)

    private static nonisolated func fetchGoogle(query: String) async throws -> [BookSearchResult] {
        var comps = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        comps.queryItems = [
            .init(name: "q",          value: query),
            .init(name: "maxResults", value: "20"),
            .init(name: "printType",  value: "books")
        ]
        guard let url = comps.url else { return [] }

        let (data, resp) = try await Sessions.google.data(from: url)
        guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else { return [] }
        let decoded = try JSONDecoder().decode(GBResponse.self, from: data)
        return (decoded.items ?? []).compactMap { mapGoogle($0) }
    }

    private static nonisolated func mapGoogle(_ item: GBItem) -> BookSearchResult? {
        guard let info = item.volumeInfo, let title = info.title else { return nil }

        // Google bazen http:// veriyor, https'ye çeviriyorum
        func toHTTPS(_ s: String?) -> URL? {
            guard let s else { return nil }
            return URL(string: s.replacingOccurrences(of: "http://", with: "https://"))
        }

        let small   = toHTTPS(info.imageLinks?.smallThumbnail)
        let thumb   = toHTTPS(info.imageLinks?.thumbnail)
        // zoom=1'i zoom=3'e çevirince daha yüksek çözünürlük geliyor
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

    // MARK: - OpenLibrary (arka planda — q parametresi her alanı tarıyor)

    private static nonisolated func fetchOpenLibrary(query: String) async throws -> [BookSearchResult] {
        var comps = URLComponents(string: "https://openlibrary.org/search.json")!
        comps.queryItems = [
            .init(name: "q",           value: query),
            .init(name: "limit",       value: "12"),
            .init(name: "fields",      value: "key,title,author_name,number_of_pages_median,cover_i,publisher,first_publish_year,language")
        ]
        guard let url = comps.url else { return [] }

        let (data, resp) = try await Sessions.openLibrary.data(from: url)
        guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else { return [] }
        let decoded = try JSONDecoder().decode(OLResponse.self, from: data)
        return (decoded.docs ?? []).compactMap { mapOL($0) }
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

    // sıralama: kendi kataloğumuz → Türkçe → OpenLibrary → Google
    private static nonisolated func mergeAll(
        catalog: [BookSearchResult],
        google: [BookSearchResult],
        openLibrary: [BookSearchResult]
    ) -> [BookSearchResult] {
        var seen: Set<String> = []
        var merged: [BookSearchResult] = []

        // kendi katalog verimiz her zaman en üste çıkıyor
        for r in catalog {
            let key = normalize(r.title + r.authorsText)
            if seen.insert(key).inserted { merged.append(r) }
        }

        // geri kalanları dil ve kaynak sırasına göre sıralayıp ekliyorum
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
