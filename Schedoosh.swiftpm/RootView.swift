import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject var auth: AuthStore

    init() {
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()

        a.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.deepGreen); a.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.deepGreen)
        ]

        a.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.castletonGreen)
        a.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.castletonGreen)
        ]

        UITabBar.appearance().standardAppearance = a
        UITabBar.appearance().scrollEdgeAppearance = a
    }

    var body: some View {
        if auth.isLoggedIn {
            TabView {
                TodayView().tabItem { Label("Today", systemImage: "clock") }
                ClassesView().tabItem { Label("Classes", systemImage: "calendar") }
                GroupsView().tabItem { Label("Groups", systemImage: "person.3") }
                SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .tint(AppColors.castletonGreen) // selected (also)
        } else {
            LoginView()
                .tint(AppColors.castletonGreen)
        }
    }
}
