import SwiftUI

struct ClassesView: View {
    @EnvironmentObject var store: DataStore
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    if store.classes.isEmpty {
                        emptyState
                    } else {
                        ForEach(1...7, id: \.self) { w in
                            let items = classes(for: w)
                            if !items.isEmpty {
                                weekdayCard(weekday: w, items: items)
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
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppColors.accentPop)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack { EditClassView(mode: .add) }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Classes")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text("Tap a class to edit it. Check in within ±10 minutes.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppColors.accentPop)

            Text("No classes yet")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Add your schedule and start competing with friends.")
                .font(.caption)
                .foregroundStyle(AppColors.accentPop)
                .multilineTextAlignment(.center)

            Button {
                showingAdd = true
            } label: {
                Text("Add your first class")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .appCard()
    }

    private func weekdayCard(weekday: Int, items: [ClassItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(weekdayName(weekday))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.accentPop)
                Spacer()
                Text("\(items.count)")
                    .font(.caption)
                    .foregroundStyle(AppColors.accentPop)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(Color.white.opacity(1)))
            }

            VStack(spacing: 10) {
                ForEach(items) { c in
                    NavigationLink {
                        EditClassView(mode: .edit(c))
                    } label: {
                        HStack(spacing: 12) {
                            Text(String(format: "%02d:%02d", c.hour, c.minute))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Capsule().fill(Color.white.opacity(0.10)))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.title)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(c.enabled ? "Enabled" : "Disabled")
                                    .font(.caption)
                                    .foregroundStyle(c.enabled ? AppColors.textSecondary : Color.white.opacity(0.55))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.45))
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(c.enabled ? "Disable" : "Enable") {
                            toggleEnabled(c)
                        }
                        Button("Delete", role: .destructive) {
                            delete(c)
                        }
                    }
                }
            }
        }
        .appCard()
    }

    private func classes(for weekday: Int) -> [ClassItem] {
        store.classes
            .filter { $0.weekday == weekday }
            .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    private func toggleEnabled(_ c: ClassItem) {
        guard let idx = store.classes.firstIndex(where: { $0.id == c.id }) else { return }
        store.classes[idx].enabled.toggle()
    }

    private func delete(_ c: ClassItem) {
        store.classes.removeAll { $0.id == c.id }
    }

    private func weekdayName(_ w: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let i = max(1, min(7, w)) - 1
        return symbols[i]
    }
}
