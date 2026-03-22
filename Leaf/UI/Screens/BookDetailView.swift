import SwiftUI

// kitap detay ekranı — kapak, bilgi, okuma ilerlemesi, notlar

struct BookDetailView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var ctx
    @Bindable var book: Book

    @State private var showAddNote = false
    @State private var showEditPage = false
    @State private var pageText = ""

    var body: some View {
        ZStack {
            LeafGradientBackground()
            ScrollView {
                VStack(spacing: 0) {
                    headerImage.padding(.bottom, LeafSpacing.lg)
                    infoCard.padding(.horizontal, LeafSpacing.md).padding(.bottom, LeafSpacing.lg)
                    progressCard.padding(.horizontal, LeafSpacing.md).padding(.bottom, LeafSpacing.lg)
                    notesSection.padding(.horizontal, LeafSpacing.md).padding(.bottom, LeafSpacing.xxxl)
                }
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddNote = true } label: {
                    Image(systemName: "note.text.badge.plus")
                        .foregroundStyle(LeafColors.accent(for: scheme))
                }
            }
        }
        .sheet(isPresented: $showAddNote) {
            AddNoteView(book: book)
        }
    }

    // MARK: - Kapak Başlık
    @ViewBuilder
    private var headerImage: some View {
        if let data = book.coverImageData, let img = UIImage(data: data) {
            // görsel taşmasın diye genişliği ekrana kısıtladım
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
    private var infoCard: some View {
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
    private var progressCard: some View {
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
        .alert("Sayfa Güncelle", isPresented: $showEditPage) {
            TextField("Mevcut sayfa", text: $pageText).keyboardType(.numberPad)
            Button("Güncelle") {
                if let p = Int(pageText) {
                    book.currentPage = min(p, book.totalPages)
                    book.updatedAt = .now
                }
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Şu an kaçıncı sayfadasınız?")
        }
    }

    // MARK: - Notlar
    private var notesSection: some View {
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
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background { Capsule().fill(LeafColors.accent(for: scheme).opacity(0.1)) }
                    }
                }
                Text(note.content)
                    .font(.system(size: 13))
                    .foregroundStyle(LeafColors.textSecondary(for: scheme))
                    .lineLimit(4)
                    .lineSpacing(3)
                Text(note.createdAt, style: .relative)
                    .font(.system(size: 12))
                    .foregroundStyle(LeafColors.textTertiary(for: scheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LeafSpacing.md)
        }
    }
}
