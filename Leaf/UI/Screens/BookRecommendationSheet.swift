import SwiftUI

// MARK: - BookRecommendationSheet
// book_catalog'dan rastgele bir kitap öneriyorum, kullanıcı beğenirse istek listesine ekleyebiliyor

struct BookRecommendationSheet: View {
    @EnvironmentObject private var store: BookStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var item: BookCatalogItem? = nil
    @State private var isLoading = true
    @State private var isAdding = false
    @State private var addedSuccessfully = false
    @State private var catalogEmpty = false
    @State private var seenTitles: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                if isLoading {
                    loadingView
                } else if catalogEmpty {
                    emptyView
                } else if let book = item {
                    contentView(book: book)
                }
            }
            .navigationTitle("Kitap Önerisi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .tint(LeafColors.primaryLight)
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Sub-views

    private var loadingView: some View {
        VStack(spacing: LeafSpacing.md) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(LeafColors.accent(for: scheme))
            Text("Öneri aranıyor…")
                .font(.subheadline)
                .foregroundStyle(LeafColors.textTertiary(for: scheme))
        }
    }

    private var emptyView: some View {
        VStack(spacing: LeafSpacing.md) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(LeafColors.accent(for: scheme).opacity(0.5))
            Text("Henüz katalogda kitap yok")
                .font(.headline)
                .foregroundStyle(LeafColors.textPrimary(for: scheme))
            Text("OpenLibrary'den kitap ekledikçe\nöneri sistemi çalışmaya başlar.")
                .font(.subheadline)
                .foregroundStyle(LeafColors.textTertiary(for: scheme))
                .multilineTextAlignment(.center)
        }
        .padding(LeafSpacing.xxl)
    }

    private func contentView(book: BookCatalogItem) -> some View {
        ScrollView {
            VStack(spacing: LeafSpacing.xl) {
                coverSection(book: book)
                infoCard(book: book)
                actionButtons(book: book)
            }
            .padding(.horizontal, LeafSpacing.md)
            .padding(.top, LeafSpacing.lg)
            .padding(.bottom, LeafSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
    }

    private func coverSection(book: BookCatalogItem) -> some View {
        RemoteCoverImageView(url: book.coverUrl)
            .frame(width: 160, height: 240)
            .clipShape(RoundedRectangle(cornerRadius: LeafRadius.large, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
    }

    private func infoCard(book: BookCatalogItem) -> some View {
        VStack(spacing: LeafSpacing.xs) {
            Text(book.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(LeafColors.textPrimary(for: scheme))
                .multilineTextAlignment(.center)

            Text(book.author)
                .font(.subheadline)
                .foregroundStyle(LeafColors.textSecondary(for: scheme))

            if book.publisher != nil || book.publishedYear != nil {
                HStack(spacing: LeafSpacing.xs) {
                    if let pub = book.publisher {
                        Label(pub, systemImage: "building.2")
                            .font(.caption)
                            .foregroundStyle(LeafColors.textTertiary(for: scheme))
                    }
                    if book.publisher != nil && book.publishedYear != nil {
                        Text("·")
                            .foregroundStyle(LeafColors.textTertiary(for: scheme))
                    }
                    if let year = book.publishedYear {
                        Label(year, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(LeafColors.textTertiary(for: scheme))
                    }
                }
                .padding(.top, LeafSpacing.xxs)
            }

            if let pages = book.pageCount, pages > 0 {
                Text("\(pages) sayfa")
                    .font(.caption)
                    .foregroundStyle(LeafColors.textTertiary(for: scheme))
            }
        }
        .padding(LeafSpacing.lg)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: LeafRadius.large, style: .continuous)
                .fill(LeafColors.surfacePrimary(for: scheme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: LeafRadius.large, style: .continuous)
                .strokeBorder(LeafColors.borderSubtle(for: scheme), lineWidth: 0.5)
        }
    }

    private func actionButtons(book: BookCatalogItem) -> some View {
        VStack(spacing: LeafSpacing.sm) {
            // istek listesine ekle butonu
            Button {
                Task { await addToWishlist(book) }
            } label: {
                Group {
                    if isAdding {
                        ProgressView()
                            .tint(.white)
                    } else if addedSuccessfully {
                        Label("Eklendi!", systemImage: "checkmark")
                    } else {
                        Label("İstek Listesine Ekle", systemImage: "bookmark.fill")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LeafSpacing.sm)
                .foregroundStyle(.white)
                .background {
                    RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous)
                        .fill(addedSuccessfully ? Color.green : LeafColors.accent(for: scheme))
                }
            }
            .disabled(isAdding || addedSuccessfully)
            .animation(LeafMotion.spring, value: addedSuccessfully)

            // farklı öneri butonu
            Button {
                Task { await load() }
            } label: {
                Label("Farklı Öneri", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LeafSpacing.sm)
                    .foregroundStyle(LeafColors.accent(for: scheme))
                    .background {
                        RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous)
                            .fill(LeafColors.surfacePrimary(for: scheme))
                            .overlay {
                                RoundedRectangle(cornerRadius: LeafRadius.medium, style: .continuous)
                                    .strokeBorder(LeafColors.accent(for: scheme).opacity(0.4), lineWidth: 1)
                            }
                    }
            }
            .disabled(isAdding || isLoading)
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        addedSuccessfully = false
        item = nil

        let result = await store.fetchRecommendation(alreadySeen: seenTitles)

        if result == nil {
            catalogEmpty = true
        } else {
            catalogEmpty = false
            item = result
            if let title = result?.title {
                seenTitles.insert(title.lowercased())
            }
        }
        isLoading = false
    }

    private func addToWishlist(_ book: BookCatalogItem) async {
        isAdding = true

        var coverData: Data? = nil
        if let urlStr = book.coverUrl, let url = URL(string: urlStr) {
            coverData = try? await URLSession.shared.data(from: url).0
        }

        await store.addBook(
            title: book.title,
            author: book.author,
            coverImageData: coverData,
            totalPages: book.pageCount ?? 0,
            isWishlist: true,
            fromCatalog: false  // katalogda zaten var, tekrar yazma
        )

        // kullanıcı öneri üzerinden ekledi — popülerlik sayacını artırıyoruz
        await store.incrementCatalogCount(title: book.title, author: book.author)

        isAdding = false
        addedSuccessfully = true

        // eklendiği gösterilsin, sonra kapat
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        dismiss()
    }
}

// MARK: - RemoteCoverImageView
// tam URL'den resim yükleyen basit view — CoverImageView storage path kullandığı için bunu ekledim

private struct RemoteCoverImageView: View {
    @Environment(\.colorScheme) private var scheme
    let url: String?

    var body: some View {
        if let urlStr = url, let imgURL = URL(string: urlStr) {
            AsyncImage(url: imgURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholder
                case .empty:
                    ZStack {
                        gradientBg
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(LeafColors.accent(for: scheme).opacity(0.5))
                    }
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            gradientBg
            Image(systemName: "book.closed")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(LeafColors.accent(for: scheme).opacity(0.4))
        }
    }

    private var gradientBg: some View {
        LinearGradient(
            colors: [
                LeafColors.accent(for: scheme).opacity(0.15),
                LeafColors.accent(for: scheme).opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    BookRecommendationSheet()
        .environmentObject(BookStore())
}
