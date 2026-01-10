import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        if auth.isLoggedIn {
            TabView {
                TodayView()
                    .tabItem { Label("Today", systemImage: "clock") }

                ClassesView()
                    .tabItem { Label("Classes", systemImage: "list.bullet") }

                GroupsView()
                    .tabItem { Label("Groups", systemImage: "person.3") }

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
        } else {
            LoginView()
        }
    }
}
