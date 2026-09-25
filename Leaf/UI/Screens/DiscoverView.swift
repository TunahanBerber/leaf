import SwiftUI

struct DiscoverView: View {
    @Environment(SocialService.self) var socialService
    @Environment(\.colorScheme) var colorScheme
    // geçilen/gizlenen kullanıcılar bu oturumda vitrinde tekrar görünmesin
    @State private var excludedIds: Set<String> = []
    @State private var showSentRequests = false
    @State private var showCityFilter = false
    @State private var showPassedUsers = false
    @State private var cityFilter: String?
    // Gizlediklerim panelinde gerçekten "Geri Getir" denip denmediğini takip
    // ediyoruz — sadece açıp kapatmak listeyi yeniden çekmeye değmez,
    // gereksiz bir istek olurdu. Sadece bir şey değiştiyse tazeliyoruz.
    @State private var passedListChanged = false

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 190), spacing: LeafSpacing.md)
    ]

    // zaten sohbeti olan kullanıcılar
    private var matchedUserIds: Set<String> {
        guard let myId = socialService.currentProfile?.id else { return [] }
        return Set(socialService.conversations.map { $0.userAId == myId ? $0.userBId : $0.userAId })
    }

    // uygulama yeniden başlatılsa bile zaten istek gönderilmiş veya sohbeti
    // olan kullanıcılar vitrin yeniden dolduğunda tekrar önümüze gelmesin
    private var discoverList: [UserProfile] {
        let requestedIds = Set(socialService.sentRequests.map(\.receiverId))
        let excluded = excludedIds.union(requestedIds).union(matchedUserIds)
        return socialService.discoveredUsers.filter { !excluded.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                Group {
                    if socialService.isLoadingDiscover {
                        ProgressView()
                            .tint(LeafColors.accent(for: colorScheme))
                    } else if discoverList.isEmpty {
                        emptyState
                    } else {
                        gridView
                    }
                }
            }
            .navigationTitle("Keşfet")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    cityFilterButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    passedUsersButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    sentRequestsButton
                }
            }
            // fetchSentRequests/fetchPassedUsers filtreden bağımsız, bir kez yeterli.
            .task {
                async let sent: () = socialService.fetchSentRequests()
                async let passed: () = socialService.fetchPassedUsers()
                _ = await (sent, passed)
            }
            // cityFilter değiştiğinde vitrin yeniden çekiliyor — discoverUsers
            // zaten listeyi ekrana yansıtmadan önce ilk görünecek fotoğrafları
            // kendi içinde önbelleğe alıyor (SocialService), burada ayrıca bir
            // şey gerekmiyor.
            .task(id: cityFilter) {
                await socialService.discoverUsers(cityFilter: cityFilter)
            }
            .sheet(isPresented: $showSentRequests) {
                SentRequestsSheet()
            }
            .sheet(isPresented: $showCityFilter) {
                CityPickerSheet(selectedCity: $cityFilter)
            }
            // Sadece gerçekten "Geri Getir" denildiyse vitrini yeniden çekiyoruz
            // (o kişi discover_users()'ta ancak swipes kaydı silindikten SONRA
            // tekrar görünür oluyor). Sırf açıp kapatmak bir istek atmıyor.
            .sheet(isPresented: $showPassedUsers, onDismiss: {
                guard passedListChanged else { return }
                passedListChanged = false
                excludedIds.removeAll()
                Task { await socialService.discoverUsers(cityFilter: cityFilter) }
            }) {
                PassedUsersSheet(onRestore: { passedListChanged = true })
            }
        }
    }

    // MARK: - Şehir Filtresi

    private var cityFilterButton: some View {
        // X'i ayrı bir Button olarak dışarıda tutuyoruz — bir Button'un LABEL'ı
        // içine .onTapGesture ile ikinci bir tıklanabilir eleman koymak SwiftUI'de
        // hit-test çakışması yaratıyor: iç dokunuş yerine dış Button'un kendi
        // action'ı tetikleniyor (X'e basınca filtre temizlenmek yerine sheet
        // yeniden açılıp başka bir şehir seçiliyordu).
        HStack(spacing: LeafSpacing.xs) {
            Button {
                showCityFilter = true
            } label: {
                HStack(spacing: LeafSpacing.xxs) {
                    Image(systemName: "mappin.circle.fill")
                    Text(cityFilter ?? "Tüm Şehirler")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
            }
            if cityFilter != nil {
                Button {
                    cityFilter = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
            }
        }
        .foregroundStyle(LeafColors.accent(for: colorScheme))
    }

    // MARK: - İstekler (gönderdiklerim)

    // MARK: - Gizlediklerim

    private var passedUsersButton: some View {
        Button {
            showPassedUsers = true
        } label: {
            Image(systemName: "eye.slash.circle")
                .foregroundStyle(LeafColors.accent(for: colorScheme))
                .overlay(alignment: .topTrailing) {
                    if !socialService.passedUsers.isEmpty {
                        CountBadge(count: socialService.passedUsers.count, color: .gray)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }

    private var sentRequestsButton: some View {
        Button {
            showSentRequests = true
        } label: {
            Image(systemName: "paperplane.fill")
                .foregroundStyle(LeafColors.accent(for: colorScheme))
                .overlay(alignment: .topTrailing) {
                    if !socialService.sentRequests.isEmpty {
                        CountBadge(count: socialService.sentRequests.count, color: .red)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }

    // MARK: - Vitrin (Grid)

    // Kart destesi + X/✓ modelinden kitaplık rafı gibi taranabilir bir
    // vitrine geçildi — aynı anda birden çok kişi görünür, karar (ilgileniyorum/
    // gizle) artık burada değil, karta dokunup tam profile girince veriliyor
    // (bkz. UserProfileView). LibraryGridView'daki adaptive grid ile aynı
    // deseni kullanıyoruz: maximum sınırı sayesinde yatay modda (ya da
    // iPad'de) kartlar büyümek yerine yeni sütun açılıyor.
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: LeafSpacing.lg) {
                ForEach(discoverList) { user in
                    gridCell(for: user)
                }
            }
            .padding(.horizontal, LeafSpacing.md)
            .padding(.top, LeafSpacing.xs)
            .padding(.bottom, LeafSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func gridCell(for user: UserProfile) -> some View {
        let destination = UserProfileView(profile: user, onPassed: {
            withAnimation(LeafMotion.spring) { _ = excludedIds.insert(user.id) }
        })
        NavigationLink(destination: destination) {
            DiscoverProfileTile(profile: user)
        }
        .buttonStyle(PressStyle())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: LeafSpacing.md) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
            Text("Henüz eşleşme yok")
                .font(.headline)
                .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
            Text("Kütüphanene kitap ekle,\nonu okuyan kişilerle buluş.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
        }
        .padding(LeafSpacing.xxl)
    }
}

// MARK: - Discover Profile Tile

// Kitaplık rafındaki kitap kartlarıyla aynı dil: dikey, foto-öncelikli,
// köşeleri yuvarlak. Kimlik bilgisi fotoğrafın üstünde bir gradyan
// scrim ile veriliyor — ayrı bir beyaz panel gerekmiyor, karar butonları da
// yok (tıklayınca tam profile gidiliyor, ilgileniyorum/gizle orada).
struct DiscoverProfileTile: View {
    let profile: UserProfile
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RevealablePhotoView(
                userId: profile.id,
                fillFrame: true,
                cornerRadius: LeafRadius.large,
                enablesTapToExpand: false
            )

            LinearGradient(
                colors: [.clear, .black.opacity(0.05), .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(profile.username)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                    if let age = profile.age {
                        Text("\(age)")
                            .font(.system(size: 13))
                            .opacity(0.85)
                    }
                }
                .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(LeafSpacing.sm)
        }
        .overlay(alignment: .topTrailing) {
            if profile.sameCity == true {
                Text("AYNI ŞEHİR")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, LeafSpacing.xs)
                    .padding(.vertical, 3)
                    .background(LeafColors.accent(for: colorScheme), in: Capsule())
                    .padding(LeafSpacing.xs)
            }
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: LeafRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let city = profile.city { parts.append(city) }
        if let books = profile.commonBookTitles, !books.isEmpty {
            parts.append("\(books.count) ortak kitap")
        }
        return parts.isEmpty ? " " : parts.joined(separator: " · ")
    }
}

// MARK: - Gönderdiğim İstekler Sheet

// Keşfet'in sağ üstündeki uçak ikonuyla açılır. Karşı taraf kabul ederse
// Realtime ile otomatik "Sohbetler"e taşınır, reddederse listeden düşer —
// bu sheet sadece socialService.sentRequests'i yansıtıyor, kendi state'i yok.
struct SentRequestsSheet: View {
    @Environment(SocialService.self) var socialService
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                if socialService.sentRequests.isEmpty {
                    sentEmptyState
                } else {
                    sentList
                }
            }
            .navigationTitle("İstek Gönderdiklerim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
            .refreshable { await socialService.fetchSentRequests() }
        }
    }

    private var sentList: some View {
        List {
            ForEach(socialService.sentRequests) { request in
                SentRequestRow(request: request)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await socialService.rejectRequest(request) }
                        } label: {
                            Label("İptal Et", systemImage: "xmark")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var sentEmptyState: some View {
        VStack(spacing: LeafSpacing.md) {
            Image(systemName: "paperplane")
                .font(.system(size: 40))
                .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
            Text("Henüz istek göndermedin")
                .font(.headline)
                .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
            Text("Keşfet'te birine \"İlgileniyorum\" dediğinde\nburada görünecek.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
        }
        .padding(LeafSpacing.xxl)
    }
}

// MARK: - Sent Request Row

// Instagram'ın "İstek Gönderildi" satırı gibi — burada aksiyon yok,
// sadece durum. Kabul edilirse Realtime ile otomatik "Sohbetler"e taşınır.
struct SentRequestRow: View {
    let request: ConversationRequest
    @Environment(\.colorScheme) var colorScheme

    private var displayName: String {
        request.receiverProfile?.username ?? String(request.receiverId.prefix(8))
    }

    var body: some View {
        HStack(spacing: LeafSpacing.md) {
            RevealablePhotoView(userId: request.receiverId, size: 48)

            VStack(alignment: .leading, spacing: LeafSpacing.xxs) {
                Text(displayName)
                    .font(.headline)
                    .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                Text("İstek gönderildi")
                    .font(.caption)
                    .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
            }

            Spacer()

            Text("Bekleniyor")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                .padding(.horizontal, LeafSpacing.sm)
                .padding(.vertical, LeafSpacing.xxs)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().stroke(LeafColors.borderSubtle(for: colorScheme))
                }
        }
        .padding(LeafSpacing.md)
        .background(LeafColors.surfacePrimary(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: LeafRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: LeafRadius.large)
                .stroke(LeafColors.borderSubtle(for: colorScheme))
        }
    }
}

// MARK: - Gizlediklerim Sheet'i

// Keşfet'te birini gizlemek (eski adıyla "pas geç") artık kalıcı (swipes
// tablosunda) — bu panel gizlediğin herkesi her zaman görebilmen ve
// istediğini "Geri Getir" ile tekrar Keşfet'e ekleyebilmen için var.
// socialService.passedUsers zaten bellekte güncel tutuluyor (gizleyince
// ekleniyor, geri getirince çıkarılıyor) — bu sheet açılırken/kapanırken
// AYRICA bir ağ isteği atmıyoruz, sadece elimizdeki veriyi gösteriyoruz.
// Bir şey değiştiyse (en az bir "Geri Getir") DiscoverView bunu dismiss'te
// kendi başına fark edip deste'yi tazeliyor.
struct PassedUsersSheet: View {
    @Environment(SocialService.self) var socialService
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    let onRestore: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                if socialService.passedUsers.isEmpty {
                    passedEmptyState
                } else {
                    passedList
                }
            }
            .navigationTitle("Gizlediklerim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
            // Parmakla aşağı çekip elle yenilemek istersen (ör. başka bir
            // cihazdan gizlemiştin) diye duruyor — ekran her açıldığında
            // otomatik tetiklenmiyor.
            .refreshable { await socialService.fetchPassedUsers() }
        }
    }

    private var passedList: some View {
        List {
            ForEach(socialService.passedUsers) { user in
                PassedUserRow(user: user, onRestore: onRestore)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var passedEmptyState: some View {
        VStack(spacing: LeafSpacing.md) {
            Image(systemName: "eye.slash.circle")
                .font(.system(size: 40))
                .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
            Text("Henüz kimseyi gizlemedin")
                .font(.headline)
                .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
            Text("Keşfet'te uygun bulmadıklarını\ngizleyebilirsin, listen burada birikir.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
        }
        .padding(LeafSpacing.xxl)
    }
}

// MARK: - Gizlenen Kullanıcı Satırı

struct PassedUserRow: View {
    let user: UserProfile
    let onRestore: () -> Void
    @Environment(SocialService.self) var socialService
    @Environment(\.colorScheme) var colorScheme
    @State private var isUndoing = false
    @State private var didUndo = false

    var body: some View {
        HStack(spacing: LeafSpacing.md) {
            RevealablePhotoView(userId: user.id, size: 48)

            // maxWidth: .infinity ile esnek alanı BU alıyor, buton hep kendi
            // doğal (tek satır) boyutunda kalıyor — isim uzunluğuna göre bazı
            // satırlarda buton metni sarılıp bazılarında sarılmıyordu.
            VStack(alignment: .leading, spacing: LeafSpacing.xxs) {
                Text(user.username)
                    .font(.headline)
                    .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                    .lineLimit(1)
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if didUndo {
                Label("Geri geldi", systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LeafColors.accent(for: colorScheme))
                    .lineLimit(1)
                    .fixedSize()
            } else {
                Button {
                    isUndoing = true
                    Task {
                        let ok = await socialService.undoPass(userId: user.id)
                        isUndoing = false
                        if ok {
                            didUndo = true
                            onRestore()
                        }
                    }
                } label: {
                    if isUndoing {
                        ProgressView().tint(LeafColors.accent(for: colorScheme))
                    } else {
                        Label("Geri Getir", systemImage: "arrow.uturn.left")
                            .labelStyle(.titleAndIcon)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.bordered)
                .tint(LeafColors.accent(for: colorScheme))
                .disabled(isUndoing)
                .fixedSize()
            }
        }
        .padding(LeafSpacing.md)
        .background(LeafColors.surfacePrimary(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: LeafRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: LeafRadius.large)
                .stroke(LeafColors.borderSubtle(for: colorScheme))
        }
    }
}

// MARK: - Sayaç Rozeti

// passedUsersButton/sentRequestsButton gibi toolbar ikonlarındaki bildirim
// sayıları için ortak rozet. iOS, topBarTrailing item'larını tek bir kapsülde
// grupluyor ve kapsülün boyutunu item'ların offset'siz gerçek boyutuna göre
// hesaplıyor — eski (x:9, y:-9) offset'i rozeti bu kapsülün dışına taşırıyordu.
// Burada offset'i belirgin şekilde küçültüp Circle yerine Capsule kullanıyoruz
// ki 2 haneli sayılarda da rozet sıkışıp deforme olmadan kapsülün içinde kalsın.
private struct CountBadge: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .frame(minWidth: 16, minHeight: 16)
            .background(color, in: Capsule())
            .offset(x: 5, y: -1)
    }
}
