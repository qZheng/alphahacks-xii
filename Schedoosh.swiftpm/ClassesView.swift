import SwiftUI

struct ClassesView: View {
    @EnvironmentObject var store: DataStore
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                if store.classes.isEmpty {
                    Text("No classes yet. Tap + to add one.")
                        .foregroundStyle(.secondary)
                }

                ForEach(store.classes) { c in
                    NavigationLink {
                        EditClassView(mode: .edit(c))
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(c.title).font(.headline)
                                Spacer()
                                Text(c.enabled ? "On" : "Off")
                                    .foregroundStyle(c.enabled ? .green : .secondary)
                                    .font(.caption)
                            }
                            Text("\(weekdayName(c.weekday)) @ \(String(format: "%02d:%02d", c.hour, c.minute))")
                                .font(.subheadline)
                        }
                    }
                }
                .onDelete { idx in
                    store.classes.remove(atOffsets: idx)
                }
            }
            .navigationTitle("Classes")
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack {
                    EditClassView(mode: .add)
                }
            }
        }
    }

    private func weekdayName(_ w: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let i = max(1, min(7, w)) - 1
        return symbols[i]
    }
}
