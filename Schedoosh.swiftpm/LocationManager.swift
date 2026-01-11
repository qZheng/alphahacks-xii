import Foundation
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject, @unchecked Sendable {

    enum LocationError: LocalizedError {
        case servicesDisabled
        case notAuthorized(CLAuthorizationStatus)
        case timeout
        case alreadyRequestingLocation

        var errorDescription: String? {
            switch self {
            case .servicesDisabled:
                return "Location Services are disabled."
            case .notAuthorized(let s):
                return "Location permission not granted (\(s))."
            case .timeout:
                return "Timed out while trying to get your location."
            case .alreadyRequestingLocation:
                return "Already requesting location. Try again in a moment."
            }
        }
    }

    // MARK: - Published state
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var lastErrorMessage: String?

    // MARK: - Private
    private let manager: CLLocationManager

    // One-shot location continuation
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var locationTimeoutTask: Task<Void, Never>?

    // Authorization waiters (support multiple callers)
    private var authContinuations: [CheckedContinuation<CLAuthorizationStatus, Never>] = []
    private var authTimeoutTask: Task<Void, Never>?

    override init() {
        let m = CLLocationManager()
        self.manager = m
        self.authorizationStatus = m.authorizationStatus
        super.init()

        m.delegate = self
        m.desiredAccuracy = kCLLocationAccuracyHundredMeters
        m.distanceFilter = 10
        m.pausesLocationUpdatesAutomatically = true
    }

    // MARK: - Authorization

    /// Triggers the system prompt if status is `.notDetermined`.
    /// Safe to call multiple times; if the OS already prompted, it’s a no-op.
    func requestAuthorizationIfNeeded(timeoutSeconds: TimeInterval = 15) async -> CLAuthorizationStatus {
        // Always read from CoreLocation directly (don’t rely on cached Published state)
        let status = manager.authorizationStatus
        authorizationStatus = status

        switch status {
        case .authorizedAlways, .authorizedWhenInUse, .denied, .restricted:
            return status

        case .notDetermined:
            return await withCheckedContinuation { cont in
                authContinuations.append(cont)

                // IMPORTANT: do NOT “only prompt once”.
                // If the first attempt happened too early / failed, you still want later calls to prompt.
                manager.requestWhenInUseAuthorization()

                // Timeout so we never hang forever
                if authTimeoutTask == nil {
                    authTimeoutTask = Task { [weak self] in
                        try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                        guard let self else { return }
                        await self.timeoutAuthorizationWaitIfNeeded()
                    }
                }
            }

        @unknown default:
            return status
        }
    }

    // MARK: - One-shot location

    func getCurrentLocation(timeoutSeconds: TimeInterval = 10) async throws -> CLLocation {
        lastErrorMessage = nil

        guard CLLocationManager.locationServicesEnabled() else {
            lastErrorMessage = LocationError.servicesDisabled.localizedDescription
            throw LocationError.servicesDisabled
        }

        let status = await requestAuthorizationIfNeeded()

        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            lastErrorMessage = LocationError.notAuthorized(status).localizedDescription
            throw LocationError.notAuthorized(status)
        }

        if locationContinuation != nil {
            lastErrorMessage = LocationError.alreadyRequestingLocation.localizedDescription
            throw LocationError.alreadyRequestingLocation
        }

        return try await withCheckedThrowingContinuation { cont in
            self.locationContinuation = cont

            self.locationTimeoutTask?.cancel()
            self.locationTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                guard let self else { return }
                await self.failLocationRequest(LocationError.timeout)
            }

            manager.requestLocation()
        }
    }

    // MARK: - Internal helpers

    private func resolveAuthWaiters(with status: CLAuthorizationStatus) {
        // Only resolve once the user has decided (or system updated status)
        guard status != .notDetermined else { return }

        authTimeoutTask?.cancel()
        authTimeoutTask = nil

        let waiters = authContinuations
        authContinuations.removeAll()
        for w in waiters {
            w.resume(returning: status)
        }
    }

    private func timeoutAuthorizationWaitIfNeeded() {
        // If we’re still notDetermined, resume waiters anyway so callers can fail gracefully
        let status = manager.authorizationStatus
        authorizationStatus = status

        guard status == .notDetermined else { return }

        authTimeoutTask?.cancel()
        authTimeoutTask = nil

        let waiters = authContinuations
        authContinuations.removeAll()
        for w in waiters {
            w.resume(returning: status)
        }

        lastErrorMessage = "Location prompt timed out. Try again and respond to the prompt."
    }

    private func finishLocationRequest(_ location: CLLocation) {
        locationTimeoutTask?.cancel()
        locationTimeoutTask = nil

        lastLocation = location
        lastErrorMessage = nil

        let cont = locationContinuation
        locationContinuation = nil
        cont?.resume(returning: location)
    }

    private func failLocationRequest(_ error: Error) {
        locationTimeoutTask?.cancel()
        locationTimeoutTask = nil

        lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription

        let cont = locationContinuation
        locationContinuation = nil
        cont?.resume(throwing: error)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: @preconcurrency CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationStatus = status
            self.resolveAuthWaiters(with: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationStatus = status
            self.resolveAuthWaiters(with: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.finishLocationRequest(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.failLocationRequest(error)
        }
    }
}
