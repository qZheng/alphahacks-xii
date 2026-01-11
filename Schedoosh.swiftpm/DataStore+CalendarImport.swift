//
//  DataStore+CalendarImport.swift
//  Schedoosh
//
//  Created by Lucas Zheng on 2026-01-10.
//

import Foundation

extension DataStore {

    @discardableResult
    func mergeCalendarImport(_ imported: [ClassItem]) -> (added: Int, updated: Int) {

        func normTitle(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        struct Key: Hashable {
            let title: String
            let weekday: Int
            let hour: Int
            let minute: Int
        }

        // Deduplicate incoming
        var byKey: [Key: ClassItem] = [:]
        for c in imported {
            let key = Key(title: normTitle(c.title), weekday: c.weekday, hour: c.hour, minute: c.minute)
            byKey[key] = c
        }

        // Work on a local copy to avoid multiple didSet saves
        var updatedClasses = classes

        var added = 0
        var updated = 0

        for (_, incoming) in byKey {
            let key = Key(title: normTitle(incoming.title),
                          weekday: incoming.weekday,
                          hour: incoming.hour,
                          minute: incoming.minute)

            if let idx = updatedClasses.firstIndex(where: {
                Key(title: normTitle($0.title),
                    weekday: $0.weekday,
                    hour: $0.hour,
                    minute: $0.minute) == key
            }) {
                var existing = updatedClasses[idx]

                if let bc = incoming.buildingCode, !bc.isEmpty {
                    existing.buildingCode = bc
                }

                // Keep calendar-imported ones synced with calendar title
                if existing.source == .calendar {
                    existing.title = incoming.title
                    existing.enabled = incoming.enabled
                }

                updatedClasses[idx] = existing
                updated += 1
            } else {
                updatedClasses.append(incoming)
                added += 1
            }
        }

        // Single assignment triggers one save
        classes = updatedClasses

        return (added, updated)
    }
}
