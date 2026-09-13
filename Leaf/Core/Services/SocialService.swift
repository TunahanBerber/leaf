// SocialService.swift
// Tüm sosyal işlemler buradan geçiyor — keşif, sohbet, mesajlaşma ve Realtime

import Foundation
import Observation
import Supabase
import UIKit

// Supabase'den gelen profil kaydı (id string olarak geliyor)
private struct ProfileRecord: Codable {
    var id: String
    var username: String
    var avatarUrl: String?
    var bio: String?
    var age: Int?
    var gender: String?
    var interestedIn: [String]?
    var city: String?
    var socialEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case id, username, bio, age, gender, city
        case avatarUrl = "avatar_url"
        case interestedIn = "interested_in"
        case socialEnabled = "social_enabled"
    }

    func toUserProfile() -> UserProfile {
        UserProfile(
            id: id,
            username: username,
            avatarUrl: avatarUrl,
            bio: bio,
            age: age,
            gender: gender,
            interestedIn: interestedIn,
            city: city,
            commonBookTitles: nil,
            sameCity: nil,
            socialEnabled: socialEnabled
        )
    }
}

// blocked_users tablosundan gelen ham kayıt
private struct BlockedUserRow: Codable {
    var blockerId: String
    var blockedId: String

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

// @Observable (Observation framework, iOS 17+) property-bazlı izleme sağlıyor —
// bir view sadece body'sinde gerçekten okuduğu property değişince re-render olur.
// Eskiden ObservableObject + @Published idi: o modelde TEK bir property değişince
// (mesela mesaj listesi) bu servisi @EnvironmentObject ile tutan HER view yeniden
// render oluyordu (Library/Discover/Inbox aynı anda TabView'de canlı kaldığı için),
// property'yi hiç okumasa bile. @Observable bunu ortadan kaldırıyor.
@MainActor
@Observable
final class SocialService {

    // MARK: - State

    var currentProfile: UserProfile?
    // Kendi profil fotoğrafımın durumu — Kitaplığım'daki avatar butonu gibi birden
    // fazla ekranın aynı anda güncel kalması gereken tek paylaşılan kaynağı bu.
    var myPhotoReveal: PhotoReveal?
    // Başkalarının fotoğraf durumu için paylaşılan önbellek — Discover kartları ve
    // Mesajlar listesi gibi yerlerde her avatarın kendi başına ayrı bir network
    // isteği atıp "önce avatar, sonra fotoğraf" gecikmesi yaratmasını önlüyor.
    // prefetchPhotoReveals(for:) ile toplu doldurulur, RevealablePhotoView önce
    // buradan okur.
    var photoRevealCache: [String: PhotoReveal] = [:]
    // photoRevealCache girdilerinin ne zaman yazıldığını tutuyoruz — Edge Function'ların
    // ürettiği signed URL'lerin ömrü 300sn. Bu pencerenin içindeyken aynı kullanıcı için
    // tekrar sorgu atmak (özellikle prefetchPhotoReveals'ta toplu olarak) tamamen gereksiz;
    // dışına çıktıysa signed URL'in süresi dolmuş olabileceğinden yenilemek gerekiyor.
    private var photoRevealCachedAt: [String: Date] = [:]
    private let photoRevealFreshWindow: TimeInterval = 270
    var discoveredUsers: [UserProfile] = []
    var conversations: [Conversation] = []
    var pendingRequests: [ConversationRequest] = []  // gelen bekleyen istekler
    var sentRequests: [ConversationRequest] = []     // benim gönderdiğim, henüz yanıtlanmamış istekler
    var messages: [Message] = []
    var blockedUsers: [UserProfile] = []
    var isLoading = false
    var error: String?
    var unreadCount: Int = 0

    // profil henüz yüklenmedi mi (nil) vs yüklendi ama yok (currentProfile == nil)
    var profileLoaded = false

    // 18 yaş altı sosyal özelliklere erişemez
    var isSocialAllowed: Bool {
        guard let age = currentProfile?.age else { return false }
        return age >= 18
    }

    private var realtimeChannel: RealtimeChannelV2?
    private var inboxChannel: RealtimeChannelV2?

    // MARK: - Profil Yükleme

    func loadCurrentProfile() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else {
            profileLoaded = true
            return
        }

        do {
            let records: [ProfileRecord] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value

            currentProfile = records.first?.toUserProfile()
            Task { await loadMyPhoto() }
        } catch {
            currentProfile = nil
        }

        profileLoaded = true
    }

    // MARK: - Profil Oluşturma

    // gender/interestedIn/city sadece 18 yaş üzeri onboarding adımında gönderiliyor —
    // reşit olmayanlardan eşleşme amaçlı veri toplamıyoruz. photoData verilirse
    // profil oluştuktan sonra process-profile-photo Edge Function'ına yükleniyor.
    func createProfile(
        username: String,
        bio: String,
        age: Int,
        gender: Gender? = nil,
        interestedIn: [Gender]? = nil,
        city: String? = nil,
        photoData: Data? = nil
    ) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return false }
        isLoading = true
        defer { isLoading = false }

        var entry: [String: AnyJSON] = [
            "id":       .string(userId),
            "username": .string(username),
            "age":      .double(Double(age))
        ]
        if !bio.isEmpty { entry["bio"] = .string(bio) }
        if let gender { entry["gender"] = .string(gender.rawValue) }
        if let interestedIn, !interestedIn.isEmpty {
            entry["interested_in"] = .array(interestedIn.map { .string($0.rawValue) })
        }
        if let city { entry["city"] = .string(city) }

        do {
            let saved: ProfileRecord = try await supabase
                .from("profiles")
                .insert(entry)
                .select()
                .single()
                .execute()
                .value

            currentProfile = saved.toUserProfile()

            if let photoData {
                _ = await uploadProfilePhoto(photoData)
            }
            return true
        } catch {
            self.error = "Profil oluşturulamadı. Kullanıcı adı zaten alınmış olabilir."
            return false
        }
    }

    // MARK: - Profil Güncelleme

    func updateProfile(username: String, bio: String) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return false }
        isLoading = true
        defer { isLoading = false }

        var entry: [String: AnyJSON] = ["username": .string(username)]
        if !bio.isEmpty { entry["bio"] = .string(bio) }

        do {
            let updated: ProfileRecord = try await supabase
                .from("profiles")
                .update(entry)
                .eq("id", value: userId)
                .select()
                .single()
                .execute()
                .value

            currentProfile = updated.toUserProfile()
            return true
        } catch {
            self.error = "Profil güncellenemedi."
            return false
        }
    }

    // Ayarlar'dan şehir değişikliği — diğer alanlardan bağımsız, hemen kaydediliyor
    // (socialEnabled ile aynı optimistic-update deseni).
    @discardableResult
    func updateCity(_ city: String) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return false }

        let previous = currentProfile?.city
        currentProfile?.city = city

        do {
            try await supabase
                .from("profiles")
                .update(["city": AnyJSON.string(city)])
                .eq("id", value: userId)
                .execute()
            return true
        } catch {
            currentProfile?.city = previous
            self.error = "Şehir güncellenemedi."
            return false
        }
    }

    // MARK: - Profil Fotoğrafı

    // Ham JPEG baytları process-profile-photo Edge Function'ına gönderilir; orijinal +
    // gerçekten bulanıklaştırılmış kopya orada (sunucu tarafında) üretilir.
    @discardableResult
    func uploadProfilePhoto(_ data: Data) async -> Bool {
        struct UploadResult: Codable {
            var ok: Bool
            var url: String?
        }
        // PhotosPicker ham galeri fotoğrafını (genelde 10+ MP) olduğu gibi verir —
        // bunu küçültmeden göndermek hem yükleme hem de Edge Function'ın JPEG decode
        // adımını çok yavaşlatıyordu. BookStore.resizedAndCompressed ile aynı yaklaşım.
        let payload = Self.resizedAndCompressed(data)
        do {
            let result: UploadResult = try await supabase.functions.invoke(
                "process-profile-photo",
                options: FunctionInvokeOptions(body: payload)
            )
            // Edge Function kendi fotoğrafımın signed URL'ini doğrudan döndürüyor —
            // ayrıca get-profile-photo'yu çağırıp bir tur daha network beklemeye
            // gerek yok, bu da yükleme sonrası görselin geç görünme hissini yaratıyordu.
            if let urlString = result.url, let url = URL(string: urlString) {
                myPhotoReveal = PhotoReveal(stage: .revealed, url: url)
            }
            // RevealablePhotoView'ın görsel önbelleğini de hemen taze byte'larla
            // besliyoruz — elimizdeki payload zaten sunucuya gönderdiğimizin aynısı
            // (orijinal, sunucu sadece kaydediyor, değiştirmiyor). Böylece Kitaplığım/
            // Ayarlar'daki avatar bu yeni fotoğrafı göstermek için imzalı URL'i tekrar
            // indirmek zorunda kalmıyor, path aynı kaldığı için eski byte'ların üzerine
            // hemen doğru olanı yazmış oluyoruz.
            if let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() {
                ProfilePhotoCacheStore.shared.set("\(userId)/original.jpg", data: payload)
            }
            return true
        } catch {
            print("[SocialService] uploadProfilePhoto error: \(error)")
            self.error = "Fotoğraf yüklenemedi."
            return false
        }
    }

    // Kendi fotoğrafımın durumunu çekip myPhotoReveal'a yazar — Kitaplığım'daki
    // avatar butonu ve Ayarlar'daki avatar gibi birden fazla ekran bunu okur.
    func loadMyPhoto() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }
        myPhotoReveal = await fetchProfilePhoto(targetUserId: userId)
    }

    // Discover kartları / Mesajlar listesi gibi bir seferde birden çok kullanıcının
    // fotoğrafı gösterileceği yerlerde, listenin kendisi yüklenir yüklenmez tek bir
    // toplu istekle hepsinin durumunu çekip önbelleğe yazar. get-profile-photos
    // Edge Function'ı tek bir SQL RPC'siyle stage'leri, tek bir Storage batch
    // çağrısıyla da signed URL'leri hesaplıyor — N ayrı istek yerine 1 istek.
    func prefetchPhotoReveals(for userIds: [String]) async {
        // Zaten taze bir kaydı olan id'leri tekrar sorgulamıyoruz — yoksa her
        // discoverUsers()/fetchConversations() çağrısı, TTL içinde olsalar bile
        // TÜM listenin fotoğraf durumunu yeniden çekiyordu (ör. bir sohbetten
        // çıkınca tetiklenen fetchConversations() gibi).
        let ids = Array(Set(userIds)).filter { !$0.isEmpty && !isPhotoRevealFresh(for: $0) }
        guard !ids.isEmpty else { return }

        struct BatchResponse: Codable {
            var results: [String: PhotoReveal]
        }
        do {
            let response: BatchResponse = try await supabase.functions.invoke(
                "get-profile-photos",
                options: FunctionInvokeOptions(body: ["target_user_ids": ids])
            )
            for (userId, reveal) in response.results {
                cachePhotoReveal(reveal, for: userId)
            }
        } catch {
            print("[SocialService] prefetchPhotoReveals error: \(error)")
        }
    }

    // photoRevealCache/photoRevealCachedAt'e her yazan yer (prefetch, tekil fetch)
    // buradan geçmeli — ikisini birlikte güncel tutmanın tek yolu bu.
    func cachePhotoReveal(_ reveal: PhotoReveal, for userId: String) {
        photoRevealCache[userId] = reveal
        photoRevealCachedAt[userId] = Date()
    }

    func isPhotoRevealFresh(for userId: String) -> Bool {
        guard photoRevealCache[userId] != nil, let cachedAt = photoRevealCachedAt[userId] else { return false }
        return Date().timeIntervalSince(cachedAt) < photoRevealFreshWindow
    }

    private static func resizedAndCompressed(_ data: Data, maxDimension: CGFloat = 800) -> Data {
        guard let image = UIImage(data: data) else { return data }

        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else {
            return image.jpegData(compressionQuality: 0.85) ?? data
        }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.85) ?? data
    }

    // Hangi varyantın (hiç/blur/orijinal) gösterileceğine sunucu karar veriyor —
    // get-profile-photo Edge Function'ı gerçek eşleşme/onay durumuna bakıyor,
    // client sadece dönen signed URL'i gösteriyor. Kendi fotoğrafın için her
    // zaman "revealed" döner.
    func fetchProfilePhoto(targetUserId: String) async -> PhotoReveal {
        do {
            let response: PhotoReveal = try await supabase.functions.invoke(
                "get-profile-photo",
                options: FunctionInvokeOptions(body: ["target_user_id": targetUserId])
            )
            return response
        } catch {
            print("[SocialService] fetchProfilePhoto error: \(error)")
            return PhotoReveal(stage: .hidden, url: nil)
        }
    }

    // Çağıranın kendi tarafındaki onay bayrağını çevirir; her iki taraf da onaylayınca
    // get-profile-photo orijinali göstermeye başlar. Sadece eşleşme (conversation)
    // bağlamında kullanılıyor — kendi profil fotoğrafın için gerekmiyor.
    func confirmPhotoReveal(conversationId: String) async -> (userAConfirmed: Bool, userBConfirmed: Bool)? {
        struct ConfirmResult: Codable {
            var userAPhotoConfirmed: Bool
            var userBPhotoConfirmed: Bool
            enum CodingKeys: String, CodingKey {
                case userAPhotoConfirmed = "user_a_photo_confirmed"
                case userBPhotoConfirmed = "user_b_photo_confirmed"
            }
        }
        do {
            let result: ConfirmResult = try await supabase
                .rpc("confirm_photo_reveal", params: ["p_conversation_id": AnyJSON.string(conversationId)])
                .single()
                .execute()
                .value
            return (result.userAPhotoConfirmed, result.userBPhotoConfirmed)
        } catch {
            print("[SocialService] confirmPhotoReveal error: \(error)")
            return nil
        }
    }

    // Keşfet/Mesajlar sekmelerini gösterme tercihi — hesaba yazılıyor ki
    // aynı hesap başka bir cihazda açıldığında da aynı durumda görünsün
    @discardableResult
    func updateSocialEnabled(_ enabled: Bool) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return false }

        // optimistic update — UI hemen tepki versin
        currentProfile?.socialEnabled = enabled

        do {
            try await supabase
                .from("profiles")
                .update(["social_enabled": AnyJSON.bool(enabled)])
                .eq("id", value: userId)
                .execute()
            return true
        } catch {
            // geri al
            currentProfile?.socialEnabled = !enabled
            self.error = "Ayar kaydedilemedi."
            return false
        }
    }

    // MARK: - Keşif

    func discoverUsers() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let users: [UserProfile] = try await supabase
                .rpc("discover_users")
                .execute()
                .value

            // birbirini engellemiş kullanıcılar keşifte görünmesin
            var filtered = users
            if let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() {
                let blocked = await blockedPairIds(currentId: userId)
                filtered = users.filter { !blocked.contains($0.id) }
            }

            // Fotoğraf durumlarını liste ekrana yansımadan ÖNCE önbelleğe alıyoruz —
            // yoksa kartlar önce boş avatarla render olup fotoğraf sonradan "patlıyor".
            await prefetchPhotoReveals(for: filtered.map(\.id))
            discoveredUsers = filtered
        } catch {
            self.error = "Kullanıcılar yüklenemedi."
            print("[SocialService] discoverUsers error: \(error)")
        }
    }

    // MARK: - Conversation Request

    // karşı tarafa sohbet isteği gönder
    func sendConversationRequest(to receiverId: String) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return false }

        // Zaten aktif bir istek veya sohbet varsa tekrar gönderme
        let existing: [ConversationRequest]? = try? await supabase
            .from("conversation_requests")
            .select()
            .eq("sender_id", value: userId)
            .eq("receiver_id", value: receiverId)
            .limit(1)
            .execute()
            .value

        if existing?.isEmpty == false { return false }

        let entry: [String: AnyJSON] = [
            "sender_id":   .string(userId),
            "receiver_id": .string(receiverId),
            "status":      .string("pending")
        ]

        do {
            try await supabase
                .from("conversation_requests")
                .insert(entry)
                .execute()
            return true
        } catch {
            print("[SocialService] sendConversationRequest error: \(error)")
            self.error = "İstek gönderilemedi."
            return false
        }
    }

    // gelen istekleri yükle (gönderen profilleriyle birlikte)
    func fetchPendingRequests() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        do {
            var requests: [ConversationRequest] = try await supabase
                .from("conversation_requests")
                .select()
                .eq("receiver_id", value: userId)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
                .value

            // Gönderen profilerini tek sorguda çek
            let senderIds = requests.map(\.senderId)
            if !senderIds.isEmpty {
                let profiles: [ProfileRecord] = (try? await supabase
                    .from("profiles")
                    .select()
                    .in("id", values: senderIds)
                    .execute()
                    .value) ?? []

                let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.toUserProfile()) })
                for i in requests.indices {
                    requests[i].senderProfile = profileMap[requests[i].senderId]
                }
            }

            await prefetchPhotoReveals(for: senderIds)
            pendingRequests = requests
        } catch {
            self.error = "İstekler yüklenemedi."
        }
    }

    // isteği kabul et → sohbet oluştur → isteği sil
    func acceptRequest(_ request: ConversationRequest) async -> String? {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return nil }

        // conversation oluştur
        let entry: [String: AnyJSON] = [
            "user_a_id": .string(request.senderId),
            "user_b_id": .string(userId)
        ]

        do {
            let conv: Conversation = try await supabase
                .from("conversations")
                .insert(entry)
                .select()
                .single()
                .execute()
                .value

            // isteği sil
            try? await supabase
                .from("conversation_requests")
                .delete()
                .eq("id", value: request.id)
                .execute()

            pendingRequests.removeAll { $0.id == request.id }
            return conv.id
        } catch {
            self.error = "İstek kabul edilemedi."
            return nil
        }
    }

    // isteği reddet → sil
    func rejectRequest(_ request: ConversationRequest) async {
        do {
            try await supabase
                .from("conversation_requests")
                .delete()
                .eq("id", value: request.id)
                .execute()

            pendingRequests.removeAll { $0.id == request.id }
            sentRequests.removeAll { $0.id == request.id }
        } catch {
            self.error = "İstek reddedilemedi."
        }
    }

    // benim gönderdiğim, karşı taraftan henüz yanıt gelmemiş istekler (Keşfet'te "İlgileniyorum" dediklerim)
    func fetchSentRequests() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        do {
            var requests: [ConversationRequest] = try await supabase
                .from("conversation_requests")
                .select()
                .eq("sender_id", value: userId)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
                .value

            // alıcı profillerini tek sorguda çek
            let receiverIds = requests.map(\.receiverId)
            if !receiverIds.isEmpty {
                let profiles: [ProfileRecord] = (try? await supabase
                    .from("profiles")
                    .select()
                    .in("id", values: receiverIds)
                    .execute()
                    .value) ?? []

                let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.toUserProfile()) })
                for i in requests.indices {
                    requests[i].receiverProfile = profileMap[requests[i].receiverId]
                }
            }

            await prefetchPhotoReveals(for: receiverIds)
            sentRequests = requests
        } catch {
            self.error = "Gönderilen istekler yüklenemedi."
        }
    }

    // bu kullanıcıya zaten istek gönderilmiş mi?
    func checkRequestStatus(to receiverId: String) async -> String? {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return nil }

        let result: [ConversationRequest]? = try? await supabase
            .from("conversation_requests")
            .select()
            .eq("sender_id", value: userId)
            .eq("receiver_id", value: receiverId)
            .limit(1)
            .execute()
            .value

        return result?.first?.status
    }

    // MARK: - Conversation

    func fetchConversations() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var convs: [Conversation] = try await supabase
                .from("conversations")
                .select()
                .or("user_a_id.eq.\(userId),user_b_id.eq.\(userId)")
                .order("created_at", ascending: false)
                .execute()
                .value

            // birbirini engellemiş kullanıcıların sohbeti listede görünmesin
            let blocked = await blockedPairIds(currentId: userId)
            convs.removeAll { conv in
                let otherId = conv.userAId == userId ? conv.userBId : conv.userAId
                return blocked.contains(otherId)
            }

            // diğer kullanıcıların ID'lerini topla
            let otherIds = convs.map { conv -> String in
                conv.userAId == userId ? conv.userBId : conv.userAId
            }

            // profilleri tek sorguda çek
            if !otherIds.isEmpty {
                let profiles: [ProfileRecord] = (try? await supabase
                    .from("profiles")
                    .select()
                    .in("id", values: otherIds)
                    .execute()
                    .value) ?? []

                let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.toUserProfile()) })

                for i in convs.indices {
                    let otherId = convs[i].userAId == userId ? convs[i].userBId : convs[i].userAId
                    convs[i].otherUser = profileMap[otherId]
                }
            }

            // Her sohbetin son mesajını çek
            let convIds = convs.map(\.id)
            if !convIds.isEmpty {
                let allMessages: [Message] = (try? await supabase
                    .from("messages")
                    .select()
                    .in("conversation_id", values: convIds)
                    .order("created_at", ascending: false)
                    .execute()
                    .value) ?? []

                var lastMessageMap: [String: Message] = [:]
                for msg in allMessages where lastMessageMap[msg.conversationId] == nil {
                    lastMessageMap[msg.conversationId] = msg
                }
                for i in convs.indices {
                    convs[i].lastMessage = lastMessageMap[convs[i].id]
                }
            }

            // Liste ekrana yansımadan ÖNCE fotoğrafları önbelleğe alıyoruz — yoksa
            // satırlar önce boş avatarla render olup fotoğraf sonradan "patlıyor".
            await prefetchPhotoReveals(for: otherIds)
            conversations = convs
            await refreshUnreadCount()
        } catch {
            self.error = "Sohbetler yüklenemedi."
        }
    }

    func refreshUnreadCount() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }
        let convIds = conversations.map(\.id)
        guard !convIds.isEmpty else {
            unreadCount = 0
            return
        }
        let response = try? await supabase
            .from("messages")
            .select("*", head: true, count: .exact)
            .in("conversation_id", values: convIds)
            .eq("is_read", value: false)
            .neq("sender_id", value: userId)
            .execute()
        unreadCount = response?.count ?? 0
    }

    // sadece mevcut sohbeti döner, yoksa nil — yeni sohbet OLUŞTURMAZ
    func fetchExistingConversationId(with otherUserId: String) async -> String? {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return nil }

        let existing: [Conversation]? = try? await supabase
            .from("conversations")
            .select()
            .or("and(user_a_id.eq.\(userId),user_b_id.eq.\(otherUserId)),and(user_a_id.eq.\(otherUserId),user_b_id.eq.\(userId))")
            .limit(1)
            .execute()
            .value

        return existing?.first?.id
    }

    // iki kullanıcı arasında sohbet başlatır, varsa mevcut olanı döner
    func startConversation(with otherUserId: String) async -> String? {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return nil }

        let existing: [Conversation]? = try? await supabase
            .from("conversations")
            .select()
            .or("and(user_a_id.eq.\(userId),user_b_id.eq.\(otherUserId)),and(user_a_id.eq.\(otherUserId),user_b_id.eq.\(userId))")
            .limit(1)
            .execute()
            .value

        if let conv = existing?.first { return conv.id }

        let entry: [String: AnyJSON] = [
            "user_a_id": .string(userId),
            "user_b_id": .string(otherUserId)
        ]

        let created: Conversation? = try? await supabase
            .from("conversations")
            .insert(entry)
            .select()
            .single()
            .execute()
            .value

        return created?.id
    }

    // MARK: - Mesajlar

    func fetchMessages(conversationId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let msgs: [Message] = try await supabase
                .from("messages")
                .select()
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: true)
                .execute()
                .value

            messages = msgs
            await markAsRead(conversationId: conversationId)
            await refreshUnreadCount()
        } catch {
            self.error = "Mesajlar yüklenemedi."
        }
    }

    func sendMessage(conversationId: String, content: String) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        let entry: [String: AnyJSON] = [
            "conversation_id": .string(conversationId),
            "sender_id":       .string(userId),
            "content":         .string(content)
        ]

        do {
            let sent: Message = try await supabase
                .from("messages")
                .insert(entry)
                .select()
                .single()
                .execute()
                .value

            messages.append(sent)
        } catch {
            self.error = "Mesaj gönderilemedi."
        }
    }

    func deleteConversation(_ conversation: Conversation) async {
        do {
            try await supabase
                .from("conversations")
                .delete()
                .eq("id", value: conversation.id)
                .execute()

            conversations.removeAll { $0.id == conversation.id }
        } catch {
            self.error = "Sohbet silinemedi."
        }
    }

    func deleteMessage(_ message: Message) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased(),
              message.senderId == userId else { return }

        do {
            try await supabase
                .from("messages")
                .delete()
                .eq("id", value: message.id)
                .execute()

            messages.removeAll { $0.id == message.id }
        } catch {
            self.error = "Mesaj silinemedi."
        }
    }

    private func markAsRead(conversationId: String) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        try? await supabase
            .from("messages")
            .update(["is_read": AnyJSON.bool(true)])
            .eq("conversation_id", value: conversationId)
            .neq("sender_id", value: userId)
            .eq("is_read", value: false)
            .execute()
    }

    // MARK: - Realtime

    func subscribeToMessages(conversationId: String) async {
        await unsubscribe()

        let channel = supabase.channel("messages:\(conversationId)")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(conversationId)"
        )

        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(conversationId)"
        )

        await channel.subscribe()
        realtimeChannel = channel

        Task { [weak self] in
            for await insertion in insertions {
                guard let self else { break }
                let record = insertion.record

                guard
                    let id           = record["id"]?.stringValue,
                    let convId       = record["conversation_id"]?.stringValue,
                    let senderId     = record["sender_id"]?.stringValue,
                    let content      = record["content"]?.stringValue,
                    let createdAtStr = record["created_at"]?.stringValue
                else { continue }

                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let createdAt = formatter.date(from: createdAtStr) ?? Date()

                let msg = Message(
                    id: id,
                    conversationId: convId,
                    senderId: senderId,
                    content: content,
                    isRead: false,
                    createdAt: createdAt
                )

                await MainActor.run {
                    guard !(self.messages.contains { $0.id == msg.id }) else { return }
                    self.messages.append(msg)
                }
            }
        }

        Task { [weak self] in
            for await deletion in deletions {
                guard let self else { break }
                guard let id = deletion.oldRecord["id"]?.stringValue else { continue }
                await MainActor.run {
                    self.messages.removeAll { $0.id == id }
                }
            }
        }
    }

    func unsubscribe() async {
        if let channel = realtimeChannel {
            await supabase.removeChannel(channel)
            realtimeChannel = nil
        }
    }

    // MARK: - Inbox Realtime

    func subscribeToInbox() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        await unsubscribeFromInbox()

        let channel = supabase.channel("inbox:\(userId)")

        let newRequests = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "conversation_requests",
            filter: "receiver_id=eq.\(userId)"
        )

        let deletedRequests = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "conversation_requests"
        )

        let newConversations = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "conversations"
        )

        let newMessages = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages"
        )

        await channel.subscribe()
        inboxChannel = channel

        Task { [weak self] in
            for await _ in newRequests {
                guard let self else { break }
                await self.fetchPendingRequests()
            }
        }

        Task { [weak self] in
            for await _ in deletedRequests {
                guard let self else { break }
                await self.fetchPendingRequests()
                await self.fetchSentRequests()
            }
        }

        Task { [weak self] in
            for await _ in newConversations {
                guard let self else { break }
                await self.fetchConversations()
            }
        }

        Task { [weak self] in
            for await insertion in newMessages {
                guard let self else { break }
                let record = insertion.record

                guard
                    let id           = record["id"]?.stringValue,
                    let convId       = record["conversation_id"]?.stringValue,
                    let senderId     = record["sender_id"]?.stringValue,
                    let content      = record["content"]?.stringValue,
                    let createdAtStr = record["created_at"]?.stringValue
                else { continue }

                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let createdAt = formatter.date(from: createdAtStr) ?? Date()

                let msg = Message(
                    id: id,
                    conversationId: convId,
                    senderId: senderId,
                    content: content,
                    isRead: false,
                    createdAt: createdAt
                )

                await MainActor.run {
                    if let idx = self.conversations.firstIndex(where: { $0.id == convId }) {
                        self.conversations[idx].lastMessage = msg
                    }
                }
            }
        }
    }

    // MARK: - Engelleme & Şikayet
    //
    // blocked_users ve user_reports tabloları Supabase'de gerçekten var (RLS ile birlikte).
    // messages/conversations/conversation_requests RLS policy'leri de blok kontrolü yapıyor,
    // yani engelleme sadece UI'da değil DB seviyesinde de uygulanıyor.

    // iki yönde de (ben onu ya da o beni engellemiş) blocklu kullanıcı id'lerini döner
    private func blockedPairIds(currentId: String) async -> Set<String> {
        let rows: [BlockedUserRow] = (try? await supabase
            .from("blocked_users")
            .select()
            .or("blocker_id.eq.\(currentId),blocked_id.eq.\(currentId)")
            .execute()
            .value) ?? []

        return Set(rows.map { $0.blockerId == currentId ? $0.blockedId : $0.blockerId })
    }

    func blockUser(userId: String) async -> Bool {
        guard let currentId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return false }

        let entry: [String: AnyJSON] = [
            "blocker_id": .string(currentId),
            "blocked_id": .string(userId)
        ]

        do {
            try await supabase
                .from("blocked_users")
                .insert(entry)
                .execute()

            // engellenen kullanıcıyla olan sohbet artık listede görünmesin
            conversations.removeAll { $0.userAId == userId || $0.userBId == userId }
            return true
        } catch {
            self.error = "Kullanıcı engellenemedi."
            return false
        }
    }

    // ayarlar ekranındaki "Engellenen Kullanıcılar" listesi için
    func fetchBlockedUsers() async {
        guard let currentId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return }

        do {
            let rows: [BlockedUserRow] = try await supabase
                .from("blocked_users")
                .select()
                .eq("blocker_id", value: currentId)
                .execute()
                .value

            let ids = rows.map(\.blockedId)
            guard !ids.isEmpty else {
                blockedUsers = []
                return
            }

            let profiles: [ProfileRecord] = try await supabase
                .from("profiles")
                .select()
                .in("id", values: ids)
                .execute()
                .value

            blockedUsers = profiles.map { $0.toUserProfile() }
        } catch {
            self.error = "Engellenen kullanıcılar yüklenemedi."
        }
    }

    func unblockUser(userId: String) async -> Bool {
        guard let currentId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return false }

        do {
            try await supabase
                .from("blocked_users")
                .delete()
                .eq("blocker_id", value: currentId)
                .eq("blocked_id", value: userId)
                .execute()

            blockedUsers.removeAll { $0.id == userId }
            return true
        } catch {
            self.error = "Engel kaldırılamadı."
            return false
        }
    }

    // messageId verilirse belirli bir mesaj, verilmezse kullanıcının kendisi şikayet edilir
    func reportUser(userId: String, reason: String, messageId: String? = nil, description: String? = nil) async -> Bool {
        guard let currentId = try? await supabase.auth.session.user.id.uuidString.lowercased() else { return false }

        var entry: [String: AnyJSON] = [
            "reporter_id": .string(currentId),
            "reported_id": .string(userId),
            "reason":      .string(reason)
        ]
        if let messageId { entry["message_id"] = .string(messageId) }
        if let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entry["description"] = .string(description)
        }

        do {
            try await supabase
                .from("user_reports")
                .insert(entry)
                .execute()
            return true
        } catch {
            self.error = "Şikayet gönderilemedi."
            return false
        }
    }

    func unsubscribeFromInbox() async {
        if let channel = inboxChannel {
            await supabase.removeChannel(channel)
            inboxChannel = nil
        }
    }
}
