import SwiftUI

// kitap detay ekranı — kapak, bilgi, okuma ilerlemesi ve notlar bir arada
// SwiftData yok, her şey BookStore → Supabase üzerinden geçiyor

struct BookDetailView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BookStore
    @Environment(SocialService.self) private var socialService

    // kitabın güncel halini store'dan okuyorum — local state tutmuyorum
    let bookId: String

    @State private var showAddNote = false
    @State private var showEditBook = false
    @State private var showDeleteConfirmation = false
    @State private var showEditPage = false
    @State private var showShareToChat = false

    // store'dan güncel kitabı bul
    private var book: Book? {
        store.books.first { $0.id == bookId }
    }

    init(book: Book) {
        self.bookId = book.id
    }

    var body: some View {
        ZStack {
            LeafGradientBackground()
            if let book {
                content(book: book)
            } else {
                // kitap silindiyse store'dan düşer, bu ekran kendiliğinden kapanır
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(book?.title ?? "")
        .task {
            // ekran açılınca notları Supabase'den çekiyorum
            if let book { await store.fetchNotes(for: book.id) }
        }
        .sheet(isPresented: $showAddNote) {
            if let book { AddNoteView(bookId: book.id) }
        }
        .sheet(isPresented: $showEditBook) {
            if let book { AddBookView(bookToEdit: book, isWishlist: book.isWishlist) }
        }
        .confirmationDialog("Silmek istediğine emin misin?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Evet, Kitabı Sil", role: .destructive) {
                if let book {
                    dismiss()
                    Task { await store.deleteBook(book) }
                }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Son kararın mı? Bu kitap ve içindeki tüm notlar kalıcı olarak uçup gidecek.")
        }
    }

    @ViewBuilder
    private func content(book: Book) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                headerImage(book: book).padding(.bottom, LeafSpacing.lg)
                infoCard(book: book).padding(.horizontal, LeafSpacing.md).padding(.bottom, LeafSpacing.lg)
                progressCard(book: book).padding(.horizontal, LeafSpacing.md).padding(.bottom, LeafSpacing.lg)
                notesSection(book: book).padding(.horizontal, LeafSpacing.md).padding(.bottom, LeafSpacing.xxxl)
            }
        }
        .scrollIndicators(.hidden)
        .toolbar {
            // Mesajlaşma zaten 18 yaş altına kapalı — sohbeti olmayan/erişemeyen
            // birine "sohbete paylaş" butonu göstermenin bir anlamı yok.
            if socialService.isSocialAllowed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showShareToChat = true } label: {
                        Image(systemName: "paperplane")
                            .foregroundStyle(LeafColors.accent(for: scheme))
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddNote = true } label: {
                    Image(systemName: "note.text.badge.plus")
                        .foregroundStyle(LeafColors.accent(for: scheme))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEditBook = true } label: {
                        Label("Düzenle", systemImage: "pencil")
                    }
                    Button(role: .destructive) { showDeleteConfirmation = true } label: {
                        Label("Sil", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(LeafColors.accent(for: scheme))
                }
            }
        }
        .sheet(isPresented: $showEditPage) {
            PageProgressSheet(book: book) { newPage in
                var updated = book
                updated.currentPage = min(newPage, book.totalPages)
                Task { await store.updateBook(updated) }
            }
        }
        .sheet(isPresented: $showShareToChat) {
            ShareBookToChatSheet(book: book)
        }
    }

    // MARK: - Kapak Başlık
    @ViewBuilder
    private func headerImage(book: Book) -> some View {
        CoverImageView(coverUrl: book.coverImageUrl, placeholderIconSize: 48)
            .frame(height: book.coverImageUrl != nil ? 280 : 200)
            .clipShape(UnevenRoundedRectangle(
                bottomLeadingRadius: LeafRadius.xlarge,
                bottomTrailingRadius: LeafRadius.xlarge
            ))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
    }

    // MARK: - Bilgi Kartı
    private func infoCard(book: Book) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: LeafSpacing.sm) {
                Text(book.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(LeafColors.textPrimary(for: scheme))
                Text(book.author)
                    .font(.system(size: 15))
                    .foregroundStyle(LeafColors.textSecondary(for: scheme))
                if book.totalPages > 0 {
                    Text("\(book.totalPages) sayfa")
                        .font(.system(size: 13))
                        .foregroundStyle(LeafColors.textTertiary(for: scheme))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LeafSpacing.md)
        }
    }

    // MARK: - İlerleme Kartı
    private func progressCard(book: Book) -> some View {
        GlassCard {
            VStack(spacing: LeafSpacing.sm) {
                HStack {
                    Text("Okuma İlerlemesi")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LeafColors.textPrimary(for: scheme))
                    Spacer()
                    Text(book.totalPages > 0 ? "%\(Int(book.progress * 100))" : "—")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LeafColors.accent(for: scheme))
                }

                if book.totalPages > 0 {
                    ProgressView(value: book.progress)
                        .tint(LeafColors.accent(for: scheme))

                    Button {
                        showEditPage = true
                    } label: {
                        HStack(spacing: LeafSpacing.xs) {
                            Image(systemName: "bookmark").font(.system(size: 14))
                            Text("Sayfa \(book.currentPage) / \(book.totalPages)")
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(LeafColors.accent(for: scheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LeafSpacing.xs)
                        .background {
                            RoundedRectangle(cornerRadius: LeafRadius.small, style: .continuous)
                                .fill(LeafColors.accent(for: scheme).opacity(0.1))
                        }
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(LeafSpacing.md)
        }
    }

    // MARK: - Notlar
    private func notesSection(book: Book) -> some View {
        VStack(alignment: .leading, spacing: LeafSpacing.sm) {
            HStack {
                Text("Notlarım").font(.system(size: 17, weight: .semibold)).foregroundStyle(LeafColors.textPrimary(for: scheme))
                Spacer()
                Text("\(book.notes.count)").font(.system(size: 13)).foregroundStyle(LeafColors.textTertiary(for: scheme))
            }
            .padding(.horizontal, LeafSpacing.xxs)

            if book.notes.isEmpty {
                GlassCard {
                    VStack(spacing: LeafSpacing.xs) {
                        Image(systemName: "note.text")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(LeafColors.textTertiary(for: scheme))
                        Text("Henüz not eklenmemiş")
                            .font(.system(size: 13))
                            .foregroundStyle(LeafColors.textTertiary(for: scheme))
                        Text("Okuduklarını not et, hatırla.")
                            .font(.system(size: 12))
                            .foregroundStyle(LeafColors.textTertiary(for: scheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(LeafSpacing.lg)
                }
            } else {
                ForEach(book.notes.sorted { $0.createdAt > $1.createdAt }) { note in
                    NoteCard(note: note)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await store.deleteNote(note) }
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Not Kartı
struct NoteCard: View {
    @Environment(\.colorScheme) private var scheme
    let note: BookNote

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: LeafSpacing.xs) {
                HStack {
                    Text(note.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LeafColors.textPrimary(for: scheme))
                    Spacer()
                    if let pg = note.pageNumber, pg > 0 {
                        Text("s. \(pg)")
                            .font(.system(size: 12))
                            .foregroundStyle(LeafColors.accent(for: scheme))
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background { Capsule().fill(LeafColors.accent(for: scheme).opacity(0.1)) }
                    }
                }
                Text(note.content)
                    .font(.system(size: 13))
                    .foregroundStyle(LeafColors.textSecondary(for: scheme))
                    .lineLimit(4).lineSpacing(3)
                Text(note.createdAt, style: .relative)
                    .font(.system(size: 12))
                    .foregroundStyle(LeafColors.textTertiary(for: scheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LeafSpacing.md)
        }
    }
}

// MARK: - Sayfa Güncelleme Sheet'i

// Eskiden sayfa numarasını klavyeyle elle yazan bir alert vardı — kaydırarak
// seçmenin daha "hareketli" hissettirdiği PageProgressSlider'a taşındı.
struct PageProgressSheet: View {
    @Environment(\.dismiss) private var dismiss
    let book: Book
    let onSave: (Int) -> Void

    @State private var page: Int

    init(book: Book, onSave: @escaping (Int) -> Void) {
        self.book = book
        self.onSave = onSave
        _page = State(initialValue: book.currentPage)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()
                VStack {
                    PageProgressSlider(page: $page, totalPages: book.totalPages)
                    Spacer()
                }
                .padding(LeafSpacing.lg)
                .padding(.top, LeafSpacing.xl)
            }
            .navigationTitle("Sayfa Güncelle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        onSave(page)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Sohbete Paylaş Sheet'i

// Kitabı güncel sayfa/ilerlemesiyle birlikte bir sohbete kart olarak
// gönderiyor — hangi sohbete gideceğini seçtirip isteğe bağlı bir alt yazı
// ekletiyor. Karşı taraf kartı sadece görüntüler, kütüphanesine ekleyemez.
struct ShareBookToChatSheet: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(SocialService.self) private var socialService
    let book: Book

    @State private var selectedConversationId: String?
    @State private var caption = ""
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                if socialService.conversations.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        List(socialService.conversations) { conversation in
                            Button {
                                withAnimation(LeafMotion.fast) { selectedConversationId = conversation.id }
                            } label: {
                                HStack(spacing: LeafSpacing.sm) {
                                    RevealablePhotoView(userId: conversation.otherUser?.id ?? "", size: 40)
                                    Text(conversation.otherUser?.username ?? "Kullanıcı")
                                        .foregroundStyle(LeafColors.textPrimary(for: scheme))
                                    Spacer()
                                    if selectedConversationId == conversation.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(LeafColors.accent(for: scheme))
                                    }
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)

                        if selectedConversationId != nil {
                            VStack(spacing: LeafSpacing.sm) {
                                LeafTextField(title: "Mesaj", text: $caption, placeholder: "İsteğe bağlı bir not ekle...")
                                Button {
                                    Task { await send() }
                                } label: {
                                    Group {
                                        if isSending {
                                            ProgressView().tint(.white)
                                        } else {
                                            Text("Gönder").fontWeight(.semibold)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, LeafSpacing.sm)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(LeafColors.accent(for: scheme))
                                .disabled(isSending)
                            }
                            .padding(LeafSpacing.md)
                            .background(.ultraThinMaterial)
                        }
                    }
                }
            }
            .navigationTitle("Sohbete Paylaş")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
            .task { await socialService.fetchConversations() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: LeafSpacing.md) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(LeafColors.textTertiary(for: scheme))
            Text("Henüz sohbetin yok")
                .font(.headline)
                .foregroundStyle(LeafColors.textPrimary(for: scheme))
            Text("Keşfet'ten biriyle eşleşince\nkitaplarını buradan paylaşabilirsin.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(LeafColors.textSecondary(for: scheme))
        }
        .padding(LeafSpacing.xxl)
    }

    private func send() async {
        guard let conversationId = selectedConversationId else { return }
        isSending = true
        await socialService.sendBookShare(
            conversationId: conversationId,
            book: book,
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isSending = false
        dismiss()
    }
}
