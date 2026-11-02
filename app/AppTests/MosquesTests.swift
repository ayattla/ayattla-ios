import XCTest
import CoreLocation
@testable import AyatTutla

final class MosquesTests: XCTestCase {
    private let riyadh = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)

    private func m(_ id: String, _ dLat: Double) -> MosquesView.Mosque {
        .init(id: id, name: id, address: nil,
              coordinate: CLLocationCoordinate2D(latitude: riyadh.latitude + dLat, longitude: riyadh.longitude))
    }

    func testFiltersByRadiusDedupesAndSorts() {
        // 0.01° latitude ≈ 1.1 km
        let items = [m("far", 0.04), m("b", 0.02), m("a", 0.005), m("a", 0.005)]
        let r = MosquesView.nearby(items, from: riyadh, radiusKm: 3)
        XCTAssertEqual(r.map(\.id), ["a", "b"])
        XCTAssertLessThan(r[0].distance, r[1].distance)
        XCTAssertEqual(MosquesView.nearby(items, from: riyadh, radiusKm: 1).map(\.id), ["a"])
    }

    func testRadiiMatchSite() {
        XCTAssertEqual(MosquesView.radii, [1, 3, 5])
    }

    func testCountText() {
        XCTAssertEqual(MosquesView.countText(1), "مسجد واحد")
        XCTAssertEqual(MosquesView.countText(2), "مسجدان")
        XCTAssertEqual(MosquesView.countText(4), "٤ مساجد")
        XCTAssertEqual(MosquesView.countText(12), "١٢ مسجدا")
    }
}
