import CoreLocation
import Observation

/// One-shot location and compass heading. Delegate callbacks arrive on the main thread
/// because the manager is created there.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var coordinate: CLLocationCoordinate2D?
    var heading: Double?
    var status: CLAuthorizationStatus
    var failed = false

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var denied: Bool { status == .denied || status == .restricted }

    func requestLocation() {
        failed = false
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: failed = true
        }
    }

    func startHeading() {
        guard CLLocationManager.headingAvailable() else { return }
        manager.startUpdatingHeading()
    }

    func stopHeading() { manager.stopUpdatingHeading() }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        status = m.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways { m.requestLocation() }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let c = locations.last?.coordinate { coordinate = c }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) { failed = true }

    func locationManager(_ m: CLLocationManager, didUpdateHeading h: CLHeading) {
        heading = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
    }
}
