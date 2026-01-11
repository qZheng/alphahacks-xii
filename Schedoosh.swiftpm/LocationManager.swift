import Foundation
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Errors

    enum LocationError: Error, LocalizedError {
        case locationServicesDisabled
        case notAuthorized(CLAuthorizationStatus)
        case requestInProgress
        case timeout
        case noLocationReturned

        var errorDescription: String? {
            switch self {
            case .locationServicesDisabled:
                return "Location Services are disabled on this device."
            case .notAuthorized(let status):
                return "Location permission not granted (status: \(status.rawValue))."
            case .requestInProgress:
                return "A location request is already in progress."
            case .timeout:
                return "Location request timed out."
            case .noLocationReturned:
                return "No location was returned."
            }
        }
    }

    // MARK: - Published state for SwiftUI

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var lastErrorMessage: String?

    /// Demo/simulator support
    @Published var isUsingMockLocation: Bool = false
    @Published var mockCoordinate: CLLocationCoordinate2D? = nil

    // MARK: - Private

    private let manager: CLLocationManager

    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var timeoutTask: Task<Void, Never>?

    /// How "fresh" a cached location must be to reuse it (seconds)
    private let cacheMaxAge: TimeInterval = 30

    // MARK: - Init

    override init() {
        self.manager = CLLocationManager()
        self.authorizationStatus = manager.authorizationStatus
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }

    // MARK: - Authorization

    /// Prompts for permission only if needed. Returns the resulting status.
    func requestAuthorizationIfNeeded() async -> CLAuthorizationStatus {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .notDetermined {
            return await withCheckedContinuation { cont in
                self.authContinuation = cont
                self.manager.requestWhenInUseAuthorization()
            }
        }

        return authorizationStatus
    }

    // MARK: - One-shot location (best for your check-in flow)

    /// Gets a one-shot current location. Uses cached value if it's recent enough.
    func getCurrentLocation(timeoutSeconds: TimeInterval = 10) async throws -> CLLocation {
        // Demo mode
        if isUsingMockLocation, let c = mockCoordinate {
            let loc = CLLocation(latitude: c.latitude, longitude: c.longitude)
            self.lastLocation = loc
            self.lastErrorMessage = nil
            return loc
        }

        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationError.locationServicesDisabled
        }

        // Ensure authorized
        let status = await requestAuthorizationIfNeeded()
        authorizationStatus = status

        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            throw LocationError.notAuthorized(status)
        }

        // Use cached location if fresh
        if let last = lastLocation, abs(last.timestamp.timeIntervalSinceNow) <= cacheMaxAge {
            return last
        }

        // Prevent overlapping requests
        if locationContinuation != nil {
            throw LocationError.requestInProgress
        }

        return try await withCheckedThrowingContinuation { cont in
            self.locationContinuation = cont
            self.lastErrorMessage = nil

            // Fire request
            self.manager.requestLocation()

            // Timeout
            self.timeoutTask?.cancel()
            self.timeoutTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                await self.failLocationRequest(LocationError.timeout)
            }
        }
    }

    // MARK: - Helpers (useful for attendance checks)

    func distanceMeters(from location: CLLocation? = nil, to target: CLLocationCoordinate2D) -> Double? {
        let base = location ?? lastLocation
        guard let base else { return nil }
        let t = CLLocation(latitude: target.latitude, longitude: target.longitude)
        return base.distance(from: t)
    }

    func isWithin(radiusMeters: Double, of target: CLLocationCoordinate2D, using location: CLLocation? = nil) -> Bool {
        guard let d = distanceMeters(from: location, to: target) else { return false }
        return d <= radiusMeters
    }

    func coarseCoordinate(from location: CLLocation, decimals: Int = 3) -> CLLocationCoordinate2D {
        func roundTo(_ value: Double) -> Double {
            let p = pow(10.0, Double(decimals))
            return (value * p).rounded() / p
        }
        return CLLocationCoordinate2D(
            latitude: roundTo(location.coordinate.latitude),
            longitude: roundTo(location.coordinate.longitude)
        )
    }

    // MARK: - Internal completion

    private func finishLocationRequest(_ location: CLLocation) {
        timeoutTask?.cancel()
        timeoutTask = nil

        lastLocation = location
        lastErrorMessage = nil

        let cont = locationContinuation
        locationContinuation = nil
        cont?.resume(returning: location)
    }

    private func failLocationRequest(_ error: Error) {
        timeoutTask?.cancel()
        timeoutTask = nil

        lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription

        let cont = locationContinuation
        locationContinuation = nil
        cont?.resume(throwing: error)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus

        Task { @MainActor in
            self.authorizationStatus = newStatus

            // If someone is awaiting the auth prompt, resume them
            if let cont = self.authContinuation {
                self.authContinuation = nil
                cont.resume(returning: newStatus)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // pick newest
        let best = locations.sorted(by: { $0.timestamp > $1.timestamp }).first

        Task { @MainActor in
            if let best {
                self.finishLocationRequest(best)
            } else {
                self.failLocationRequest(LocationError.noLocationReturned)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.failLocationRequest(error)
        }
    }
}
