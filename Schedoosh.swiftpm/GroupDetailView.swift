import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var store: DataStore
    let groupID: UUID

    @State private var newMemberName: String = ""

    private var groupIndex: Int? {
        store.groups.firstIndex(where: { $0.id == groupID })
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if let gi = groupIndex {
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard(group: store.groups[gi])

                        leaderboardCard(group: store.groups[gi])

                        addMemberCard(gi: gi)

                        infoCard()
                    }
                    .padding(16)
                }
                .scrollContentBackground(.hidden)
                .appScreen()
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Text("Group not found.")
                    .foregroundStyle(Theme.textSecondary)
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

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Leaderboard")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("Lower is better")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
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

    private func addMemberCard(gi: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add member (local)")
                .font(.headline)
                .foregroundStyle(.white)

            TextField("Name", text: $newMemberName)
                .softField()
                

            Button {
                addMember(gi: gi)
            } label: {
                Text("Add")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                store.reconcileMeInGroups()
            } label: {
                Text("Sync your points")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .softCard()
    }

    private func infoCard() -> some View {
        Text("This is local-only. To sync points across phones, you’d need accounts + a backend (Firebase/CloudKit/etc).")
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
            .softCard()
    }

    // MARK: - Actions

    private func addMember(gi: Int) {
        let name = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        store.groups[gi].members.append(Member(name: name, points: 0, isMe: false))
        newMemberName = ""
    }
}

// MARK: - Local Theme + Styles (Playgrounds-safe)

private enum Theme {
    static let bg = Color(hex: "182F57")
    static let card = Color.white.opacity(0.08)
    static let accent = Color(hex: "1B6156")
    static let accent2 = Color(hex: "19454B")
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

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        case 8: (a, r, g, b) = ((int >> 24) & 255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
