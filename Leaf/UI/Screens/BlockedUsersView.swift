import SwiftUI

struct BlockedUsersView: View {
    @EnvironmentObject var social: SocialService
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            LeafGradientBackground()

            if social.blockedUsers.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(social.blockedUsers) { profile in
                        BlockedUserRowView(profile: profile)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    Task { await social.unblockUser(userId: profile.id) }
                                } label: {
                                    Label("Engeli Kaldır", systemImage: "hand.raised.slash")
                                }
                                .tint(LeafColors.accent(for: colorScheme))
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Engellenen Kullanıcılar")
        .navigationBarTitleDisplayMode(.inline)
        .task { await social.fetchBlockedUsers() }
    }

    private var emptyState: some View {
        VStack(spacing: LeafSpacing.md) {
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 48))
                .foregroundStyle(LeafColors.textTertiary(for: colorScheme))
            Text("Engellediğin kimse yok")
                .font(.headline)
                .foregroundStyle(LeafColors.textPrimary(for: colorScheme))
            Text("Engellediğin kullanıcılar\nburada listelenir.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(LeafColors.textSecondary(for: colorScheme))
        }
        .padding(LeafSpacing.xxl)
    }
}

// MARK: - Blocked User Row

private struct BlockedUserRowView: View {
    let profile: UserProfile
    @EnvironmentObject var social: SocialService
    @Environment(\.colorScheme) var colorScheme
    @State private var isUnblocking = false

    var body: some View {
        HStack(spacing: LeafSpacing.md) {
            Circle()
                .fill(LeafColors.accent(for: colorScheme).opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(profile.username.prefix(1).uppercased())
                        .font(.headline.bold())
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                }

            Text(profile.username)
                .font(.headline)
                .foregroundStyle(LeafColors.textPrimary(for: colorScheme))

            Spacer()

            Button {
                isUnblocking = true
                Task {
                    await social.unblockUser(userId: profile.id)
                    isUnblocking = false
                }
            } label: {
                if isUnblocking {
                    ProgressView().tint(LeafColors.accent(for: colorScheme))
                } else {
                    Text("Engeli Kaldır")
                        .font(.caption.bold())
                        .foregroundStyle(LeafColors.accent(for: colorScheme))
                }
            }
            .disabled(isUnblocking)
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
