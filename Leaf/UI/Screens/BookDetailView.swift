import SwiftUI

// kitap detay ekranı — kapak, bilgi, okuma ilerlemesi, notlar
// SwiftData yok; tüm işlemler BookStore üzerinden Supabase'e gider

struct BookDetailView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BookStore

    // Kitabın güncel hali store'dan okunur — local state değil
    let bookId: String

    @State private var showAddNote = false
    @State private var showEditBook = false
    @State private var showDeleteConfirmation = false
    @State private var showEditPage = false
    @State private var pageText = ""

    // Store'dan güncel kitabı bul
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
                // Kitap silindiyse bu ekran kapanacak
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(book?.title ?? "")
        .task {
            // Notları Supabase'den çek
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
        .alert("Sayfa Güncelle", isPresented: $showEditPage) {
            TextField("Mevcut sayfa", text: $pageText).keyboardType(.numberPad)
            Button("Güncelle") {
                guard let p = Int(pageText) else { return }
                var updated = book
                updated.currentPage = min(p, book.totalPages)
                Task { await store.updateBook(updated) }
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Şu an kaçıncı sayfadasınız?")
        }
    }

    // MARK: - Kapak Başlık
    @ViewBuilder
    private func headerImage(book: Book) -> some View {
        if let data = book.coverImageData, let img = UIImage(data: data) {
            GeometryReader { geo in
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: 280)
                    .clipped()
            }
            .frame(height: 280)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: LeafRadius.xlarge, bottomTrailingRadius: LeafRadius.xlarge))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .task {
                // Kapak henüz bellekte yoksa Storage'dan indir
                await store.loadCoverIfNeeded(for: book.id)
            }
        } else if book.coverImageUrl != nil {
            // URL var ama kapak indiriliyor
            ZStack {
                LinearGradient(
                    colors: [LeafColors.accent(for: scheme).opacity(0.12), LeafColors.accent(for: scheme).opacity(0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                ProgressView().tint(LeafColors.accent(for: scheme))
            }
            .frame(height: 280)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: LeafRadius.xlarge, bottomTrailingRadius: LeafRadius.xlarge))
            .task { await store.loadCoverIfNeeded(for: book.id) }
        } else {
            ZStack {
                LinearGradient(
                    colors: [LeafColors.accent(for: scheme).opacity(0.12), LeafColors.accent(for: scheme).opacity(0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundStyle(LeafColors.accent(for: scheme).opacity(0.3))
            }
            .frame(height: 200)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: LeafRadius.xlarge, bottomTrailingRadius: LeafRadius.xlarge))
        }
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
                }

                Button {
                    pageText = "\(book.currentPage)"
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
