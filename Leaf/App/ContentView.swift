import SwiftUI
import SwiftData

// ana ekran — kitaplık boşsa EmptyState, doluysa grid gösterir

struct ContentView: View {
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @State private var showAddBook = false
    @AppStorage("appTheme") private var appTheme: String = "system"

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                if books.isEmpty {
                    EmptyStateView { showAddBook = true }
                } else {
                    LibraryGridView(books: books)
                }
            }
            .navigationTitle("Kitaplığım")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // tema butonu — güneş / ay / otomatik
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(LeafMotion.regular) {
                            // döngü: system → light → dark → system
                            switch appTheme {
                            case "system": appTheme = "light"
                            case "light": appTheme = "dark"
                            default: appTheme = "system"
                            }
                        }
                    } label: {
                        Image(systemName: themeIcon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(themeColor)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }

                // kitap ekleme butonu
                if !books.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAddBook = true } label: {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
                        }
                        .tint(LeafColors.primaryLight)
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView()
            }
        }
    }

    // MARK: - Tema ikon ve renkleri

    private var themeIcon: String {
        switch appTheme {
        case "light": "sun.max.fill"     // ☀️ açık tema
        case "dark": "moon.fill"         // 🌙 koyu tema
        default: "sparkles"              // ✨ sistem otomatik
        }
    }

    private var themeColor: Color {
        switch appTheme {
        case "light": .orange
        case "dark": .indigo
        default: LeafColors.primaryLight  // leaf yeşili — otomatik mod
        }
    }
}
