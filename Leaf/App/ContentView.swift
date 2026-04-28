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
            if auth.isAuthenticated {
                await social.loadCurrentProfile()
                // giriş yapılınca hemen subscription başlat ve badge yükle
                await social.fetchConversations()
            } else {
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
    @EnvironmentObject private var pushService: PushNotificationService
    @State private var selectedTab: MainTab = .library
    @Environment(\.scenePhase) private var scenePhase

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
                    .badge(social.unreadCount)
                    .tag(MainTab.inbox)
            }

            WishlistView()
                .tabItem {
                    Label("İstek Listesi", systemImage: "bookmark.fill")
                }
                .tag(MainTab.wishlist)
        }
        .tint(LeafColors.primaryLight)
        .onAppear {
            pushService.requestPermissionAndRegister()
            pushService.clearBadge()
        }
        // Uygulama ön plana gelince okunmamış sayısını güncelle
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await social.refreshUnreadCount() }
            }
        }
        // Bildirime tıklanınca inbox tab'ına geç
        .onReceive(NotificationCenter.default.publisher(for: .navigateToConversation)) { _ in
            if showSocial { selectedTab = .inbox }
        }
    }
}


#Preview {
    ContentView()
        .environmentObject(SupabaseAuthService())
        .environmentObject(BookStore())
        .environmentObject(SocialService())
}
