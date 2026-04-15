import SwiftUI

enum MainTab: Int {
    case library  = 0
    case discover = 1
    case inbox    = 2
    case wishlist = 3
}

// MARK: - Root View (Auth Gate)

struct ContentView: View {
    @EnvironmentObject private var auth: SupabaseAuthService
    @EnvironmentObject private var store: BookStore
    @EnvironmentObject private var social: SocialService

    var body: some View {
        Group {
            if auth.isAuthenticated {
                if !social.profileLoaded {
                    // profil yüklenirken bekle
                    loadingView
                } else if social.currentProfile == nil {
                    // giriş yapıldı ama profil yok → kurulum ekranı
                    ProfileSetupView()
                        .environmentObject(social)
                } else {
                    MainTabView()
                        .environmentObject(auth)
                        .environmentObject(store)
                        .environmentObject(social)
                        .task { await store.fetchAll() }
                }
            } else {
                AuthView()
                    .environmentObject(auth)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.isAuthenticated)
        .animation(.easeInOut(duration: 0.25), value: social.profileLoaded)
        .task(id: auth.isAuthenticated) {
            // oturum değişince profili yeniden yükle
            if auth.isAuthenticated {
                await social.loadCurrentProfile()
            } else {
                // çıkış yapılınca profil state'ini temizle
                social.currentProfile = nil
                social.profileLoaded = false
            }
        }
    }

    private var loadingView: some View {
        ZStack {
            LeafGradientBackground()
            ProgressView()
                .tint(LeafColors.primaryLight)
                .scaleEffect(1.2)
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject private var auth: SupabaseAuthService
    @EnvironmentObject private var store: BookStore
    @EnvironmentObject private var social: SocialService
    @State private var selectedTab: MainTab = .library

    @AppStorage("socialFeaturesEnabled") private var socialFeaturesEnabled: Bool = true

    private var showSocial: Bool { social.isSocialAllowed && socialFeaturesEnabled }

    var body: some View {
        TabView(selection: $selectedTab) {

            LibraryView()
                .environmentObject(social)
                .tabItem {
                    Label("Kitaplığım", systemImage: "books.vertical.fill")
                }
                .tag(MainTab.library)

            if showSocial {
                DiscoverView()
                    .environmentObject(social)
                    .tabItem {
                        Label("Keşfet", systemImage: "person.2.fill")
                    }
                    .tag(MainTab.discover)

                InboxView()
                    .environmentObject(social)
                    .environmentObject(auth)
                    .tabItem {
                        Label("Mesajlar", systemImage: "message.fill")
                    }
                    .tag(MainTab.inbox)
            }

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
        .environmentObject(SocialService())
}
