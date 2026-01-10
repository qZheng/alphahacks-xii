import SwiftUI

struct EditClassView: View {
    enum Mode {
        case add
        case edit(ClassItem)
    }

    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var title: String = ""
    @State private var weekday: Int = Calendar.current.component(.weekday, from: Date())
    @State private var hour: Int = 9
    @State private var minute: Int = 0
    @State private var enabled: Bool = true

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Class name", text: $title)
                Toggle("Enabled", isOn: $enabled)
            }

            Section("When") {
                Picker("Day", selection: $weekday) {
                    ForEach(1...7, id: \.self) { w in
                        Text(Calendar.current.weekdaySymbols[w - 1]).tag(w)
                    }
                }
                Stepper("Hour: \(hour)", value: $hour, in: 0...23)
                Stepper("Minute: \(minute)", value: $minute, in: 0...59)

                Text("Check-in window is 10 minutes before to 10 minutes after start time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(saveTitle) {
                    save()
                }
                .disabled(!canSave)

                if case .edit = mode {
                    Button("Delete", role: .destructive) {
                        delete()
                    }
                }
            }
        }
        .navigationTitle(navTitle)
        .onAppear { load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { dismiss() }
            }
        }
    }

    private var saveTitle: String {
        switch mode {
        case .add: return "Add Class"
        case .edit: return "Save Changes"
        }
    }

    private var navTitle: String {
        switch mode {
        case .add: return "New Class"
        case .edit: return "Edit Class"
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func load() {
        switch mode {
        case .add:
            title = ""
            enabled = true
            let now = Date()
            hour = Calendar.current.component(.hour, from: now)
            minute = Calendar.current.component(.minute, from: now)
        case .edit(let c):
            title = c.title
            weekday = c.weekday
            hour = c.hour
            minute = c.minute
            enabled = c.enabled
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .add:
            let c = ClassItem(
                title: cleanTitle,
                weekday: weekday,
                hour: hour,
                minute: minute,
                enabled: enabled
            )
            store.classes.append(c)

        case .edit(let existing):
            guard let idx = store.classes.firstIndex(where: { $0.id == existing.id }) else { return }
            store.classes[idx] = ClassItem(
                id: existing.id,
                title: cleanTitle,
                weekday: weekday,
                hour: hour,
                minute: minute,
                enabled: enabled
            )
        }
        dismiss()
    }

    private func delete() {
        if case .edit(let existing) = mode {
            store.classes.removeAll { $0.id == existing.id }
        }
        dismiss()
    }
}
