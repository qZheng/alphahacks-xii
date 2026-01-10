import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var store: DataStore
    @State private var showingAdd = false
    @State private var newGroupName = ""

    var body: some View {
        NavigationStack {
            List {
                if store.groups.isEmpty {
                    Text("No groups yet. Tap + to make one.")
                        .foregroundStyle(.secondary)
                }

                ForEach(store.groups) { g in
                    NavigationLink {
                        GroupDetailView(groupID: g.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(g.name).font(.headline)
                            Text("\(g.members.count) members")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    store.groups.remove(atOffsets: idx)
                }
            }
            .navigationTitle("Groups")
            .toolbar {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack {
                    Form {
                        Section("Group name") {
                            TextField("Name", text: $newGroupName)
                        }
                        Section {
                            Button("Create") {
                                createGroup()
                            }
                            .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .navigationTitle("New Group")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { showingAdd = false }
                        }
                    }
                }
            }
        }
    }

    private func createGroup() {
        let me = Member(name: store.profile.name, points: store.profile.points, isMe: true)
        let g = Group(name: newGroupName.trimmingCharacters(in: .whitespacesAndNewlines), members: [me])
        store.groups.append(g)
        store.reconcileMeInGroups()
        newGroupName = ""
        showingAdd = false
    }
}
