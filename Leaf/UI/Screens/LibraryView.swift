import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var auth: SupabaseAuthService
    @EnvironmentObject private var store: BookStore
    @EnvironmentObject private var social: SocialService

    @State private var showAddBook    = false
    @State private var showSettings   = false

    @AppStorage("appTheme") private var appTheme: String = "system"
    @Environment(\.colorScheme) private var scheme

    private var userInitial: String {
        let name = social.currentProfile?.username ?? auth.currentUser?.email ?? "U"
        return String(name.prefix(1)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                if store.isLoading {
                    ProgressView()
                        .tint(LeafColors.accent(for: scheme))
                } else if store.library.isEmpty {
                    EmptyStateView { showAddBook = true }
                } else {
                    LibraryGridView(books: store.library)
                }
            }
            .navigationTitle("Kitaplığım")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        avatarButtonLabel
                    }
                }

                if !store.library.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAddBook = true } label: {
                            Image(systemName: "plus").fontWeight(.semibold)
                        }
                        .tint(LeafColors.primaryLight)
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(auth)
                    .environmentObject(social)
            }
            .task(id: social.currentProfile?.id) {
                await social.loadMyPhoto()
            }
        }
    }

    private var themeColor: Color {
        switch appTheme {
        case "light": return .orange
        case "dark":  return .indigo
        default:      return LeafColors.primaryLight
        }
    }

    // Fotoğraf yüklenmemişse aynen eski harf-avatarı gösteriyoruz; fotoğraf
    // varsa (myPhotoReveal .revealed döndüyse) onun yerine gerçek fotoğrafı basıyoruz.
    @ViewBuilder
    private var avatarButtonLabel: some View {
        if case .revealed = social.myPhotoReveal?.stage, let url = social.myPhotoReveal?.url {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(themeColor.opacity(0.3), lineWidth: 0.5))
                } else {
                    initialAvatar
                }
            }
        } else {
            initialAvatar
        }
    }

    private var initialAvatar: some View {
        ZStack {
            Circle()
                .fill(themeColor.opacity(0.15))
                .frame(width: 32, height: 32)
            Text(userInitial)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(themeColor)
        }
        .overlay(Circle().stroke(themeColor.opacity(0.3), lineWidth: 0.5))
    }

}
