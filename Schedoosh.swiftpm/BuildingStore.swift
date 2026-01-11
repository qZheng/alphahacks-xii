//
//  BuildingStore.swift
//  Schedoosh
//
//  Created by Lucas Zheng on 2026-01-10.
//

import Foundation
import CoreLocation

func normalizeBuildingCode(_ raw: String) -> String {
    raw.filter(\.isLetter).uppercased()
}


enum BuildingCode {
    static func normalize(_ raw: String) -> String {
        raw.filter(\.isLetter).uppercased()
    }
}

struct Building: Codable, Hashable {
    let code: String
    let name: String?
    let lat: Double
    let lon: Double
    let radiusMeters: Double?

    var normalizedCode: String {
        normalizeBuildingCode(code)
    }



    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var effectiveRadiusMeters: Double {
        radiusMeters ?? 150
    }
}

@MainActor
final class BuildingStore: ObservableObject {
    @Published private(set) var buildingsByCode: [String: Building] = [:]
    @Published private(set) var loadError: String? = nil
    nonisolated static func normalize(_ raw: String) -> String {
        raw.filter(\.isLetter).uppercased()
    }

    init() {
        reload()
    }

    func reload() {
        do {
            let buildings = try loadBuildingsJSON(named: "buildings")
            buildingsByCode = Dictionary(
                uniqueKeysWithValues: buildings.map { ($0.normalizedCode, $0) }
            )
            loadError = nil
        } catch {
            buildingsByCode = [:]
            loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func building(for code: String?) -> Building? {
        guard let code else { return nil }
        return buildingsByCode[normalizeBuildingCode(code)]
    }


    func coordinate(for code: String?) -> CLLocationCoordinate2D? {
        building(for: code)?.coordinate
    }

    func radiusMeters(for code: String?, default defaultRadius: Double = 150) -> Double {
        building(for: code)?.effectiveRadiusMeters ?? defaultRadius
    }

    func isKnownBuilding(code: String?) -> Bool {
        building(for: code) != nil
    }

    // MARK: - Helpers


    private func loadBuildingsJSON(named name: String) throws -> [Building] {
        let fm = FileManager.default

        // In SwiftPM/Playgrounds, resources might be in a separate bundle.
        // Search main + all bundles + all frameworks.
        let bundlesToSearch: [Bundle] = {
            var seen = Set<ObjectIdentifier>()
            var out: [Bundle] = []

            func add(_ b: Bundle) {
                let id = ObjectIdentifier(b)
                guard !seen.contains(id) else { return }
                seen.insert(id)
                out.append(b)
            }

            add(.main)
            Bundle.allBundles.forEach(add)
            Bundle.allFrameworks.forEach(add)
            return out
        }()

        // 1) Normal resource lookup
        for b in bundlesToSearch {
            if let url =
                b.url(forResource: name, withExtension: "json") ??
                b.url(forResource: name, withExtension: "json", subdirectory: "Resources")
            {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode([Building].self, from: data)
            }
        }

        // 2) File-path fallback inside resource directories
        for b in bundlesToSearch {
            guard let resourceURL = b.resourceURL else { continue }

            let candidates = [
                resourceURL.appendingPathComponent("\(name).json"),
                resourceURL.appendingPathComponent("Resources/\(name).json")
            ]

            for url in candidates where fm.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode([Building].self, from: data)
            }
        }

        throw NSError(domain: "BuildingStore", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not find \(name).json in any bundle. Ensure it exists at Resources/\(name).json in the project."
        ])
    }


}
