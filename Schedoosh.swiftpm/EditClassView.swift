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

    @State private var time: Date = Date()
    @State private var isSaving: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                header

                VStack(spacing: 12) {
                    TextField("Class name", text: $title)
                        .appTextField()

                    Toggle(isOn: $enabled) {
                        Text("Enabled")
                            .foregroundStyle(.white)
                    }
                    .tint(AppColors.accentPop)
                }
                .appCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("When")
                        .font(.headline)
                        .foregroundStyle(AppColors.textSecondary)

                    HStack {
                        Text("Day")
                            .foregroundStyle(.white)
                        Spacer()
                        Picker("", selection: $weekday) {
                            ForEach(1...7, id: \.self) { w in
                                Text(Calendar.current.weekdaySymbols[w - 1]).tag(w)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppColors.accentPop)
                    }

                    Divider().overlay(Color.white.opacity(0.12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time")
                            .foregroundStyle(.white)

                        DatePicker(
                            "",
                            selection: $time,
                            displayedComponents: [.hourAndMinute]
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .tint(AppColors.accentPop)
                        .environment(\.colorScheme, .dark)
                    }

                    Text("Check-in window is 10 minutes before to 10 minutes after start time.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .appCard()

                Button(saveTitle) { save() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave || isSaving)
                
                if isSaving {
                    ProgressView()
                        .tint(.white)
                }
                
                if let error = store.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(AppColors.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if case .edit = mode {
                    Button(role: .destructive) { delete() } label: {
                        Text("Delete class")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(20)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .tint(.white)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { dismiss() }
                    .foregroundStyle(.white)
            }
        }
        .onAppear { 
            load() 
        }
        .appScreen()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(navTitle)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Keep it simple and consistent.")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        let cal = Calendar.current

        switch mode {
        case .add:
            title = ""
            enabled = true
            let now = Date()
            weekday = cal.component(.weekday, from: now)
            hour = cal.component(.hour, from: now)
            minute = cal.component(.minute, from: now)

        case .edit(let c):
            title = c.title
            weekday = c.weekday
            hour = c.hour
            minute = c.minute
            enabled = c.enabled
        }

        time = cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cal = Calendar.current

        hour = cal.component(.hour, from: time)
        minute = cal.component(.minute, from: time)

        isSaving = true
        store.lastError = nil
        
        Task {
            switch mode {
            case .add:
                let c = ClassItem(
                    title: cleanTitle,
                    weekday: weekday,
                    hour: hour,
                    minute: minute,
                    enabled: enabled
                )
                await store.addClass(c)
                
            case .edit(let existing):
                let updated = ClassItem(
                    id: existing.id,
                    title: cleanTitle,
                    weekday: weekday,
                    hour: hour,
                    minute: minute,
                    enabled: enabled
                )
                await store.updateClass(updated)
            }
            await MainActor.run {
                isSaving = false
                // Only dismiss if there's no error
                if store.lastError == nil {
                    dismiss()
                }
            }
        }
    }

    private func delete() {
        if case .edit(let existing) = mode {
            Task {
                await store.deleteClass(existing)
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}
