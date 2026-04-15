import SwiftUI

// kapak resmi yönetimi — her kart kendi CoverLoader'ını @StateObject olarak tutuyor
// böylece bir kapak yüklenince sadece o kart render ediliyor, tüm grid değil
// NSCache sayesinde bir kez indirilen kapak oturum boyunca tekrar indirilmiyor

// MARK: - Uygulama Geneli Bellek Önbelleği

private final class CoverCacheStore: @unchecked Sendable {
    static let shared = CoverCacheStore()

    private let cache: NSCache<NSString, NSData>

    private init() {
        cache = NSCache()
        cache.countLimit       = 150          // en fazla 150 kapak bellekte tutulsun
        cache.totalCostLimit   = 50 * 1024 * 1024  // 50 MB üzerine çıkmasın
    }

    func get(_ key: String) -> Data? {
        cache.object(forKey: key as NSString) as Data?
    }

    func set(_ key: String, data: Data) {
        cache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
    }
}

// MARK: - CoverLoader

@MainActor
final class CoverLoader: ObservableObject {
    @Published private(set) var imageData: Data?
    private var isLoading = false

    private static let baseURL =
        "https://qowvamowkmysdjrnhkkb.supabase.co/storage/v1/object/public/book-covers/"

    func load(from path: String?) async {
        guard let path, imageData == nil, !isLoading else { return }

        // önce bellekte var mı diye bakıyorum
        if let cached = CoverCacheStore.shared.get(path) {
            imageData = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        let urlString = Self.baseURL + path
        guard let url = URL(string: urlString) else { return }

        if let (data, _) = try? await URLSession.shared.data(from: url) {
            CoverCacheStore.shared.set(path, data: data)
            imageData = data
        }
    }
}

// MARK: - CoverImageView

struct CoverImageView: View {
    @StateObject private var loader = CoverLoader()
    @Environment(\.colorScheme) private var scheme

    // Storage path: {userId}/{bookId} — nil gelirse kapak yok demek
    let coverUrl: String?
    var placeholderIconSize: CGFloat = 36

    var body: some View {
        Group {
            if let data = loader.imageData, let img = UIImage(data: data) {
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
        .task { await loader.load(from: coverUrl) }
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
