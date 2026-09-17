import SwiftUI
import PhotosUI

// kitap ekleme ve düzenleme ekranı — sheet olarak açılıyor
// SwiftData yok, kayıt direkt BookStore → Supabase'e gidiyor

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
    @State private var isFetchingCover = false
    @State private var coverFetchTask: Task<Void, Never>?

    var bookToEdit: Book? = nil
    var isWishlist: Bool = false

    @State private var showSearchSheet = false
    @State private var selectedOnlineBook: OpenLibraryResult? = nil
    // katalog için ek meta bilgiler — kullanıcı bunları görmez
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

                        // kitap arama butonu
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
                    // Yatay modda (ya da iPad'de) form ekranın tamamına
                    // gerilmesin diye genişliği sınırlayıp ortalıyoruz.
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
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
        // scheme'i closure'a girmeden önce yakalıyorum — Swift 6 Sendable kuralı zorunlu kılıyor
        let s = scheme
        let cover = coverData
        let fetching = isFetchingCover
        return PhotosPicker(selection: $photo, matching: .images) {
            if let data = cover, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous))
            } else {
                VStack(spacing: LeafSpacing.sm) {
                    if fetching {
                        ProgressView()
                            .tint(LeafColors.accent(for: s).opacity(0.6))
                        Text("Kapak iniyor...")
                            .font(.system(size: 13))
                            .foregroundStyle(LeafColors.textTertiary(for: s))
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(LeafColors.accent(for: s).opacity(0.6))
                        Text("Kapak Ekle")
                            .font(.system(size: 13))
                            .foregroundStyle(LeafColors.textTertiary(for: s))
                    }
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
            }
        }
        .task {
            // düzenleme modundaysa mevcut kapağı URL'den çekiyorum
            guard coverData == nil,
                  let path = bookToEdit?.coverImageUrl else { return }
            let urlString = "https://qowvamowkmysdjrnhkkb.supabase.co/storage/v1/object/public/book-covers/\(path)"
            guard let url = URL(string: urlString) else { return }
            if let (data, _) = try? await URLSession.shared.data(from: url) {
                coverData = data
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        // arama sonucundan seçilen kapak hâlâ arka planda iniyorsa bekliyoruz —
        // yoksa erken "Kaydet"e basınca kitap kapaksız kaydoluyordu
        await coverFetchTask?.value

        // boyutlandırma + sıkıştırma artık uploadCover() içinde merkezi olarak yapılıyor

        if let book = bookToEdit {
            // düzenleme modundayız, mevcut kitabı güncelliyoruz
            var updated = book
            updated.title = title
            updated.author = author
            updated.totalPages = Int(totalPages) ?? book.totalPages
            await store.updateBook(updated, newCoverData: coverData)
        } else {
            // her yeni kitap (arama, elle giriş, foto fark etmez) kataloğa
            // pending olarak gidiyor — admin onaylayana kadar görünmüyor
            await store.addBook(
                title: title,
                author: author,
                coverImageData: coverData,
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

        // katalog meta bilgileri — kayıt sırasında book_catalog'a aktarılıyor
        bookLanguage      = book.language
        bookPublisher     = book.publisher
        bookPublishedYear = book.publishedDate

        guard let coverUrl = book.highResCoverURL else { return }
        isFetchingCover = true
        coverFetchTask = Task {
            let data = try? await URLSession.shared.data(from: coverUrl).0
            await MainActor.run {
                if let data { self.coverData = data }
                self.isFetchingCover = false
            }
        }
    }
}
