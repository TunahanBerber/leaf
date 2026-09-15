import SwiftUI

struct DiscoverView: View {
    @Environment(SocialService.self) var socialService
    @Environment(\.colorScheme) var colorScheme
    @State private var navigateToProfile: UserProfile?
    // geçilen kullanıcılar bu oturumda destede tekrar görünmesin
    @State private var excludedIds: Set<String> = []
    @State private var isSubmitting = false
    @State private var showSentRequests = false
    @State private var showCityFilter = false
    @State private var showPassedUsers = false
    @State private var cityFilter: String?
    // Gizlediklerim panelinde gerçekten "Geri Getir" denip denmediğini takip
    // ediyoruz — sadece açıp kapatmak deste'yi yeniden çekmeye değmez,
    // gereksiz bir istek olurdu. Sadece bir şey değiştiyse tazeliyoruz.
    @State private var passedListChanged = false

    // zaten sohbeti olan kullanıcılar
    private var matchedUserIds: Set<String> {
        guard let myId = socialService.currentProfile?.id else { return [] }
        return Set(socialService.conversations.map { $0.userAId == myId ? $0.userBId : $0.userAId })
    }

    // uygulama yeniden başlatılsa bile zaten istek gönderilmiş veya sohbeti
    // olan kullanıcılar deste yeniden dolduğunda tekrar önümüze gelmesin
    private var deck: [UserProfile] {
        let requestedIds = Set(socialService.sentRequests.map(\.receiverId))
        let excluded = excludedIds.union(requestedIds).union(matchedUserIds)
        return socialService.discoveredUsers.filter { !excluded.contains($0.id) }
    }

    // en üstteki 3 kart, alttan üste çizilecek sırada (0 = en üstte, en önde)
    private var stackedCards: [(position: Int, user: UserProfile)] {
        deck.prefix(3)
            .enumerated()
            .map { (position: $0.offset, user: $0.element) }
            .reversed()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                Group {
                    if socialService.isLoadingDiscover {
                        ProgressView()
                            .tint(LeafColors.accent(for: colorScheme))
                    } else if deck.isEmpty {
                        emptyState
                    } else {
                        deckView
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
            // cityFilter değiştiğinde deste yeniden çekiliyor — discoverUsers
            // zaten listeyi ekrana yansıtmadan önce fotoğrafları kendi içinde
            // önbelleğe alıyor (SocialService), burada ayrıca bir şey gerekmiyor.
            .task(id: cityFilter) {
                await socialService.discoverUsers(cityFilter: cityFilter)
            }
            .navigationDestination(item: $navigateToProfile) { profile in
                UserProfileView(profile: profile)
            }
            .sheet(isPresented: $showSentRequests) {
                SentRequestsSheet()
            }
            .sheet(isPresented: $showCityFilter) {
                CityPickerSheet(selectedCity: $cityFilter)
            }
            // Sadece gerçekten "Geri Getir" denildiyse deste'yi yeniden çekiyoruz
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
                        Text("\(socialService.passedUsers.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.gray)
                            .clipShape(Circle())
                            .offset(x: 9, y: -9)
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
                        Text("\(socialService.sentRequests.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 9, y: -9)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }

    // MARK: - Deste

    private var deckView: some View {
        VStack(spacing: LeafSpacing.xl) {
            Spacer(minLength: 0)

            ZStack {
                ForEach(stackedCards, id: \.user.id) { item in
                    DiscoverStackCard(profile: item.user)
                        .scaleEffect(1 - CGFloat(item.position) * 0.04)
                        .offset(y: CGFloat(item.position) * 10)
                        .opacity(item.position == 0 ? 1 : 0.55)
                        .zIndex(Double(-item.position))
                        .allowsHitTesting(item.position == 0)
                        .onTapGesture { navigateToProfile = item.user }
                }
            }
            .animation(LeafMotion.spring, value: deck.map(\.id))

            Spacer(minLength: 0)

            decisionButtons
                .padding(.bottom, LeafSpacing.xl)
        }
        .padding(.horizontal, LeafSpacing.md)
    }

    private var decisionButtons: some View {
        HStack(spacing: LeafSpacing.xxl) {
            decisionButton(icon: "xmark", tint: .red, action: pass)
            decisionButton(icon: "checkmark", tint: LeafColors.accent(for: colorScheme), action: approve)
        }
        .disabled(isSubmitting)
    }

    private func decisionButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 64, height: 64)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().strokeBorder(tint.opacity(0.3), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
    }

    private func pass() {
        guard let user = deck.first else { return }
        withAnimation(LeafMotion.spring) {
            excludedIds.insert(user.id)
        }
        // Eskiden sadece bu oturumda (bellekte) geçerliydi — kapatıp açınca
        // aynı kişi tekrar karşına çıkıyordu. Artık kalıcı: record_swipe
        // (liked:false) sayesinde geri getirmediğin sürece bir daha hiç
        // çıkmıyor, GizlediklerimSheet'ten istediğin zaman geri getirebiliyorsun.
        // recordPass tüm profili alıyor ki Gizlediklerim listesine ekstra bir
        // ağ isteği atmadan, doğrudan bellekte ekleyebilsin.
        Task { await socialService.recordPass(user) }
    }

    private func approve() {
        guard let user = deck.first else { return }
        isSubmitting = true
        Task {
            _ = await socialService.sendConversationRequest(to: user.id)
            await socialService.fetchSentRequests()
            isSubmitting = false
            withAnimation(LeafMotion.spring) {
                excludedIds.insert(user.id)
            }
        }
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

// MARK: - Discover Stack Card

struct DiscoverStackCard: View {
    let profile: UserProfile
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GlassCard {
            VStack(spacing: LeafSpacing.lg) {
                avatar

                VStack(spacing: LeafSpacing.xxs) {
                    HStack(spacing: LeafSpacing.xxs) {
                        Text(profile.username)
                            .font(.title2.bold())
                            .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                        if let age = profile.age {
                            Text("\(age)")
                                .font(.title3)
                                .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                        }
                    }

                    // Cinsiyet + şehir — discover_users RPC'si bunları zaten
                    // dönüyordu ama kartta hiç gösterilmiyordu.
                    if profile.gender != nil || profile.city != nil {
                        HStack(spacing: LeafSpacing.xs) {
                            if let genderName = Gender(rawValue: profile.gender ?? "")?.displayName {
                                Text(genderName)
                            }
                            if let city = profile.city {
                                if profile.gender != nil {
                                    Text("·").foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                                }
                                Label(city, systemImage: "mappin.and.ellipse")
                                    .labelStyle(.titleAndIcon)
                            }
                            if profile.sameCity == true {
                                Text("Aynı Şehir")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, LeafSpacing.xs)
                                    .padding(.vertical, 2)
                                    .background(LeafColors.accent(for: colorScheme), in: Capsule())
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
                    }

                    if let bio = profile.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }

                if let books = profile.commonBookTitles, !books.isEmpty {
                    VStack(alignment: .leading, spacing: LeafSpacing.xs) {
                        ForEach(books.prefix(3), id: \.self) { title in
                            Label(title, systemImage: "book.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(LeafColors.accent(for: colorScheme))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(LeafSpacing.xl)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 340)
    }

    // MARK: - Avatar

    // Henüz sohbet yok (conversationId verilmiyor) — foto varsa bulanık önizleme
    // gösterilir, reveal ikonu çıkmaz (o sadece gerçek bir sohbette anlamlı).
    // Foto hiç yoksa RevealablePhotoView kendi silüet placeholder'ını gösterir.
    private var avatar: some View {
        RevealablePhotoView(userId: profile.id, size: 96)
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
