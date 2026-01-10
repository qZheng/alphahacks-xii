import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var engine: AttendanceEngine

    var body: some View {
        NavigationStack {
            List {
                Section("Your score") {
                    HStack {
                        Text("Points")
                        Spacer()
                        Text("\(store.profile.points)")
                            .font(.headline)
                    }
                }

                Section("Next class") {
                    if let (c, d) = engine.nextClassToday() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(c.title).font(.headline)
                            Text(timeString(d))
                                .font(.subheadline)
                            Text(engine.statusText(for: c))
                                .font(.subheadline)

                            if engine.canCheckInNow(for: c) {
                                Button("Check In ✅") {
                                    engine.checkInNow(for: c)
                                }
                            }
                        }
                    } else {
                        Text("No more classes today.")
                    }
                }

                Section("Today") {
                    let todays = todaysClasses()
                    if todays.isEmpty {
                        Text("No classes scheduled today.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(todays) { c in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(c.title).font(.headline)
                                    Text("\(String(format: "%02d:%02d", c.hour, c.minute))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(engine.statusText(for: c))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Check") {
                    Button("Run Score Check Now") {
                        engine.manualCheckNow()
                    }
                    if !engine.lastCheckMessage.isEmpty {
                        Text(engine.lastCheckMessage)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Schedoosh")
        }
    }

    private func todaysClasses() -> [ClassItem] {
        let now = Date()
        let cal = Calendar.current
        let todayWeekday = cal.component(.weekday, from: now)
        return store.classes.filter { $0.enabled && $0.weekday == todayWeekday }.sorted {
            ($0.hour, $0.minute) < ($1.hour, $1.minute)
        }
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: d)
    }
}
