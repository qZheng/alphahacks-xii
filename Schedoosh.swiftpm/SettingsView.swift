import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var auth: AuthStore
    @State private var name: String = ""
    @EnvironmentObject var buildings: BuildingStore


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    accountCard

                    profileCard

                    rulesCard

                    dangerCard
                }
                .padding(20)
            }
            .navigationTitle("")
            .appScreen()
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { name = store.profile.name }
        }
        
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Make it yours.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.headline)
                .foregroundStyle(AppColors.textSecondary)

            HStack {
                Text("Status")
                    .foregroundStyle(.white)
                Spacer()
                Text(auth.isLoggedIn ? "Logged in" : "Logged out")
                    .foregroundStyle(auth.isLoggedIn ? AppColors.castletonGreen : AppColors.textSecondary)
            }

            if auth.isLoggedIn {
                HStack {
                    Text("Username")
                        .foregroundStyle(.white)
                    Spacer()
                    Text(auth.username.isEmpty ? "Player" : auth.username)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Button(role: .destructive) {
                    auth.logout()
                } label: {
                    Text("Log out")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .appCard()
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Buildings loaded: \(buildings.buildingsByCode.count)")
            if let err = buildings.loadError {
                Text("Buildings error: \(err)").foregroundStyle(.red)
            }

            Text("Profile")
                .font(.headline)
                .foregroundStyle(AppColors.textSecondary)

            TextField("Display name", text: $name)
                .appTextField()

            Button {
                store.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                Task {
                    await store.reconcileMeInGroups()
                }
            } label: {
                Text("Save name")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .appCard()
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rules")
                .font(.headline)
                .foregroundStyle(AppColors.textSecondary)

            Text("You get +1 point if you don’t check in within 10 minutes of class start. It’s a friends game—honor system.")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .appCard()
    }

    private var dangerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Danger zone")
                .font(.headline)
                .foregroundStyle(AppColors.textSecondary)

            Button(role: .destructive) {
                store.clearAll()
            } label: {
                Text("Reset everything")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .appCard()
    }
}
