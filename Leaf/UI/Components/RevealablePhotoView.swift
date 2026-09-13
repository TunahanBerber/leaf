import SwiftUI

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

    // Paylaşılan önbellekte bu kullanıcı için bir kayıt varsa (Discover/Mesajlar
    // listesi toplu çekmişse) onu anında kullanıyoruz — kendi tekil fetch'imizin
    // bitmesini beklemeye gerek kalmıyor, "önce avatar sonra fotoğraf" gecikmesi
    // burada ortadan kalkıyor. social.photoRevealCache güncellenince (prefetch
    // tamamlanınca) bu view otomatik yeniden çizilir çünkü @Published okunuyor.
    private var effectiveReveal: PhotoReveal {
        social.photoRevealCache[userId] ?? reveal
    }

    private var hasVisibleImage: Bool {
        effectiveReveal.url != nil && (effectiveReveal.stage == .blurred || effectiveReveal.stage == .revealed)
    }

    var body: some View {
        ZStack {
            if hasVisibleImage, let url = effectiveReveal.url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        silhouette
                    }
                }
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
        .fullScreenCover(isPresented: $showDetail) {
            PhotoDetailView(
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
        // Prefetch zaten doldurmuşsa (Discover/Mesajlar listesi) ekstra bir
        // network isteği atmaya gerek yok — effectiveReveal zaten onu kullanıyor.
        // forceRefresh sadece reveal onayından hemen sonra kullanılıyor, çünkü o
        // an itibariyle önbellekteki eski (henüz onaylanmamış) değer artık geçersiz.
        if !forceRefresh, social.photoRevealCache[userId] != nil { return }
        let result = await social.fetchProfilePhoto(targetUserId: userId)
        reveal = result
        social.photoRevealCache[userId] = result
    }
}

// MARK: - Photo Detail (WhatsApp tarzı büyük görünüm)

// Bulanık fotoğrafın büyük halini gösterir; sohbet bağlamındaysa (conversationId
// verildiyse) altta "Fotoğrafı Gör" butonu ile karşılıklı reveal isteğini burada
// başlatıyoruz — Keşfet kartlarında (conversationId yok) sadece büyütüp gösteriyoruz.
private struct PhotoDetailView: View {
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

                if let url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable()
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
