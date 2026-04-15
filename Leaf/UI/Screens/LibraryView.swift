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
        }
    }

    private var themeColor: Color {
        switch appTheme {
        case "light": return .orange
        case "dark":  return .indigo
        default:      return LeafColors.primaryLight
        }
    }

}
