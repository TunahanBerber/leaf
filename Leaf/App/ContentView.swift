import SwiftUI

enum MainTab: Int {
    case library = 0
    case wishlist = 1
}

// MARK: - Root View (Auth Gate)

// giriş kontrolü buradan geçiyor — oturum varsa ana ekran, yoksa giriş sayfası açılıyor
struct ContentView: View {
    @EnvironmentObject private var auth: SupabaseAuthService
    @EnvironmentObject private var store: BookStore

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
                    .environmentObject(auth)
                    .environmentObject(store)
                    .task {
                        // giriş olunca hemen kitapları çek
                        await store.fetchAll()
                    }
            } else {
                AuthView()
                    .environmentObject(auth)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.isAuthenticated)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject private var auth: SupabaseAuthService
    @EnvironmentObject private var store: BookStore
    @State private var selectedTab: MainTab = .library

    var body: some View {
        TabView(selection: $selectedTab) {

            LibraryView()
                .tabItem {
                    Label("Kitaplığım", systemImage: "books.vertical.fill")
                }
                .tag(MainTab.library)

            WishlistView()
                .tabItem {
                    Label("İstek Listesi", systemImage: "bookmark.fill")
                }
                .tag(MainTab.wishlist)

        }
        .tint(LeafColors.primaryLight)
    }
}

#Preview {
    ContentView()
        .environmentObject(SupabaseAuthService())
        .environmentObject(BookStore())
}
