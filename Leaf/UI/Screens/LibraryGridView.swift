import SwiftUI

// kitaplık grid görünümü — iki sütunlu, cam efektli kartlar

struct LibraryGridView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var store: BookStore
    let books: [Book]

    @State private var bookToEdit: Book?
    @State private var bookToDelete: Book?

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: LeafSpacing.md)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: LeafSpacing.lg) {
                ForEach(books) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        BookCardView(book: book)
                    }
                    .buttonStyle(PressStyle())
                    .contextMenu {
                        Button { bookToEdit = book } label: {
                            Label("Düzenle", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            bookToDelete = book
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, LeafSpacing.md)
            .padding(.top, LeafSpacing.xs)
            .padding(.bottom, LeafSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $bookToEdit) { book in
            AddBookView(bookToEdit: book, isWishlist: book.isWishlist)
        }
        .confirmationDialog(
            "Silmek istediğine emin misin?",
            isPresented: Binding(
                get: { bookToDelete != nil },
                set: { if !$0 { bookToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Evet, Sil", role: .destructive) {
                if let book = bookToDelete { delete(book) }
            }
            Button("Vazgeç", role: .cancel) {
                bookToDelete = nil
            }
        } message: {
            if let book = bookToDelete {
                Text("\(book.title) kalıcı olarak silinecek.")
            }
        }
    }

    private func delete(_ book: Book) {
        // BookStore önce Supabase'den siler, sonra yerel diziden kaldırır
        Task { await store.deleteBook(book) }
    }
}

// MARK: - Tek kitap kartı

struct BookCardView: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var store: BookStore
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverSection.frame(height: 220).clipped()

            VStack(alignment: .leading, spacing: LeafSpacing.xxs) {
                Text(book.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LeafColors.textPrimary(for: scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(book.author)
                    .font(.system(size: 12))
                    .foregroundStyle(LeafColors.textTertiary(for: scheme))
                    .lineLimit(1)

                if book.hasStarted {
                    ProgressView(value: book.progress)
                        .tint(LeafColors.accent(for: scheme))
                        .padding(.top, LeafSpacing.xxs)
                }
            }
            .padding(.horizontal, LeafSpacing.sm)
            .padding(.vertical, LeafSpacing.sm)
        }
        .background {
            RoundedRectangle(cornerRadius: LeafRadius.large, style: .continuous)
                .fill(LeafColors.surfacePrimary(for: scheme))
        }
        .clipShape(RoundedRectangle(cornerRadius: LeafRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LeafRadius.large, style: .continuous)
                .strokeBorder(LeafColors.borderSubtle(for: scheme), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        // kart ekrana gelince kapağı indir — data yoksa Storage'dan çeker
        .task { await store.loadCoverIfNeeded(for: book.id) }
    }

    @ViewBuilder
    private var coverSection: some View {
        if let data = book.coverImageData, let img = UIImage(data: data) {
            GeometryReader { geo in
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        } else if book.coverImageUrl != nil {
            // URL var, indiriliyor — küçük spinner göster
            ZStack {
                LinearGradient(
                    colors: [
                        LeafColors.accent(for: scheme).opacity(0.15),
                        LeafColors.accent(for: scheme).opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(LeafColors.accent(for: scheme).opacity(0.5))
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        LeafColors.accent(for: scheme).opacity(0.15),
                        LeafColors.accent(for: scheme).opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "book.closed")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundStyle(LeafColors.accent(for: scheme).opacity(0.4))
            }
        }
    }
}
