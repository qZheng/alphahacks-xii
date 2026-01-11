import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var store: DataStore
    @State private var showingAdd = false
    @State private var newGroupName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    if store.groups.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.groups) { g in
                                NavigationLink {
                                    GroupDetailView(groupID: g.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(g.name)
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white)
                                            Text("\(g.members.count) members")
                                                .font(.caption)
                                                .foregroundStyle(AppColors.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.white.opacity(0.45))
                                    }
                                    .appCard()
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Leave Group", role: .destructive) {
                                        Task {
                                            await store.leaveGroup(g)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .appScreen()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 16) {
                            Text("New Group")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(spacing: 12) {
                                TextField("Group name", text: $newGroupName)
                                    .appTextField()
                            }
                            .appCard()

                            Button("Create") { createGroup() }
                                .buttonStyle(PrimaryButtonStyle())
                                .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(20)
                    }
                    
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { showingAdd = false }
                                .foregroundStyle(.white)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .appScreen()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Groups")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Compare points with friends.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppColors.castletonGreen)

            Text("No groups yet")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Create a group to start tracking scores together.")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingAdd = true
            } label: {
                Text("Create a group")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .appCard()
    }

    private func createGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        Task {
            await store.createGroup(name: name)
            await MainActor.run {
                newGroupName = ""
                showingAdd = false
            }
        }
    }
}
