import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var store: DataStore
    let groupID: UUID

    @State private var newMemberName = ""

    var groupIndex: Int? {
        store.groups.firstIndex(where: { $0.id == groupID })
    }

    var body: some View {
        List {
            if let gi = groupIndex {
                Section("Members") {
                    ForEach(store.groups[gi].members) { m in
                        HStack {
                            Text(m.name)
                            if m.isMe {
                                Text("(You)")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            Spacer()
                            Text("\(m.points)")
                                .font(.headline)
                        }
                    }
                    .onDelete { idx in
                        store.groups[gi].members.remove(atOffsets: idx)
                        store.reconcileMeInGroups()
                    }
                }

                Section("Add member (local)") {
                    TextField("Name", text: $newMemberName)
                    Button("Add") {
                        addMember()
                    }
                    .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Sync your points") {
                    Button("Update ‘You’ in this group") {
                        store.reconcileMeInGroups()
                    }
                }

                Section {
                    Text("This is local-only. To sync points with friends’ phones, you’d need a backend (ex: Firebase/CloudKit) and accounts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Group not found.")
            }
        }
        .navigationTitle(groupName)
    }

    private var groupName: String {
        store.groups.first(where: { $0.id == groupID })?.name ?? "Group"
    }

    private func addMember() {
        guard let gi = groupIndex else { return }
        let name = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        store.groups[gi].members.append(Member(name: name, points: 0, isMe: false))
        newMemberName = ""
    }
}
