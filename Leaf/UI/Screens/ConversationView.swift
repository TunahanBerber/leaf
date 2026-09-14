import SwiftUI

// MARK: - ConversationView

struct ConversationView: View {
    let conversationId: String
    let otherUsername: String

    @Environment(SocialService.self) var socialService
    @EnvironmentObject var auth: SupabaseAuthService
    @EnvironmentObject var bookStore: BookStore
    @Environment(\.colorScheme) var colorScheme

    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showBlockConfirm  = false
    @State private var showReportSheet   = false
    @State private var showReportSuccess = false
    @State private var showShareBookPicker = false
    @State private var messageToReport: Message?   // context menüden mesaj bazlı şikayet
    @State private var filterWarning: String?
    // Mesajlar tamamen yüklenene kadar listeyi göstermiyoruz — aksi halde
    // ScrollView, socialService.messages henüz boş/bir önceki sohbetten kalma
    // haldeyken ilk layout'unu alıyor ve .defaultScrollAnchor(.bottom) yanlış
    // (o anki) içeriğe göre ankraj oluyor; mesajlar geldikten sonra listenin
    // gerçek altına otomatik kaymıyordu. Liste ancak dolu veriyle ilk kez
    // oluştuğunda anchor doğru çalışıyor.
    @State private var isLoadingMessages = true
    @State private var isLoadingOlderMessages = false

    private var currentUserId: String {
        auth.currentUser?.id.uuidString.lowercased() ?? ""
    }

    private var otherUserId: String? {
        guard let conv = socialService.conversations.first(where: { $0.id == conversationId }) else { return nil }
        return conv.userAId == currentUserId ? conv.userBId : conv.userAId
    }

    var body: some View {
        ZStack {
            LeafGradientBackground()

            Group {
                if isLoadingMessages {
                    ProgressView()
                        .tint(LeafColors.accent(for: colorScheme))
                } else {
                    messageListView
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                inputArea
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: LeafSpacing.xs) {
                    if let otherUserId {
                        RevealablePhotoView(userId: otherUserId, conversationId: conversationId, size: 32)
                    }
                    Text(otherUsername)
                        .font(.headline)
                        .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showBlockConfirm = true
                    } label: {
                        Label("Engelle", systemImage: "hand.raised.fill")
                    }
                    Button {
                        showReportSheet = true
                    } label: {
                        Label("Şikayet Et", systemImage: "flag.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                }
            }
        }
        .confirmationDialog(
            "\(otherUsername) adlı kullanıcıyı engellemek istediğine emin misin?",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Engelle", role: .destructive) {
                guard let uid = otherUserId else { return }
                Task { await socialService.blockUser(userId: uid) }
            }
            Button("İptal", role: .cancel) { }
        }
        .sheet(isPresented: $showShareBookPicker) {
            ShareBookPickerSheet(conversationId: conversationId)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheet(username: otherUsername) { reason, description in
                guard let uid = otherUserId else { return }
                Task {
                    let ok = await socialService.reportUser(userId: uid, reason: reason, description: description)
                    if ok { showReportSuccess = true }
                }
            }
        }
        .sheet(item: $messageToReport) { message in
            ReportSheet(username: otherUsername) { reason, description in
                Task {
                    let ok = await socialService.reportUser(
                        userId: message.senderId,
                        reason: reason,
                        messageId: message.id,
                        description: description
                    )
                    if ok { showReportSuccess = true }
                }
            }
        }
        .alert("Şikayet İletildi", isPresented: $showReportSuccess) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("Bildirimin alındı. En kısa sürede incelenecek.")
        }
        .alert("Mesaj Gönderilemedi", isPresented: Binding(get: { filterWarning != nil }, set: { if !$0 { filterWarning = nil } })) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(filterWarning ?? "")
        }
        .task(id: conversationId) {
            // Bu sohbeti daha önce açtıysak (messagesCache) spinner beklemeden
            // elimizdeki son veriyi hemen gösteriyoruz — WhatsApp'ta olduğu gibi
            // girip çıkışlar anında oluyor, fetchMessages arkada sessizce tazeliyor.
            // Hiç açmadıysak (cache yok) eskisi gibi spinner gösteriyoruz.
            if let cached = socialService.cachedMessages(for: conversationId) {
                socialService.messages = cached
                isLoadingMessages = false
            } else {
                isLoadingMessages = true
                socialService.messages = []
            }
            // Realtime aboneliği fetch'ten ÖNCE açılıyor: aksi halde fetch ile
            // subscribe arasındaki pencerede karşı tarafın attığı bir mesaj ne
            // ilk fetch'e yakalanır ne de henüz açılmamış kanaldan gelirdi — sohbete
            // girip manuel yenilemeden görünmezdi. subscribeToMessages'daki insert
            // handler'ı zaten "messages içinde bu id zaten var mı" kontrolü yapıyor
            // (SocialService.swift), o yüzden fetch ile realtime'ın aynı mesajı iki
            // kez getirmesi durumunda çakışma güvenle önleniyor.
            await socialService.subscribeToMessages(conversationId: conversationId)
            await socialService.fetchMessages(conversationId: conversationId)
            isLoadingMessages = false
            PushNotificationService.shared.clearBadge()
        }
        .onDisappear {
            Task {
                await socialService.unsubscribe()
                if let idx = socialService.conversations.firstIndex(where: { $0.id == conversationId }) {
                    // Sohbet zaten inbox listesinde — tüm listeyi (ve her
                    // sohbetin profilini/son mesajını) ağır bir şekilde yeniden
                    // çekmek yerine sadece bu sohbetin önizlemesini local'de
                    // güncelliyoruz. InboxView bu yüzden artık girip çıkışta
                    // spinner'a dönüp listeyi baştan çizmiyor.
                    socialService.conversations[idx].lastMessage = socialService.messages.last
                    await socialService.refreshUnreadCount()
                } else {
                    // Az önce kabul edilen bir istekten gelinmiş olabilir —
                    // sohbet henüz local listede yok, bu durumda tam yenileme
                    // gerekiyor (nadir, sadece ilk kez girilen sohbetlerde).
                    await socialService.fetchConversations()
                }
            }
        }
    }

    // MARK: - Mesaj Listesi

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    // Listenin başına yaklaşınca (bu satır görünür olunca) bir
                    // sayfa daha eski mesaj çekiyoruz. Geçmişin gerçek başına
                    // gelince (hasMoreMessages false) bu satır tamamen kalkıyor.
                    if socialService.hasMoreMessages(for: conversationId) {
                        ProgressView()
                            .padding(.vertical, LeafSpacing.sm)
                            .frame(maxWidth: .infinity)
                            .onAppear { loadOlderMessages(proxy: proxy) }
                    }
                    ForEach(socialService.messages) { message in
                        let isOwn = message.senderId == currentUserId
                        MessageBubble(
                            message: message,
                            isOwn: isOwn,
                            onDelete: { Task { await socialService.deleteMessage(message) } },
                            onReport: isOwn ? nil : { messageToReport = message }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, LeafSpacing.md)
                .padding(.vertical, LeafSpacing.md)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isTextFieldFocused = false
            }
            // Sadece gerçekten YENİ bir mesaj eklendiğinde (son mesajın id'si
            // değiştiğinde) en alta kayıyoruz. loadOlderMessages üste eski
            // mesaj eklediğinde son mesaj değişmediği için burası tetiklenmiyor
            // — yoksa yukarı kaydırıp eski mesajları okurken sürekli en alta
            // zıplardı.
            .onChange(of: socialService.messages.last?.id) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    // Yukarı kaydırınca eski mesajları getirir. Yeni içerik başa eklenince
    // ScrollView'ın görünümü kaymasın diye, o an en üstteki mesajı işaretleyip
    // veri geldikten sonra tekrar aynı mesaja (animasyonsuz) scroll ediyoruz —
    // aksi halde kullanıcı okurken ekran aniden aşağı "zıplardı".
    private func loadOlderMessages(proxy: ScrollViewProxy) {
        guard !isLoadingOlderMessages else { return }
        isLoadingOlderMessages = true
        let anchorId = socialService.messages.first?.id
        Task {
            await socialService.loadOlderMessages(conversationId: conversationId)
            isLoadingOlderMessages = false
            if let anchorId {
                proxy.scrollTo(anchorId, anchor: .top)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = socialService.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.4)

            inputBar
                .padding(.horizontal, LeafSpacing.sm)
                .padding(.vertical, LeafSpacing.xs)
                .padding(.bottom, 4)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: LeafSpacing.xs) {
            // WhatsApp'taki gibi solda + — kütüphanenden bir kitabı (güncel
            // sayfası ya da bir notuyla) doğrudan bu sohbete gönderiyor.
            Button {
                showShareBookPicker = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(LeafColors.accent(for: colorScheme))
            }
            .padding(.bottom, 2)

            TextField("Mesaj yaz...", text: $messageText, axis: .vertical)
                .lineLimit(1...5)
                .focused($isTextFieldFocused)
                .font(.body)
                .padding(.horizontal, LeafSpacing.sm)
                .padding(.vertical, LeafSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: LeafRadius.xlarge)
                        .fill(LeafColors.surfacePrimary(for: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: LeafRadius.xlarge)
                                .stroke(LeafColors.borderSubtle(for: colorScheme), lineWidth: 1)
                        )
                )

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        messageText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? LeafColors.textTertiary(for: colorScheme)
                            : LeafColors.accent(for: colorScheme)
                    )
                    .animation(LeafMotion.fast, value: messageText.isEmpty)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.bottom, 2)
        }
    }

    // MARK: - Gönder

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        guard ContentFilter.isAllowed(text) else {
            filterWarning = "Mesajın uygunsuz içerik barındırdığı için gönderilemedi."
            return
        }

        messageText = ""
        Task {
            await socialService.sendMessage(conversationId: conversationId, content: text)
        }
    }
}

// MARK: - Report Sheet

struct ReportSheet: View {
    let username: String
    let onSubmit: (_ reason: String, _ description: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedReason: String?
    @State private var description = ""
    @FocusState private var isDescriptionFocused: Bool

    private let reasons = [
        "Taciz",
        "Spam",
        "Uygunsuz İçerik",
        "Diğer"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                List {
                    Section {
                        ForEach(reasons, id: \.self) { reason in
                            Button {
                                selectedReason = reason
                            } label: {
                                HStack {
                                    Text(reason)
                                        .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                                    Spacer()
                                    if selectedReason == reason {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(LeafColors.accent(for: colorScheme))
                                    }
                                }
                            }
                            .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))
                        }
                    } header: {
                        Text("Sebep")
                    }

                    Section {
                        TextField("İsteğe bağlı, kısaca açıkla...", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                            .focused($isDescriptionFocused)
                            .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                            .listRowBackground(LeafColors.surfacePrimary(for: colorScheme))
                    } header: {
                        Text("Açıklama")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("\(username) Şikayet Et")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Gönder") {
                        guard let reason = selectedReason else { return }
                        onSubmit(reason, description.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(selectedReason == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isOwn: Bool
    let onDelete: () -> Void
    let onReport: (() -> Void)?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .bottom, spacing: LeafSpacing.xxs) {
            if isOwn { Spacer(minLength: 56) }

            VStack(alignment: isOwn ? .trailing : .leading, spacing: 3) {
                Group {
                    if message.messageType == "book_share", let sharedBook = message.sharedBook {
                        SharedBookCard(book: sharedBook, caption: message.content, isOwn: isOwn)
                    } else {
                        Text(message.content)
                            .font(.body)
                            .foregroundStyle(isOwn ? .white : LeafColors.textPrimary(for: colorScheme))
                            .padding(.horizontal, LeafSpacing.sm)
                            .padding(.vertical, 9)
                    }
                }
                .background(
                    isOwn
                        ? LeafColors.accent(for: colorScheme)
                        : LeafColors.surfacePrimary(for: colorScheme)
                )
                .clipShape(RoundedRectangle(cornerRadius: LeafRadius.large))
                .overlay {
                    if !isOwn {
                        RoundedRectangle(cornerRadius: LeafRadius.large)
                            .stroke(LeafColors.borderSubtle(for: colorScheme), lineWidth: 1)
                    }
                }
                .contextMenu {
                    if isOwn {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Mesajı Sil", systemImage: "trash")
                        }
                    } else if let onReport {
                        Button {
                            onReport()
                        } label: {
                            Label("Şikayet Et", systemImage: "flag")
                        }
                    }
                }

                Text(message.createdAt.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                    .padding(.horizontal, LeafSpacing.xxs)
            }

            if !isOwn { Spacer(minLength: 56) }
        }
    }
}

// MARK: - Sohbette Paylaşılan Kitap Kartı

struct SharedBookCard: View {
    let book: SharedBookPayload
    let caption: String
    let isOwn: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: LeafSpacing.xs) {
            HStack(spacing: LeafSpacing.sm) {
                CoverImageView(coverUrl: book.coverImageUrl, placeholderIconSize: 20)
                    .frame(width: 52, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: LeafRadius.small))

                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isOwn ? .white : LeafColors.textPrimary(for: colorScheme))
                        .lineLimit(2)
                    Text(book.author)
                        .font(.caption)
                        .foregroundStyle(isOwn ? .white.opacity(0.8) : LeafColors.textSecondary(for: colorScheme))
                        .lineLimit(1)

                    if book.totalPages > 0 {
                        HStack(spacing: LeafSpacing.xxs) {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 10))
                            Text("Sayfa \(book.currentPage) / \(book.totalPages) · %\(Int(book.progress * 100))")
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(isOwn ? .white.opacity(0.9) : LeafColors.accent(for: colorScheme))
                    }
                }
                Spacer(minLength: 0)
            }

            if let noteTitle = book.noteTitle, let noteContent = book.noteContent {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: LeafSpacing.xxs) {
                        Text(noteTitle)
                            .font(.caption.weight(.semibold))
                        if let notePage = book.notePageNumber, notePage > 0 {
                            Text("s. \(notePage)")
                                .font(.caption2.weight(.medium))
                                .opacity(0.8)
                        }
                    }
                    Text(noteContent)
                        .font(.caption2)
                        .lineLimit(4)
                }
                .foregroundStyle(isOwn ? .white.opacity(0.95) : LeafColors.textPrimary(for: colorScheme))
                .padding(.top, 2)
                .padding(.horizontal, LeafSpacing.xs)
                .padding(.vertical, LeafSpacing.xxs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: LeafRadius.small, style: .continuous)
                        .fill(isOwn ? .white.opacity(0.15) : LeafColors.accent(for: colorScheme).opacity(0.1))
                }
            }

            if !caption.isEmpty {
                Text(caption)
                    .font(.body)
                    .foregroundStyle(isOwn ? .white : LeafColors.textPrimary(for: colorScheme))
                    .padding(.top, 2)
            }
        }
        .padding(LeafSpacing.sm)
        .frame(width: 230, alignment: .leading)
    }
}

// MARK: - Sohbetten Kitap/Not Seçme Sheet'i (WhatsApp'taki + gibi)

// Sohbet zaten belli olduğu için (BookDetailView'daki ShareBookToChatSheet'in
// aksine) burada bir sohbet seçtirmiyoruz — sadece kitap, sonra istersen o
// kitabın notlarından biri. Seçilince anında gönderiyor; ek bir alt yazı
// istiyorsan zaten aynı sohbette normal mesaj olarak yazabilirsin.
struct ShareBookPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var bookStore: BookStore
    @Environment(SocialService.self) private var socialService
    let conversationId: String

    @State private var selectedBookId: String?
    @State private var isSending = false

    private var myBooks: [Book] {
        bookStore.books.filter { !$0.isWishlist }
    }

    // bookStore.books'tan canlı okuyoruz — fetchNotes tamamlanınca books[idx].notes
    // güncelleniyor, bir @State kopyası tutsaydık bu güncellemeyi kaçırırdık.
    private var selectedBook: Book? {
        guard let selectedBookId else { return nil }
        return bookStore.books.first { $0.id == selectedBookId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                if let selectedBook {
                    optionsList(for: selectedBook)
                } else if myBooks.isEmpty {
                    emptyState
                } else {
                    bookList
                }
            }
            .navigationTitle(selectedBook == nil ? "Kitap Seç" : "Ne Paylaşılsın?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(selectedBook == nil ? "İptal" : "Geri") {
                        if selectedBookId != nil {
                            withAnimation(LeafMotion.fast) { selectedBookId = nil }
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            // BookDetailView'ı hiç açmadan doğrudan sohbetten paylaşmaya
            // çalışıyor olabilirsin — o zaman kitabın notes'u BookStore'da
            // henüz hiç çekilmemiş (boş) olabilir. Kitap seçilince tazeliyoruz.
            .task(id: selectedBookId) {
                if let selectedBookId {
                    await bookStore.fetchNotes(for: selectedBookId)
                }
            }
            .disabled(isSending)
            .overlay {
                if isSending {
                    ProgressView().tint(LeafColors.accent(for: scheme))
                }
            }
        }
    }

    private var bookList: some View {
        List(myBooks) { book in
            Button {
                withAnimation(LeafMotion.fast) { selectedBookId = book.id }
            } label: {
                HStack(spacing: LeafSpacing.sm) {
                    CoverImageView(coverUrl: book.coverImageUrl, placeholderIconSize: 16)
                        .frame(width: 40, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: LeafRadius.small))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .foregroundStyle(LeafColors.textPrimary(for: scheme))
                            .lineLimit(1)
                        Text(book.author)
                            .font(.caption)
                            .foregroundStyle(LeafColors.textSecondary(for: scheme))
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func optionsList(for book: Book) -> some View {
        List {
            Section {
                Button {
                    Task { await send(book: book, note: nil) }
                } label: {
                    Label(
                        book.totalPages > 0
                            ? "Sadece ilerlemeyi paylaş (Sayfa \(book.currentPage) / \(book.totalPages))"
                            : "Kitabı paylaş",
                        systemImage: "bookmark.fill"
                    )
                }
            }

            if !book.notes.isEmpty {
                Section("Bir not ekle") {
                    ForEach(book.notes.sorted { $0.createdAt > $1.createdAt }) { note in
                        Button {
                            Task { await send(book: book, note: note) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(LeafColors.textPrimary(for: scheme))
                                Text(note.content)
                                    .font(.caption)
                                    .foregroundStyle(LeafColors.textSecondary(for: scheme))
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: LeafSpacing.md) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40))
                .foregroundStyle(LeafColors.textTertiary(for: scheme))
            Text("Kütüphanen boş")
                .font(.headline)
                .foregroundStyle(LeafColors.textPrimary(for: scheme))
            Text("Paylaşacak bir kitap için önce\nKitaplığım'a bir şey ekle.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(LeafColors.textSecondary(for: scheme))
        }
        .padding(LeafSpacing.xxl)
    }

    private func send(book: Book, note: BookNote?) async {
        isSending = true
        await socialService.sendBookShare(
            conversationId: conversationId,
            book: book,
            noteTitle: note?.title,
            noteContent: note?.content,
            notePageNumber: note?.pageNumber,
            caption: ""
        )
        isSending = false
        dismiss()
    }
}
