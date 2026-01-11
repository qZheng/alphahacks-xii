import Foundation
import Combine
import CoreLocation

@MainActor
final class AttendanceEngine: ObservableObject, @unchecked Sendable {
    @Published var lastCheckMessage: String = ""

    private let store: DataStore
    private var timer: AnyCancellable?

    private let checkInBufferSeconds: TimeInterval = 10 * 60

    init(store: DataStore) {
        self.store = store
        startTimer()
    }

    func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.runAutoChecks()
                }
            }
    }

    func manualCheckNow() {
        runAutoChecks(forceMessage: true)
    }

    func checkInNow(for classItem: ClassItem,
                    locationManager: LocationManager,
                    buildings: BuildingStore) async {

        let now = Date()
        let cal = Calendar.current

        guard let start = cal.date(bySettingHour: classItem.hour, minute: classItem.minute, second: 0, of: now) else {
            lastCheckMessage = "Couldn't read time for \(classItem.title)."
            return
        }

        let window = checkInWindow(for: start)
        let key = occurrenceKey(for: classItem.id, on: start)

        if store.checkedInKeys.contains(key) {
            lastCheckMessage = "Already checked in for \(classItem.title)."
            return
        }
        if store.missedKeys.contains(key) {
            lastCheckMessage = "Too late to check in for \(classItem.title)."
            return
        }
        guard now >= window.opensAt && now <= window.closesAt else {
            lastCheckMessage = "Check-in window isn't open for \(classItem.title)."
            return
        }

        // 1) Resolve building from building code
        let rawCode = classItem.buildingCode ?? ""
        let code = rawCode.filter { $0.isLetter }.uppercased()

        guard !code.isEmpty else {
            lastCheckMessage = "No building code set for \(classItem.title)."
            return
        }

        guard let building = buildings.building(for: code) else {
            lastCheckMessage = "Building code \(code) isn’t in buildings.json."
            return
        }

        // 2) Get user location (one-shot)
        lastCheckMessage = "Checking your location…"

        do {
            let loc = try await locationManager.getCurrentLocation(timeoutSeconds: 10)

            // Optional: avoid garbage GPS fixes
            if loc.horizontalAccuracy < 0 || loc.horizontalAccuracy > 250 {
                lastCheckMessage = "Location accuracy too low (~\(Int(max(loc.horizontalAccuracy, 0)))m). Try again."
                return
            }

            // 3) Distance check
            let target = CLLocation(latitude: building.coordinate.latitude,
                                    longitude: building.coordinate.longitude)

            let distance = loc.distance(from: target)
            let radius = building.effectiveRadiusMeters

            guard distance <= radius else {
                lastCheckMessage = "Not at \(code): \(formatMeters(distance)) away (need ≤ \(Int(radius))m)."
                return
            }

            // 4) Success
            store.checkedInKeys.insert(key)
            lastCheckMessage = "Checked in: \(classItem.title) @ \(code) ✅"

        } catch {
            lastCheckMessage = "Location failed: \(error.localizedDescription)"
        }
    }

    private func formatMeters(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000.0)
        } else {
            return "\(Int(meters.rounded())) m"
        }
    }


    func canCheckInNow(for classItem: ClassItem) -> Bool {
        guard classItem.enabled else { return false }
        let now = Date()
        let cal = Calendar.current
        let todayWeekday = cal.component(.weekday, from: now)
        guard classItem.weekday == todayWeekday else { return false }

        guard let start = cal.date(bySettingHour: classItem.hour, minute: classItem.minute, second: 0, of: now) else { return false }
        let key = occurrenceKey(for: classItem.id, on: start)
        if store.checkedInKeys.contains(key) || store.missedKeys.contains(key) { return false }

        let window = checkInWindow(for: start)
        return now >= window.opensAt && now <= window.closesAt
    }

    func statusText(for classItem: ClassItem) -> String {
        let now = Date()
        let cal = Calendar.current

        guard let start = cal.date(bySettingHour: classItem.hour, minute: classItem.minute, second: 0, of: now) else {
            return "Time error"
        }

        let key = occurrenceKey(for: classItem.id, on: start)
        if store.checkedInKeys.contains(key) { return "Checked in ✅" }
        if store.missedKeys.contains(key) { return "Missed ❌ (+1)" }

        let window = checkInWindow(for: start)
        if now < window.opensAt { return "Upcoming" }
        if now <= window.closesAt { return "Check-in open ⏳" }
        return "Waiting to score…"
    }

    func nextClassToday() -> (ClassItem, Date)? {
        let now = Date()
        let cal = Calendar.current
        let todayWeekday = cal.component(.weekday, from: now)

        let candidates = store.classes
            .filter { $0.enabled && $0.weekday == todayWeekday }
            .compactMap { c -> (ClassItem, Date)? in
                guard let d = cal.date(bySettingHour: c.hour, minute: c.minute, second: 0, of: now) else { return nil }
                return (c, d)
            }
            .filter { $0.1 >= now.addingTimeInterval(-3600) }

        return candidates.sorted(by: { $0.1 < $1.1 }).first
    }

    private func runAutoChecks(forceMessage: Bool = false) {
        let now = Date()
        let cal = Calendar.current
        let todayWeekday = cal.component(.weekday, from: now)

        let todays = store.classes.filter { $0.enabled && $0.weekday == todayWeekday }
        var didScore = false

        for c in todays {
            guard let start = cal.date(bySettingHour: c.hour, minute: c.minute, second: 0, of: now) else { continue }
            let key = occurrenceKey(for: c.id, on: start)

            if store.checkedInKeys.contains(key) || store.missedKeys.contains(key) { continue }

            let window = checkInWindow(for: start)
            if now > window.closesAt {
                store.missedKeys.insert(key)
                store.addPoint()
                didScore = true
                lastCheckMessage = "Missed \(c.title) (\(timeString(c))) → +1 point"
            }
        }

        if forceMessage && !didScore && lastCheckMessage.isEmpty {
            lastCheckMessage = "Checked: nothing to score right now."
        }
    }

    private func checkInWindow(for start: Date) -> (opensAt: Date, closesAt: Date) {
        (start.addingTimeInterval(-checkInBufferSeconds), start.addingTimeInterval(checkInBufferSeconds))
    }

    private func occurrenceKey(for classID: UUID, on date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "\(classID.uuidString)::\(f.string(from: date))"
    }

    private func timeString(_ c: ClassItem) -> String {
        String(format: "%02d:%02d", c.hour, c.minute)
    }
}
