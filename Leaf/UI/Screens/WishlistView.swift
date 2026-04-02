import SwiftUI

struct WishlistView: View {
    @EnvironmentObject private var store: BookStore
    @State private var showAddBook = false

    var body: some View {
        NavigationStack {
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
        }
    }
}

#Preview {
    WishlistView()
        .environmentObject(BookStore())
}
