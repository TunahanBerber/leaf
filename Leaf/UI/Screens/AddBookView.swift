import SwiftUI
import PhotosUI

// kitap ekleme / düzenleme ekranı — sheet olarak açılıyor
// SwiftData yok; tüm kayıt işlemi BookStore üzerinden Supabase'e gider

@MainActor
struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var store: BookStore

    @State private var title = ""
    @State private var author = ""
    @State private var totalPages = ""
    @State private var photo: PhotosPickerItem?
    @State private var coverData: Data?
    @State private var isSaving = false

    var bookToEdit: Book? = nil
    var isWishlist: Bool = false

    @State private var showSearchSheet = false
    @State private var selectedOnlineBook: OpenLibraryResult? = nil
    // katalog için ek meta — kullanıcıya görünmez
    @State private var bookLanguage: String?   = nil
    @State private var bookPublisher: String?  = nil
    @State private var bookPublishedYear: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()
                ScrollView {
                    VStack(spacing: LeafSpacing.lg) {
                        coverPicker.padding(.top, LeafSpacing.md)

                        // Kitap arama butonu
                        Button {
                            showSearchSheet = true
                        } label: {
                            HStack(spacing: LeafSpacing.xs) {
                                Image(systemName: "magnifyingglass")
                                Text("İnternetten Kitap Ara").fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background {
                                RoundedRectangle(cornerRadius: LeafRadius.medium)
                                    .fill(LeafColors.accent(for: scheme).opacity(0.1))
                            }
                            .foregroundStyle(LeafColors.accent(for: scheme))
                            .padding(.horizontal, LeafSpacing.md)
                        }
                        .buttonStyle(PressStyle())

                        VStack(spacing: LeafSpacing.md) {
                            LeafTextField(title: "Kitap Adı",    text: $title,      placeholder: "Kitabın adını yazın")
                            LeafTextField(title: "Yazar",        text: $author,     placeholder: "Yazarın adını yazın")
                            LeafTextField(title: "Toplam Sayfa", text: $totalPages, placeholder: "Sayfa sayısını girin", keyboard: .numberPad)
                        }
                        .padding(.horizontal, LeafSpacing.md)
                    }
                    .padding(.bottom, LeafSpacing.xxxl)
                }
            }
            .navigationTitle(bookToEdit == nil ? "Kitap Ekle" : "Kitabı Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundStyle(LeafColors.textSecondary(for: scheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(LeafColors.accent(for: scheme))
                        } else {
                            Text("Kaydet").fontWeight(.semibold)
                                .foregroundStyle(LeafColors.accent(for: scheme))
                        }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showSearchSheet) {
                BookSearchSheet(selectedBook: $selectedOnlineBook)
            }
            .onChange(of: selectedOnlineBook) { _, newBook in
                if let newBook { populate(with: newBook) }
            }
        }
    }

    private var coverPicker: some View {
        // scheme'i closure'a girmeden önce kapıyoruz — Swift 6 Sendable kuralı
        let s = scheme
        let cover = coverData
        return PhotosPicker(selection: $photo, matching: .images) {
            if let data = cover, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous))
            } else {
                VStack(spacing: LeafSpacing.sm) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(LeafColors.accent(for: s).opacity(0.6))
                    Text("Kapak Ekle")
                        .font(.system(size: 13))
                        .foregroundStyle(LeafColors.textTertiary(for: s))
                }
                .frame(width: 140, height: 200)
                .background {
                    RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous)
                        .fill(LeafColors.surfacePrimary(for: s))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous)
                        .strokeBorder(LeafColors.borderPrimary(for: s), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                }
            }
        }
        .onChange(of: photo) { _, val in
            Task { @MainActor in
                if let data = try? await val?.loadTransferable(type: Data.self) {
                    coverData = data
                }
            }
        }
        .onAppear {
            if let edit = bookToEdit {
                title = edit.title
                author = edit.author
                totalPages = String(edit.totalPages)
                coverData = edit.coverImageData
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        // JPEG sıkıştırması — Storage için boyutu küçültür
        let compressed: Data? = coverData.flatMap {
            UIImage(data: $0)?.jpegData(compressionQuality: 0.75)
        }

        if let book = bookToEdit {
            // Mevcut kitabı güncelle
            var updated = book
            updated.title = title
            updated.author = author
            updated.totalPages = Int(totalPages) ?? book.totalPages
            await store.updateBook(updated, newCoverData: compressed)
        } else {
            // Yeni kitap ekle — direkt Supabase'e gider, kataloğa da düşer
            await store.addBook(
                title: title,
                author: author,
                coverImageData: compressed,
                totalPages: Int(totalPages) ?? 0,
                isWishlist: isWishlist,
                language: bookLanguage,
                publisher: bookPublisher,
                publishedYear: bookPublishedYear
            )
        }
        dismiss()
    }

    private func populate(with book: OpenLibraryResult) {
        title  = book.title
        author = book.authorsText
        if let pages = book.pageCount { totalPages = String(pages) }

        // katalog için meta — kayıt sırasında book_catalog'a geçer
        bookLanguage      = book.language
        bookPublisher     = book.publisher
        bookPublishedYear = book.publishedDate

        if let coverUrl = book.highResCoverURL {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: coverUrl) {
                    await MainActor.run { self.coverData = data }
                }
            }
        }
    }
}
