import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let groupID: UUID

    @State private var showingInvite = false
    @State private var inviteUsername = ""
    @State private var showingLeaveConfirmation = false

    private var groupIndex: Int? {
        store.groups.firstIndex(where: { $0.id == groupID })
    }
    
    private var currentGroup: Group? {
        guard let gi = groupIndex else { return nil }
        return store.groups[gi]
    }

    var body: some View {
        let sorted = currentGroup?.members.sorted { $0.points < $1.points } ?? []
        let isFirstPlace = sorted.firstIndex(where: { $0.isMe }) == 0
        
        ZStack {
            Theme.bg.ignoresSafeArea()

            if let gi = groupIndex {
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard(group: store.groups[gi])

                        leaderboardCard(group: store.groups[gi])

                        infoCard()
                        
                        leaveButton
                    }
                    .padding(16)
                }
                .scrollContentBackground(.hidden)
                .appScreen()
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .tint(.white)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showingInvite = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(AppColors.brightGreen)
                        }
                        Button("Close") { dismiss() }
                            .foregroundStyle(.white)
                    }
                }
                .sheet(isPresented: $showingInvite) {
                    inviteSheet
                }
                .alert("Leave Group", isPresented: $showingLeaveConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Leave", role: .destructive) {
                        if let group = currentGroup {
                            Task {
                                await store.leaveGroup(group)
                                await MainActor.run {
                                    dismiss()
                                }
                            }
                        }
                    }
                } message: {
                    Text("Are you sure you want to leave this group?")
                }
            } else {
                Text("Group not found.")
                    .foregroundStyle(Theme.textSecondary)
            }
            
            if isFirstPlace {
                ConfettiView()
                    .ignoresSafeArea()
            }
        }
    }
    
    private var inviteSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Invite User")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {
                        TextField("Username", text: $inviteUsername)
                            .appTextField()
                    }
                    .appCard()

                    Button("Invite") {
                        inviteUser()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(inviteUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    if let error = store.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(AppColors.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(20)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        showingInvite = false
                        inviteUsername = ""
                        store.lastError = nil
                    }
                    .foregroundStyle(.white)
                }
            }
            .scrollContentBackground(.hidden)
            .tint(.white)
            .appScreen()
        }
        .tint(.white)
    }
    
    private func inviteUser() {
        let username = inviteUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty, let group = currentGroup else { return }
        
        Task {
            await store.inviteUser(username, to: group)
            await MainActor.run {
                if store.lastError == nil {
                    inviteUsername = ""
                    showingInvite = false
                }
            }
        }
    }

    // MARK: - UI Pieces

    private func headerCard(group: Group) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.name)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack {
                Text("\(group.members.count) members")
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                Text("Lower score wins")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
            }
        }
        .softCard()
    }

    private func leaderboardCard(group: Group) -> some View {
        let sorted = group.members.sorted { $0.points < $1.points }
        
        // Find user's position (1-indexed)
        let userPosition = sorted.firstIndex(where: { $0.isMe }).map { $0 + 1 } ?? nil
        let placementEmoji = placementEmoji(for: userPosition)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Leaderboard")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                if let emoji = placementEmoji {
                    Text(emoji)
                        .font(.title3)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                }
            }

            VStack(spacing: 10) {
                ForEach(sorted.indices, id: \.self) { i in
                    let m = sorted[i]

                    HStack(spacing: 12) {
                        Text("#\(i + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .frame(width: 34, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.12))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(m.name)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)

                                if m.isMe {
                                    Text("You")
                                        .font(.caption2)
                                        .foregroundStyle(.white)
                                        .padding(.vertical, 3)
                                        .padding(.horizontal, 8)
                                        .background(Capsule().fill(Theme.accent.opacity(0.25)))
                                }
                            }

                            Text("\(m.points) points")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.06))
                    )
                }
            }
        }
        .softCard()
    }
    
    private func placementEmoji(for position: Int?) -> String? {
        guard let pos = position else { return nil }
        switch pos {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "😰"
        }
    }

    private func infoCard() -> some View {
        Text("All data is synced with the server. Points and member information are managed server-side.")
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
            .softCard()
    }
    
    private var leaveButton: some View {
        Button {
            showingLeaveConfirmation = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .fontWeight(.semibold)
                Text("Leave Group")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.red.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Local Theme + Styles (Playgrounds-safe)

private enum Theme {
    static let bg = Color(hex: "182F57", alpha: 1.0)
    static let card = Color.white.opacity(0.08)
    static let accent = Color(hex: "1B6156", alpha: 1.0)
    static let accent2 = Color(hex: "19454B", alpha: 1.0)
    static let textSecondary = Color.white.opacity(0.70)
}

private extension View {
    func softCard() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }

    func softField() -> some View {
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.10))
            )
            .foregroundStyle(.white)
    }
}

