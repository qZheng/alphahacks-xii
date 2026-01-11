import SwiftUI

@main
struct SchedooshApp: App {
    @StateObject private var store = DataStore()
    @StateObject private var engine: AttendanceEngine
    @StateObject private var auth = AuthStore()
    @StateObject private var location = LocationManager()
    @StateObject private var buildings = BuildingStore() 

    init() {
        let store = DataStore()
        _store = StateObject(wrappedValue: store)
        _engine = StateObject(wrappedValue: AttendanceEngine(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(engine)
                .environmentObject(auth)
<<<<<<< Updated upstream
<<<<<<< Updated upstream
                .environmentObject(buildings)
                .environmentObject(location)
=======
=======
>>>>>>> Stashed changes
                .environmentObject(location)
                .onAppear {
                    store.authStore = auth
                    Task {
                        if auth.isLoggedIn {
                            await store.refresh()
                        }
                    }
                }
                .onChange(of: auth.isLoggedIn) { newValue in
                    if newValue {
                        Task {
                            await store.refresh()
                        }
                    } else {
                        store.clearAll()
                    }
                }
<<<<<<< Updated upstream
>>>>>>> Stashed changes
=======
>>>>>>> Stashed changes
        }
    }
}
