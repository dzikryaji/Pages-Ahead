import CoreLocation
import Foundation
import MapKit

struct LocationCoordinate: Sendable {
    let latitude: Double
    let longitude: Double
    var coreLocation: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
}

enum LocationError: LocalizedError {
    case denied
    case unavailable
    var errorDescription: String? {
        switch self { case .denied: "Location access is unavailable. Enter a city instead."; case .unavailable: "Current location could not be determined." }
    }
}

@MainActor
final class CoreLocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    private func requestPermission() async throws {
        switch manager.authorizationStatus {
        case .notDetermined:
            try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        case .denied, .restricted: throw LocationError.denied
        case .authorizedAlways, .authorizedWhenInUse: return
        @unknown default: throw LocationError.unavailable
        }
    }

    func requestCurrentLocation() async throws -> (location: LocationCoordinate, city: String) {
        try await requestPermission()
        let location = try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
        let mapItems = try? await MKReverseGeocodingRequest(location: location)?.mapItems
        let city = mapItems?.first?.addressRepresentations?.cityName ?? "Current Location"
        return (LocationCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), city)
    }

    func coordinate(for city: String) async throws -> LocationCoordinate {
        guard let request = MKGeocodingRequest(addressString: city),
              let location = try await request.mapItems.first?.location else { throw LocationError.unavailable }
        return LocationCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationContinuation?.resume(returning: location); locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error); locationContinuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            authorizationContinuation?.resume(throwing: LocationError.denied)
            authorizationContinuation = nil
            locationContinuation?.resume(throwing: LocationError.denied)
            locationContinuation = nil
        case .authorizedWhenInUse, .authorizedAlways:
            authorizationContinuation?.resume()
            authorizationContinuation = nil
        case .notDetermined:
            break
        @unknown default:
            authorizationContinuation?.resume(throwing: LocationError.unavailable)
            authorizationContinuation = nil
        }
    }
}
