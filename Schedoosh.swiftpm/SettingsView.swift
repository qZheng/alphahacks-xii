import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var auth: AuthStore
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(auth.isLoggedIn ? "Logged in" : "Logged out")
                            .foregroundStyle(auth.isLoggedIn ? .green : .secondary)
                    }

                    if auth.isLoggedIn {
                        HStack {
                            Text("Username")
                            Spacer()
                            Text(auth.username.isEmpty ? "Player" : auth.username)
                                .foregroundStyle(.secondary)
                        }

                        Button("Log out", role: .destructive) {
                            auth.logout()
                        }
                    }
                }

                Section("Profile") {
                    TextField("Display name", text: $name)
                    Button("Save Name") {
                        store.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.reconcileMeInGroups()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Rules") {
                    Text("You get +1 point if you don't check in within 10 minutes of class start. It's a friends game—honor system.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Danger zone") {
                    Button("Reset Everything", role: .destructive) {
                        store.clearAll()
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { name = store.profile.name }
        }
    }
}
