import SwiftUI

// kapak resmi yönetimi — her kart kendi CoverLoader'ını @StateObject olarak tutuyor
// böylece bir kapak yüklenince sadece o kart render ediliyor, tüm grid değil
// bellek (NSCache) + disk cache sayesinde bir kez indirilen kapak sadece bu
// oturumda değil, uygulama yeniden açıldığında da tekrar indirilmiyor

// MARK: - Uygulama Geneli Bellek Önbelleği

private final class CoverCacheStore: @unchecked Sendable {
    static let shared = CoverCacheStore()

    private let cache: NSCache<NSString, NSData>
    private let diskDir: URL
    private let ioQueue = DispatchQueue(label: "leaf.cover-disk-cache", qos: .utility)

    private init() {
        cache = NSCache()
        cache.countLimit       = 150          // en fazla 150 kapak bellekte tutulsun
        cache.totalCostLimit   = 50 * 1024 * 1024  // 50 MB üzerine çıkmasın

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskDir = caches.appendingPathComponent("book-covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDir, withIntermediateDirectories: true)
    }

    private func diskPath(for key: String) -> URL {
        diskDir.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_"))
    }

    // bellek boşsa (ör. uygulama yeniden açıldı) diske bakıyoruz —
    // önceden bir kez indirilmiş kapak artık her açılışta tekrar inmiyor
    func get(_ key: String) -> Data? {
        if let cached = cache.object(forKey: key as NSString) as Data? {
            return cached
        }
        guard let diskData = try? Data(contentsOf: diskPath(for: key)) else { return nil }
        cache.setObject(diskData as NSData, forKey: key as NSString, cost: diskData.count)
        return diskData
    }

    func set(_ key: String, data: Data) {
        cache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        // diske yazmayı ana thread dışına alıyoruz — grid'de aynı anda çok kapak
        // inince ana thread'de takılma olmasın
        let path = diskPath(for: key)
        ioQueue.async {
            try? data.write(to: path)
        }
    }
}

// MARK: - CoverLoader

@MainActor
final class CoverLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    private var isLoading = false
    private let path: String?

    private static let baseURL =
        "https://qowvamowkmysdjrnhkkb.supabase.co/storage/v1/object/public/book-covers/"

    // cache'de varsa init sırasında senkron olarak decode ediyoruz — böylece
    // view ilk kez çizildiğinde görsel zaten hazır oluyor, placeholder hiç
    // görünmüyor (önceden her hücre cache'te olsa bile bir an placeholder
    // gösterip .task ile asenkron yükleniyordu)
    init(path: String?) {
        self.path = path
        if let path, let cached = CoverCacheStore.shared.get(path) {
            image = UIImage(data: cached)
        }
    }

    func loadIfNeeded() async {
        guard let path, image == nil, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        let urlString = Self.baseURL + path
        guard let url = URL(string: urlString) else { return }

        if let (data, _) = try? await URLSession.shared.data(from: url) {
            CoverCacheStore.shared.set(path, data: data)
            image = UIImage(data: data)
        }
    }
}

// MARK: - CoverImageView

struct CoverImageView: View {
    @StateObject private var loader: CoverLoader
    @Environment(\.colorScheme) private var scheme

    // Storage path: {userId}/{bookId} — nil gelirse kapak yok demek
    let coverUrl: String?
    var placeholderIconSize: CGFloat = 36

    init(coverUrl: String?, placeholderIconSize: CGFloat = 36) {
        self.coverUrl = coverUrl
        self.placeholderIconSize = placeholderIconSize
        _loader = StateObject(wrappedValue: CoverLoader(path: coverUrl))
    }

    var body: some View {
        Group {
            if let img = loader.image {
                GeometryReader { geo in
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            } else if coverUrl != nil {
                loadingPlaceholder
            } else {
                emptyPlaceholder
            }
        }
        .clipped()
        .task { await loader.loadIfNeeded() }
    }

    private var loadingPlaceholder: some View {
        ZStack {
            gradientBackground
            ProgressView()
                .scaleEffect(0.8)
                .tint(LeafColors.accent(for: scheme).opacity(0.5))
        }
    }

    private var emptyPlaceholder: some View {
        ZStack {
            gradientBackground
            Image(systemName: "book.closed")
                .font(.system(size: placeholderIconSize, weight: .ultraLight))
                .foregroundStyle(LeafColors.accent(for: scheme).opacity(0.4))
        }
    }

    private var gradientBackground: some View {
        LinearGradient(
            colors: [
                LeafColors.accent(for: scheme).opacity(0.15),
                LeafColors.accent(for: scheme).opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
