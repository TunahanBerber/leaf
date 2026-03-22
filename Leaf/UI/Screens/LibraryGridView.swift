import SwiftUI

// kitaplık grid görünümü — iki sütunlu, cam efektli kartlar

struct LibraryGridView: View {
    @Environment(\.colorScheme) private var scheme
    let books: [Book]

    private let columns = [
        GridItem(.flexible(), spacing: LeafSpacing.md),
        GridItem(.flexible(), spacing: LeafSpacing.md)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: LeafSpacing.lg) {
                ForEach(books) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        BookCardView(book: book)
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, LeafSpacing.md)
            .padding(.top, LeafSpacing.xs)
            .padding(.bottom, LeafSpacing.xxxl)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Tek kitap kartı

struct BookCardView: View {
    @Environment(\.colorScheme) private var scheme
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // kapak görseli
            coverSection
                .frame(height: 220)
                .clipped()

            // bilgi alanı
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

    @ViewBuilder
    private var coverSection: some View {
        if let data = book.coverImageData, let img = UIImage(data: data) {
            // görseli sınırlar içinde tutuyorum — fill modunda taşmasın diye
            // geometryReader ile kartın genişliğini alıp ona göre kırpıyorum
            GeometryReader { geo in
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        } else {
            // kapak yoksa gradient placeholder
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
