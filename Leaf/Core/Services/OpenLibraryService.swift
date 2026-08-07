// OpenLibraryService.swift
// Google Books ve OpenLibrary'yi paralel çalıştırıyorum
// Google hızlı gelince hemen gösteriyorum, OpenLibrary gelince (Türkçe'de daha kapsamlı) sonuçları birleştiriyorum
// Sorguyu intitle:/inauthor: gibi alan bazlı kuruyoruz, sonra sonuçları query'ye benzerliğe göre skorlayıp sıralıyoruz

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
    // Google arka planda gelene kadar true kalıyor — results boşken bunu
    // beklemeden "sonuç yok" göstermek, Google birazdan dolduracak olsa bile
    // kullanıcıya yanlışlıkla arama boşmuş gibi görünmesine yol açıyordu
    @Published var isSearchComplete = false

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
        // yazarken tetiklenmiş bekleyen debounce task'ı iptal edip yerine
        // bunu koyuyorum — yoksa Enter'dan az sonra devreye girip
        // results'ı sıfırlıyordu (ilk Enter'da "sonuç yok" görünmesinin sebebi buydu)
        searchTask?.cancel()
        let task = Task { await performSearch(query: query) }
        searchTask = task
        await task.value
    }

    func clear() {
        searchTask?.cancel()
        results = []
        errorMessage = nil
        isLoading = false
        isSearchComplete = false
    }

    // MARK: - Sorgu Ayrıştırma

    // "yazar:" prefix'i ile kullanıcı açıkça yazar aramak istediğini belirtebiliyor,
    // yoksa default olarak başlık araması varsayıyoruz (en yaygın kullanım)
    private struct ParsedQuery {
        enum Kind { case title, author }
        let kind: Kind
        let term: String
    }

    private static nonisolated func parseQuery(_ raw: String) -> ParsedQuery {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let authorPrefixes = ["yazar:", "yazar :", "author:", "by:"]
        let lowered = trimmed.lowercased()
        for prefix in authorPrefixes where lowered.hasPrefix(prefix) {
            let term = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            return ParsedQuery(kind: .author, term: term)
        }
        return ParsedQuery(kind: .title, term: trimmed)
    }

    // MARK: - 3 Aşamalı Arama

    private func performSearch(query: String) async {
        isLoading = true
        isSearchComplete = false
        errorMessage = nil
        results = []

        let parsed = Self.parseQuery(query)

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
        results = Self.mergeAll(catalog: catalogResults, google: [], openLibrary: olResults, parsed: parsed)
        isLoading = false

        // Google arka planda geliyor — OL'u tamamlıyor
        let googleResults = (try? await googleFetch) ?? []
        guard !Task.isCancelled else { return }
        results = Self.mergeAll(catalog: catalogResults, google: googleResults, openLibrary: olResults, parsed: parsed)
        isSearchComplete = true
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
        let parsed = parseQuery(query)
        guard !parsed.term.isEmpty else { return [] }

        switch parsed.kind {
        case .author:
            return try await fetchGoogle(fieldQuery: "inauthor:\(parsed.term)")
        case .title:
            // "yazar:" prefix'i yoksa kullanıcı bir kişi ismi de yazmış olabilir
            // (örn. "Hakan Günday") — sadece intitle: ile aramak o yazarın YAZDIĞI
            // kitapları değil, başlığında ismi geçen (hakkında yazılmış) kitapları
            // buluyordu; kendi romanları hiç sorgulanmıyordu bile. İkisini birden
            // soruyoruz, skorlama hangisinin daha alakalı olduğuna karar veriyor.
            async let titleResults  = fetchGoogle(fieldQuery: "intitle:\(parsed.term)")
            async let authorResults = fetchGoogle(fieldQuery: "inauthor:\(parsed.term)")
            let (t, a) = try await (titleResults, authorResults)
            var seen = Set<String>()
            var merged: [BookSearchResult] = []
            for r in t + a where seen.insert(r.id).inserted { merged.append(r) }
            return merged
        }
    }

    private static nonisolated func fetchGoogle(fieldQuery: String) async throws -> [BookSearchResult] {
        var comps = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        comps.queryItems = [
            .init(name: "q",          value: fieldQuery),
            .init(name: "maxResults", value: "20"),
            .init(name: "printType",  value: "books")
        ]

        // key olmadan anonim/paylaşımlı kotaya düşüyor, çok kolay doluyor —
        // kendi projemizin key'i varsa mutlaka ekliyoruz
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_BOOKS_API_KEY") as? String,
           !apiKey.isEmpty, !apiKey.hasPrefix("$(") {
            comps.queryItems?.append(.init(name: "key", value: apiKey))
        }

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
        // zoom=1'i zoom=3'e çevirip "yüksek çözünürlük" istemek bazı kitaplarda
        // Google'ın gerçek kapak yerine kendi 575x750 "image not available"
        // placeholder'ını sessizce (HTTP 200 ile) döndürmesine yol açıyordu —
        // kaldırdık, zoom=1 zaten çalışan tek gerçek kaynak

        return BookSearchResult(
            id:             "gb_\(item.id)",
            title:          title,
            authors:        info.authors ?? [],
            pageCount:      info.pageCount,
            coverURL:       small ?? thumb,
            highResCoverURL: thumb ?? small,
            publisher:      info.publisher,
            publishedDate:  info.publishedDate,
            language:       info.language
        )
    }

    // MARK: - OpenLibrary (arka planda — title/author alanına göre daraltıyoruz)

    private static nonisolated func fetchOpenLibrary(query: String) async throws -> [BookSearchResult] {
        let parsed = parseQuery(query)
        guard !parsed.term.isEmpty else { return [] }

        switch parsed.kind {
        case .author:
            return try await fetchOpenLibrary(field: "author", term: parsed.term)
        case .title:
            // Google tarafındaki gerekçenin aynısı: prefix yoksa hem title hem
            // author alanında arayıp birleştiriyoruz, tek başına title araması
            // kişi ismi sorgularında gerçek yazarın kitaplarını atlıyordu.
            async let titleResults  = fetchOpenLibrary(field: "title",  term: parsed.term)
            async let authorResults = fetchOpenLibrary(field: "author", term: parsed.term)
            let (t, a) = try await (titleResults, authorResults)
            var seen = Set<String>()
            var merged: [BookSearchResult] = []
            for r in t + a where seen.insert(r.id).inserted { merged.append(r) }
            return merged
        }
    }

    private static nonisolated func fetchOpenLibrary(field: String, term: String) async throws -> [BookSearchResult] {
        let items: [URLQueryItem] = [
            .init(name: "limit",  value: "12"),
            .init(name: "fields", value: "key,title,author_name,number_of_pages_median,cover_i,publisher,first_publish_year,language"),
            .init(name: field,    value: term)
        ]

        var comps = URLComponents(string: "https://openlibrary.org/search.json")!
        comps.queryItems = items
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

    // sıralama: kendi kataloğumuz → relevance skoru → Türkçe → OpenLibrary → Google
    private static nonisolated func mergeAll(
        catalog: [BookSearchResult],
        google: [BookSearchResult],
        openLibrary: [BookSearchResult],
        parsed: ParsedQuery
    ) -> [BookSearchResult] {
        var seen: Set<String> = []
        var merged: [BookSearchResult] = []

        // kendi katalog verimiz her zaman en üste çıkıyor
        for r in catalog {
            let key = normalize(r.title + r.authorsText)
            if seen.insert(key).inserted { merged.append(r) }
        }

        // her sonucu query'ye ne kadar benzediğine göre skorluyoruz, alakasızları eliyoruz,
        // eşit skorlarda dil/kaynak önceliği devreye giriyor
        let scoredRest = (openLibrary + google)
            .map { r in (result: r, score: relevanceScore(for: r, parsed: parsed)) }
            .filter { $0.score >= 5 }
            .sorted { a, b in
                if abs(a.score - b.score) > 1 { return a.score > b.score }

                let aIsOL      = a.result.id.hasPrefix("ol_")
                let bIsOL      = b.result.id.hasPrefix("ol_")
                let aIsTurkish = a.result.language == "tr" || a.result.language == "tur"
                let bIsTurkish = b.result.language == "tr" || b.result.language == "tur"
                if aIsTurkish != bIsTurkish { return aIsTurkish }
                if aIsOL != bIsOL { return aIsOL }
                return false
            }

        for (r, _) in scoredRest {
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

    // MARK: - Relevance Scoring

    // query'ye başlık/yazar benzerliğine göre 0-100 arası skor üretiyoruz;
    // tam eşleşme > prefix > substring > fuzzy (typo toleranslı) sırasıyla puanlanıyor
    private static nonisolated func relevanceScore(for result: BookSearchResult, parsed: ParsedQuery) -> Double {
        let term = normalize(parsed.term)
        guard !term.isEmpty else { return 50 }

        let title  = normalize(result.title)
        let author = normalize(result.authorsText)

        func matchScore(_ text: String) -> Double {
            guard !text.isEmpty else { return 0 }
            if text == term { return 100 }
            if text.hasPrefix(term) { return 90 }
            if text.contains(term) { return 75 }
            return similarity(text, term) * 60
        }

        let titleScore  = matchScore(title)
        let authorScore = matchScore(author)

        switch parsed.kind {
        case .author:
            // yazar araması: yazar eşleşmesi asıl, başlık ikincil
            return max(authorScore, titleScore * 0.3)
        case .title:
            // "yazar:" prefix'i olmayan sorgularda güçlü (tam/prefix/substring,
            // >=75) bir yazar eşleşmesi artık title'la eşit ağırlıkta — "Hakan
            // Günday" gibi kişi adı sorgularında onun HAKKINDA yazılmış kitaplar
            // yerine kendi romanları öne çıksın diye. Ama sadece fuzzy (typo
            // toleranslı, <75) yazar eşleşmesi hâlâ indirimli kalıyor — yoksa
            // "harry poter" gibi typo'lu aramalarda author alanı kötü kullanılmış
            // (örn. ürün adı = "Harry Potter") kayıtlar gerçek kitapların önüne geçiyor.
            let authorWeight = authorScore >= 75 ? 1.0 : 0.5
            return max(titleScore, authorScore * authorWeight)
        }
    }

    // Levenshtein tabanlı normalize edilmiş benzerlik (0...1) — typo'lara toleranslı
    private static nonisolated func similarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let distance = levenshteinDistance(a, b)
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else { return 0 }
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    private static nonisolated func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        guard !aChars.isEmpty else { return bChars.count }
        guard !bChars.isEmpty else { return aChars.count }

        var dp = Array(0...bChars.count)
        for i in 1...aChars.count {
            var prev = dp[0]
            dp[0] = i
            for j in 1...bChars.count {
                let temp = dp[j]
                dp[j] = aChars[i - 1] == bChars[j - 1] ? prev : 1 + min(prev, dp[j], dp[j - 1])
                prev = temp
            }
        }
        return dp[bChars.count]
    }
}
