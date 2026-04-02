import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var auth: SupabaseAuthService
    @EnvironmentObject private var store: BookStore

    @State private var showAddBook = false

    // Uygulama ayarları
    @AppStorage("appTheme") private var appTheme: String = "system"
    @Environment(\.colorScheme) private var scheme

    // Profil baş harfi — email'in ilk karakterinden
    private var userInitial: String {
        guard let email = auth.currentUser?.email, let first = email.first else { return "U" }
        return String(first).uppercased()
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
                // Profil Menüsü
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Section("Tema") {
                            Button { withAnimation { appTheme = "system" } } label: {
                                Label("Sistem", systemImage: "sparkles")
                            }
                            Button { withAnimation { appTheme = "light" } } label: {
                                Label("Açık", systemImage: "sun.max")
                            }
                            Button { withAnimation { appTheme = "dark" } } label: {
                                Label("Koyu", systemImage: "moon")
                            }
                        }

                        Section("Oturum (\(auth.currentUser?.email ?? "Bilinmiyor"))") {
                            Button(role: .destructive) {
                                Task { await auth.signOut() }
                            } label: {
                                Label("Çıkış Yap", systemImage: "arrow.right.circle.fill")
                            }
                        }
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

                // Kitap ekleme butonu
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
