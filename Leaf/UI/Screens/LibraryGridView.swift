import SwiftUI

// kitaplık grid görünümü — adaptive iki sütun, cam efektli kartlar

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
        // store önce Supabase'den siliyor, sonra yerel listeden kaldırıyor
        Task { await store.deleteBook(book) }
    }
}

// MARK: - Tek kitap kartı

// BookCardView, BookStore'a bağımlı değil — store değişince gereksiz render olmasın diye
// kapak yüklemesini CoverImageView kendi @StateObject'i ile hallediyor
struct BookCardView: View {
    @Environment(\.colorScheme) private var scheme
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoverImageView(coverUrl: book.coverImageUrl)
                .frame(height: 220)

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
    }
}
