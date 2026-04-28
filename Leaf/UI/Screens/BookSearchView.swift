// BookSearchSheet.swift
// kitap adı veya yazar girilince Google Books + OpenLibrary'den öneri getiriyor

import SwiftUI

// MARK: - Ana Sheet

struct BookSearchSheet: View {
    @StateObject private var service = OpenLibraryService()
    @Binding var selectedBook: OpenLibraryResult?
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // arka plan
                LeafGradientBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // arama kutusu
                    searchBar
                        .padding(.horizontal, LeafSpacing.md)
                        .padding(.top, LeafSpacing.sm)
                        .padding(.bottom, LeafSpacing.sm)

                    Divider()
                        .opacity(0.15)

                    // içerik
                    contentArea
                }
            }
            .navigationTitle("Kitap Ara")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") {
                        service.clear()
                        dismiss()
                    }
                    .foregroundStyle(LeafColors.primary)
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Arama Kutusu

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16, weight: .medium))

            TextField("Kitap adı veya yazar...", text: $query)
                .focused($isSearchFocused)
                .autocorrectionDisabled()
                .onChange(of: query) { _, newValue in
                    service.search(query: newValue)
                }
                .submitLabel(.search)
                .onSubmit {
                    Task { await service.searchNow(query: query) }
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    service.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LeafRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: LeafRadius.medium)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.2), value: query.isEmpty)
    }

    // MARK: - İçerik Alanı

    @ViewBuilder
    private var contentArea: some View {
        if service.isLoading {
            loadingView
        } else if let error = service.errorMessage {
            errorView(message: error)
        } else if query.isEmpty {
            emptyQueryView
        } else if service.results.isEmpty && !query.isEmpty {
            noResultsView
        } else {
            resultsList
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            // sadece spinner koyuyorum — kullanıcı ne aradığını zaten biliyor
            ProgressView()
                .scaleEffect(1.2)
                .tint(LeafColors.primary)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Tekrar Dene") {
                Task { await service.searchNow(query: query) }
            }
            .buttonStyle(.bordered)
            .tint(LeafColors.primary)
            Spacer()
        }
        .padding()
    }

    private var emptyQueryView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 48))
                .foregroundStyle(LeafColors.primary.opacity(0.4))
            VStack(spacing: 6) {
                Text("Kitabını Bul")
                    .font(.headline)
                Text("Kitap adı veya yazar ismiyle arama yap,\nkapak ve bilgileri otomatik dolsun.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding()
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("\"\(query)\" için sonuç bulunamadı")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(service.results) { book in
                    BookSearchResultRow(book: book) {
                        selectedBook = book
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, LeafSpacing.md)
            .padding(.vertical, LeafSpacing.sm)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Satır Buton Stili (ScrollView ile çakışmıyor)

private struct SearchRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? LeafMotion.pressScale : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Sonuç Satırı

struct BookSearchResultRow: View {
    let book: OpenLibraryResult
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // liste için küçük kapak yeterli, çok daha hızlı yükleniyor
                CoverThumbnail(url: book.coverURL)

                // kitap bilgileri
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if !book.authorsText.isEmpty {
                        Text(book.authorsText)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let pages = book.pageCount, pages > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 10))
                            Text("\(pages) sayfa")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LeafRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: LeafRadius.large)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(SearchRowButtonStyle())
    }
}

// MARK: - Kapak Küçük Resmi

struct CoverThumbnail: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderCover
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        placeholderCover
                    }
                }
            } else {
                placeholderCover
            }
        }
        .frame(width: 48, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }

    private var placeholderCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.ultraThinMaterial)
            Image(systemName: "book.closed.fill")
                .foregroundStyle(LeafColors.primary.opacity(0.5))
                .font(.system(size: 20))
        }
    }
}
