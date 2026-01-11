//
//  BuildingStore.swift
//  Schedoosh
//
//  Created by Lucas Zheng on 2026-01-10.
//

import Foundation
import CoreLocation

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
        BuildingCode.normalize(code)
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
        return buildingsByCode[BuildingCode.normalize(code)]
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
        // Try common bundle locations for Swift Playgrounds projects
        let urlCandidates: [URL?] = [
            Bundle.main.url(forResource: name, withExtension: "json"),
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Resources"),
            Bundle.main.bundleURL.appendingPathComponent("\(name).json")
        ]

        guard let url = urlCandidates.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw NSError(domain: "BuildingStore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not find \(name).json in app bundle. Make sure it’s added as a Resource."
            ])
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Building].self, from: data)
    }
}
