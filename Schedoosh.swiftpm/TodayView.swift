import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var engine: AttendanceEngine
    @EnvironmentObject var location: LocationManager
    @EnvironmentObject var buildings: BuildingStore


    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    scoreCard
                    nextClassCard
                    dailyScheduleCard
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .appScreen()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            // This triggers the permission prompt on first launch (status == .notDetermined)
            _ = await location.requestAuthorizationIfNeeded()
        }
    }


    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text("Check in within ±10 minutes of class start.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scoreCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your score")
                    .font(.headline)
                    .foregroundStyle(AppColors.textSecondary)

                Text("\(store.profile.points)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text("Lower is better (golf rules).")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "flag.checkered")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppColors.accentPop)
                .padding(10)
                .background(Circle().fill(Color.white.opacity(0.10)))
        }
        .safeCard()
    }

    private var nextClassCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let (c, d) = engine.nextClassToday() {
                    let now = Date()
                    let isCurrent = now >= d.addingTimeInterval(-10 * 60) && now <= d.addingTimeInterval(10 * 60)
                    Text(isCurrent ? "Current class" : "Next class")
                        .font(.headline)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Text("Next class")
                        .font(.headline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "calendar")
                    .foregroundStyle(AppColors.textSecondary)
            }

            if let (c, d) = engine.nextClassToday() {
                let status = engine.statusText(for: c)
                let can = engine.canCheckInNow(for: c)
                let isChecked = status.hasPrefix("Checked")
                let isMissed = status.hasPrefix("Missed")

                VStack(alignment: .leading, spacing: 6) {
                    Text(c.title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(timeString(d))
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)

                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Button {
                    Task {
                        await engine.checkInNow(for: c, locationManager: location, buildings: buildings)
                    }
                } label: {
                    Text(isChecked ? "Checked In ✅" : (isMissed ? "Missed" : (can ? "Check In ✅" : "Not in window")))
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!can || isChecked || isMissed)
                .opacity((!can || isChecked || isMissed) ? 0.60 : 1.0)

                if !engine.lastCheckMessage.isEmpty {
                    Text(engine.lastCheckMessage)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            } else {
                Text("No more classes today.")
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .safeCard()
    }

    private var dailyScheduleCard: some View {
        let now = Date()
        let cal = Calendar.current
        let todayWeekday = cal.component(.weekday, from: now)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Schedule")
                    .font(.headline)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(1...7, id: \.self) { weekday in
                        let items = weeklyClasses(for: weekday)
                        let isToday = weekday == todayWeekday
                        
                        weekDayColumn(weekday: weekday, items: items, isToday: isToday)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .safeCard()
    }
    
    private func weekDayColumn(weekday: Int, items: [ClassItem], isToday: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Day header
            VStack(alignment: .leading, spacing: 4) {
                Text(weekdayNameShort(weekday))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.brightGreen)
                
                Text("\(items.count)")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(Capsule().fill(Color.white.opacity(isToday ? 0.15 : 0.10)))
            }
            
            // Events for this day
            if items.isEmpty {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                    .frame(minWidth: 80)
                    .frame(minHeight: 40)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items) { c in
                        Button {
                            scheduleTap(c)
                        } label: {
                            weekDayEventRow(c, isToday: isToday)
                        }
                        .buttonStyle(PressableRowStyle())
                    }
                }
                .frame(minWidth: 100)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(isToday ? 0.12 : 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isToday ? AppColors.accentPop.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
        )
    }
    
    private func weekDayEventRow(_ c: ClassItem, isToday: Bool) -> some View {
        let status = engine.statusText(for: c)
        let statusColor = statusColorFor(status)
        
        return VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "%02d:%02d", c.hour, c.minute))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(Capsule().fill(Color.white.opacity(0.15)))
            
            Text(c.title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(isToday ? .white : AppColors.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(status)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(statusColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func scheduleRow(_ c: ClassItem) -> some View {
        let status = engine.statusText(for: c)
        let statusColor = statusColorFor(status)

        return HStack(spacing: 12) {
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

                Text(status)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            if engine.canCheckInNow(for: c) {
                Image(systemName: "hand.tap")
                    .foregroundStyle(AppColors.accentPop.opacity(0.9))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func scheduleTap(_ c: ClassItem) {
        if engine.canCheckInNow(for: c) {
            Task {
                await engine.checkInNow(for: c, locationManager: location, buildings: buildings)
            }
        } else {
            engine.lastCheckMessage = "\(c.title): \(engine.statusText(for: c))"
        }
    }

    private func statusColorFor(_ status: String) -> Color {
        if status.hasPrefix("Checked") { return AppColors.accentPop }
        if status.hasPrefix("Missed") { return AppColors.danger }
        if status.contains("open") { return AppColors.accentPop.opacity(0.85) }
        return AppColors.textSecondary
    }

    private func todaysClasses() -> [ClassItem] {
        let now = Date()
        let cal = Calendar.current
        let todayWeekday = cal.component(.weekday, from: now)
        return store.classes
            .filter { $0.enabled && $0.weekday == todayWeekday }
            .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }
    
    private func weeklyClasses(for weekday: Int) -> [ClassItem] {
        store.classes
            .filter { $0.enabled && $0.weekday == weekday }
            .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }
    
    private func weekdayName(_ w: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let i = max(1, min(7, w)) - 1
        return symbols[i]
    }
    
    private func weekdayNameShort(_ w: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let i = max(1, min(7, w)) - 1
        return symbols[i]
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: d)
    }
}

private struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SafeCard: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppColors.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppColors.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 8)
                    .allowsHitTesting(false)
            )
    }
}

private extension View {
    func safeCard(padding: CGFloat = 16) -> some View {
        self.modifier(SafeCard(padding: padding))
    }
}
