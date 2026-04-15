import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var socialService: SocialService
    @Environment(\.colorScheme) var colorScheme
    @State private var navigateToProfile: UserProfile?

    var body: some View {
        NavigationStack {
            ZStack {
                LeafGradientBackground()

                Group {
                    if socialService.isLoading {
                        ProgressView()
                            .tint(LeafColors.accent(for: colorScheme))
                    } else if socialService.discoveredUsers.isEmpty {
                        emptyState
                    } else {
                        userList
                    }
                }
            }
            .navigationTitle("Keşfet")
            .navigationBarTitleDisplayMode(.large)
            .task { await socialService.discoverUsers() }
            .navigationDestination(item: $navigateToProfile) { profile in
                UserProfileView(profile: profile)
            }
        }
    }

    // MARK: - User List

    private var userList: some View {
        ScrollView {
            LazyVStack(spacing: LeafSpacing.sm) {
                ForEach(socialService.discoveredUsers) { user in
                    UserDiscoverCard(profile: user)
                        .onTapGesture { navigateToProfile = user }
                }
            }
            .padding(.horizontal, LeafSpacing.md)
            .padding(.top, LeafSpacing.sm)
            .padding(.bottom, LeafSpacing.xxl)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: LeafSpacing.md) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
            Text("Henüz eşleşme yok")
                .font(.headline)
                .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
            Text("Kütüphanene kitap ekle,\nonu okuyan kişilerle buluş.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
        }
        .padding(LeafSpacing.xxl)
    }
}

// MARK: - User Discover Card

struct UserDiscoverCard: View {
    let profile: UserProfile
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: LeafSpacing.md) {
            // Avatar
            Circle()
                .fill(LeafColors.accent(for: colorScheme).opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay {
                    Text(profile.username.prefix(1).uppercased())
                        .font(.title2.bold())
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                }

            // Bilgi
            VStack(alignment: .leading, spacing: LeafSpacing.xxs) {
                HStack {
                    Text(profile.username)
                        .font(.headline)
                        .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
                    if let age = profile.age {
                        Text("· \(age)")
                            .font(.subheadline)
                            .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
                    }
                }

                if let books = profile.commonBookTitles, !books.isEmpty {
                    Text(books.prefix(2).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                        .lineLimit(1)
                }

                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
        }
        .padding(LeafSpacing.md)
        .background(LeafColors.surfacePrimary(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: LeafRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: LeafRadius.large)
                .stroke(LeafColors.borderSubtle(for: colorScheme))
        }
    }
}
