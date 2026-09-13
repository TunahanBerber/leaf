import SwiftUI

// MARK: - Görsel Bayt Önbelleği (path-bazlı)

// get-profile-photo(s) her çağrıda YENİ bir signed URL üretiyor (imza+expiry
// değişiyor) — fotoğrafın byte'ları aynı kalsa bile. AsyncImage/URLCache bu URL'e
// göre önbelliyor olsaydı, aynı fotoğraf her ekran ziyaretinde/app açılışında
// baştan inerdi. Bunun yerine CoverImageView'daki kitap kapağı önbelleğiyle aynı
// mantığı kullanıyoruz: cache anahtarı, storage'daki SABİT path ({userId}/original.jpg
// veya {userId}/blurred.jpg) — bu, imza her değiştiğinde de aynı kalıyor.
// SocialService.uploadProfilePhoto de kendi fotoğrafını yükledikten hemen sonra
// buraya taze byte'ları yazıyor (bkz. SocialService.swift) — bu yüzden internal.
final class ProfilePhotoCacheStore: @unchecked Sendable {
    static let shared = ProfilePhotoCacheStore()

    private let cache: NSCache<NSString, NSData>
    private let diskDir: URL
    private let ioQueue = DispatchQueue(label: "leaf.profile-photo-disk-cache", qos: .utility)

    private init() {
        cache = NSCache()
        cache.countLimit     = 200
        cache.totalCostLimit = 50 * 1024 * 1024

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskDir = caches.appendingPathComponent("profile-photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDir, withIntermediateDirectories: true)
    }

    private func diskPath(for key: String) -> URL {
        diskDir.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_"))
    }

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
        let path = diskPath(for: key)
        ioQueue.async {
            try? data.write(to: path)
        }
    }
}

// Aşamalı fotoğraf açma: hiç/blur/orijinal ayrımına sunucu (get-profile-photo Edge
// Function'ı) karar veriyor, burada sadece dönen aşamaya göre uygun görsel gösteriliyor.
// Kendi fotoğrafın (userId == kendi id'n) için sunucu her zaman "revealed" döner, o
// yüzden bu view profil/ayarlar ekranlarında düz avatar göstermek için de kullanılabilir.
struct RevealablePhotoView: View {
    let userId: String
    var conversationId: String? = nil
    var size: CGFloat = 56

    @Environment(SocialService.self) var social
    @Environment(\.colorScheme) var colorScheme
    @State private var reveal = PhotoReveal(stage: .hidden, url: nil)
    @State private var hasConfirmed = false
    @State private var showDetail = false
    @State private var loadedImage: UIImage?

    // Paylaşılan önbellekte bu kullanıcı için bir kayıt varsa (Discover/Mesajlar
    // listesi toplu çekmişse) onu anında kullanıyoruz — kendi tekil fetch'imizin
    // bitmesini beklemeye gerek kalmıyor, "önce avatar sonra fotoğraf" gecikmesi
    // burada ortadan kalkıyor. social.photoRevealCache güncellenince (prefetch
    // tamamlanınca) bu view otomatik yeniden çizilir çünkü @Observable okunuyor.
    private var effectiveReveal: PhotoReveal {
        social.photoRevealCache[userId] ?? reveal
    }

    private var hasVisibleImage: Bool {
        effectiveReveal.url != nil && (effectiveReveal.stage == .blurred || effectiveReveal.stage == .revealed)
    }

    // Storage'daki sabit path — hangi varyantın (blur/orijinal) gösterileceğini
    // stage zaten belirlediği için path'i URL'den değil doğrudan buradan türetiyoruz.
    private var derivedPath: String? {
        switch effectiveReveal.stage {
        case .revealed: return "\(userId)/original.jpg"
        case .blurred:  return "\(userId)/blurred.jpg"
        case .none, .hidden: return nil
        }
    }

    var body: some View {
        ZStack {
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                silhouette
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .contentShape(Circle())
        // WhatsApp'taki gibi: avatara dokunca büyük gösteriyoruz, "blur'u kaldır"
        // isteği o büyük görünümdeki buton üzerinden gidiyor — avatarın üzerinde
        // ayrıca bir rozet/ikon yok.
        .onTapGesture {
            if hasVisibleImage { showDetail = true }
        }
        .task(id: "\(userId)-\(conversationId ?? "")") { await load() }
        .task(id: derivedPath) { await loadImageIfNeeded() }
        .fullScreenCover(isPresented: $showDetail) {
            PhotoDetailView(
                image: loadedImage,
                url: effectiveReveal.url,
                stage: effectiveReveal.stage,
                canRequestReveal: conversationId != nil,
                hasConfirmed: hasConfirmed,
                onRequestReveal: {
                    guard let conversationId else { return }
                    Task {
                        _ = await social.confirmPhotoReveal(conversationId: conversationId)
                        hasConfirmed = true
                        await load(forceRefresh: true)
                    }
                }
            )
        }
    }

    private var silhouette: some View {
        Circle()
            .fill(LeafColors.accent(for: colorScheme).opacity(0.15))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(LeafColors.accent(for: colorScheme))
            }
    }

    private func load(forceRefresh: Bool = false) async {
        // Prefetch zaten taze bir kayıt bırakmışsa (Discover/Mesajlar listesi)
        // ekstra bir network isteği atmaya gerek yok — effectiveReveal zaten onu
        // kullanıyor. Kayıt varsa ama süresi (signed URL TTL'i) geçmişse burada
        // da yeniliyoruz, yoksa süresi dolmuş bir URL sonsuza kadar önbellekte kalırdı.
        // forceRefresh sadece reveal onayından hemen sonra kullanılıyor, çünkü o
        // an itibariyle önbellekteki eski (henüz onaylanmamış) değer artık geçersiz.
        if !forceRefresh, social.isPhotoRevealFresh(for: userId) { return }
        let result = await social.fetchProfilePhoto(targetUserId: userId)
        reveal = result
        social.cachePhotoReveal(result, for: userId)
    }

    // Görsel byte'larını path'e göre önbellekten okur; yoksa signed URL'den bir kez
    // indirip path anahtarıyla kaydeder — imza her yenilendiğinde path aynı kaldığı
    // için bir daha asla yeniden inmiyor (bkz. ProfilePhotoCacheStore).
    private func loadImageIfNeeded() async {
        guard let path = derivedPath else {
            loadedImage = nil
            return
        }
        if let cached = ProfilePhotoCacheStore.shared.get(path), let image = UIImage(data: cached) {
            loadedImage = image
            return
        }
        guard let url = effectiveReveal.url else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        ProfilePhotoCacheStore.shared.set(path, data: data)
        loadedImage = UIImage(data: data)
    }
}

// MARK: - Photo Detail (WhatsApp tarzı büyük görünüm)

// Bulanık fotoğrafın büyük halini gösterir; sohbet bağlamındaysa (conversationId
// verildiyse) altta "Fotoğrafı Gör" butonu ile karşılıklı reveal isteğini burada
// başlatıyoruz — Keşfet kartlarında (conversationId yok) sadece büyütüp gösteriyoruz.
private struct PhotoDetailView: View {
    // Avatar zaten indirip önbelleğe aldıysa (neredeyse her zaman) burada onu
    // doğrudan gösteriyoruz — aynı byte'ları ikinci kez indirmeye gerek yok.
    // Yalnızca avatar'ın kendi yükleme task'ı henüz bitmediyse url'den AsyncImage
    // ile yedek olarak çekiyoruz.
    let image: UIImage?
    let url: URL?
    let stage: PhotoRevealStage
    let canRequestReveal: Bool
    let hasConfirmed: Bool
    let onRequestReveal: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding()
                }

                Spacer()

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal, 24)
                } else if let url {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .padding(.horizontal, 24)
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                }

                Spacer()

                if stage == .blurred && canRequestReveal {
                    if hasConfirmed {
                        Text("İstek gönderildi — karşı taraf da onaylayınca net görünecek")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 48)
                    } else {
                        Button(action: onRequestReveal) {
                            Label("Fotoğrafı Gör", systemImage: "eye.fill")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(.white, in: Capsule())
                        }
                        .padding(.bottom, 48)
                    }
                }
            }
        }
    }
}
