import SwiftUI

struct WishlistView: View {
    @EnvironmentObject private var store: BookStore
    @State private var showAddBook = false
    @State private var showRecommendation = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    LeafGradientBackground()

                    if store.wishlist.isEmpty {
                        EmptyStateView(
                            icon: "bookmark",
                            title: "İstek Listeniz Boş",
                            message: "Almak istediğiniz, okumayı hayal ettiğiniz\nkitapları buraya ekleyebilirsiniz.",
                            buttonText: "İstek Ekle",
                            onAdd: { showAddBook = true }
                        )
                    } else {
                        LibraryGridView(books: store.wishlist)
                    }
                }

                // öneri butonu — sağ alt köşede, tab bar'ın hemen üstünde duruyor
                Button {
                    showRecommendation = true
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(LeafColors.primaryLight)
                        .clipShape(Circle())
                        .shadow(color: LeafColors.primaryLight.opacity(0.35), radius: 8, y: 4)
                }
                .padding(.trailing, LeafSpacing.md)
                .padding(.bottom, LeafSpacing.lg)
            }
            .navigationTitle("İstek Listesi")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !store.wishlist.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAddBook = true } label: {
                            Image(systemName: "plus").fontWeight(.semibold)
                        }
                        .tint(LeafColors.primaryLight)
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView(isWishlist: true)
            }
            .sheet(isPresented: $showRecommendation) {
                BookRecommendationSheet()
            }
        }
    }
}

#Preview {
    WishlistView()
        .environmentObject(BookStore())
}
