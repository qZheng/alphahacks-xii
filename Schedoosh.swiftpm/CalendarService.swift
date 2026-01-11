//
//  CalendarService.swift
//  Schedoosh
//
//  Created by Lucas Zheng on 2026-01-10.
//

import Foundation
import EventKit

@MainActor
final class CalendarService: ObservableObject {
    enum CalendarError: Error, LocalizedError {
        case accessDenied
        case accessRestricted

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Calendar access was denied. Enable it in Settings for this app."
            case .accessRestricted:
                return "Calendar access is restricted on this device."
            }
        }
    }

    private let eventStore = EKEventStore()

    @Published private(set) var lastImportMessage: String = ""

    func requestAccessIfNeeded() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized, .fullAccess:
            return

        case .writeOnly:
            // write-only cannot read events, so treat as denied for our use case
            throw CalendarError.accessDenied

        case .denied:
            throw CalendarError.accessDenied

        case .restricted:
            throw CalendarError.accessRestricted

        case .notDetermined:
            let granted: Bool
            if #available(iOS 17.0, *) {
                let tempStore = EKEventStore()
                granted = (try? await tempStore.requestFullAccessToEvents()) ?? false
            } else {
                let tempStore = EKEventStore()
                granted = await withCheckedContinuation { cont in
                    tempStore.requestAccess(to: .event) { ok, _ in
                        cont.resume(returning: ok)
                    }
                }
            }

            if !granted { throw CalendarError.accessDenied }
            eventStore.reset()


        @unknown default:
            throw CalendarError.accessDenied
        }

    }

    func fetchEvents(start: Date, end: Date) async throws -> [EKEvent] {
        try await requestAccessIfNeeded()
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }

    /// Imports upcoming events as recurring ClassItems.
    /// Only imports events whose `location` yields a letters-only building code.
    @discardableResult
    func importUpcomingClasses(into store: DataStore, daysAhead: Int = 14) async -> (added: Int, updated: Int) {
        do {
            let now = Date()
            let end = Calendar.current.date(byAdding: .day, value: daysAhead, to: now)
                ?? now.addingTimeInterval(60 * 60 * 24 * Double(daysAhead))

            let events = try await fetchEvents(start: now, end: end)

            let imported: [ClassItem] = events.compactMap { ev in
                let title = ev.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }

                // Your spec: location → building code = letters only
                guard let building = Self.extractBuildingCode(from: ev.location) else { return nil }

                let cal = Calendar.current
                let weekday = cal.component(.weekday, from: ev.startDate)
                let hour = cal.component(.hour, from: ev.startDate)
                let minute = cal.component(.minute, from: ev.startDate)

                return ClassItem(
                    title: title,
                    weekday: weekday,
                    hour: hour,
                    minute: minute,
                    enabled: true,
                    buildingCode: building,
                    source: .calendar
                )
            }

            let result = store.mergeCalendarImport(imported)
            lastImportMessage = "Imported \(result.added) new, updated \(result.updated)."
            return result
        } catch {
            lastImportMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return (0, 0)
        }
    }

    /// Strips everything except letters and uppercases (e.g., "ITB 101" -> "ITB")
    static func extractBuildingCode(from location: String?) -> String? {
        guard let location, !location.isEmpty else { return nil }
        let letters = location.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let code = String(String.UnicodeScalarView(letters)).uppercased()
        return code.isEmpty ? nil : code
    }
}
