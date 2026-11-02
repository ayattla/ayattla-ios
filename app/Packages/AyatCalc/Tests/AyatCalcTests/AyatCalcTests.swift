import XCTest
@testable import AyatCalc

/// Golden vectors were captured from the live site on 2026-11-02 (see tools/golden).
final class AyatCalcTests: XCTestCase {
    private func golden(_ name: String) throws -> [String: Any] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Golden"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    func testPrayerTimesMatchSite() throws {
        let cases = try XCTUnwrap(golden("prayer_times_2026-11-02")["cases"] as? [[String: Any]])
        XCTAssertEqual(cases.count, 36)
        for c in cases {
            let method = PrayerTimes.Method(fajrAngle: c["fajrAngle"] as! Double, isha: c["isha"] as! Double)
            let zone = try XCTUnwrap(TimeZone(identifier: c["zone"] as! String))
            let noon = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "UTC"),
                                      year: 2026, month: 11, day: 2, hour: 9).date!
            let tz = PrayerTimes.tzHours(zone, at: noon)
            XCTAssertEqual(tz, c["tzHours"] as! Double, "tz \(c["city"]!)")
            let t = PrayerTimes.compute(year: 2026, month: 11, day: 2, lat: c["lat"] as! Double, lng: c["lng"] as! Double,
                                        tzHours: tz, method: method)
            let exp = c["expected"] as! [String: String]
            let got = ["fajr": t.fajr, "sunrise": t.sunrise, "dhuhr": t.dhuhr, "asr": t.asr, "maghrib": t.maghrib, "isha": t.isha]
            for (k, v) in got { XCTAssertEqual(PrayerTimes.hhmm(v), exp[k], "\(c["city"]!) \(k)") }
        }
    }

    func testRamadanIshaUsesTwoHours() {
        let normal = PrayerTimes.compute(year: 2026, month: 11, day: 2, lat: 21.4225, lng: 39.8262, tzHours: 3, method: .ummAlQura)
        let ram = PrayerTimes.compute(year: 2026, month: 11, day: 2, lat: 21.4225, lng: 39.8262, tzHours: 3, method: .ummAlQura, ramadan: true)
        XCTAssertEqual(ram.isha - normal.isha, 0.5, accuracy: 1e-9)
    }

    func testGeoMethodRule() {
        XCTAssertEqual(PrayerTimes.Method.forLocation(lat: 24.7, lng: 46.7), .ummAlQura)
        XCTAssertEqual(PrayerTimes.Method.forLocation(lat: 30.0, lng: 31.2), .defaultGeo)
    }

    func testQiblaMatchesSite() throws {
        let cases = try XCTUnwrap(golden("qibla")["cases"] as? [[String: Any]])
        for c in cases {
            let lat = c["lat"] as! Double, lng = c["lng"] as! Double
            XCTAssertEqual(Qibla.bearing(lat: lat, lng: lng), c["bearing"] as! Double, accuracy: 0.0001, "\(c["city"]!)")
            XCTAssertEqual(Qibla.distanceKm(lat: lat, lng: lng), c["km"] as! Double, accuracy: 0.01, "\(c["city"]!)")
        }
    }

    func testHijriMatchesSite() throws {
        let cases = try XCTUnwrap(golden("hijri")["cases"] as? [[String: Any]])
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        for c in cases {
            let g = f.date(from: (c["gregorian"] as! String) + " 12:00")!
            let h = c["hijri"] as! [String: Int]
            XCTAssertEqual(Hijri.fromGregorian(g), Hijri.Date(year: h["y"]!, month: h["m"]!, day: h["d"]!), "\(c["gregorian"]!)")
        }
    }

    func testZakatMatchesSite() throws {
        let cases = try XCTUnwrap(golden("zakat")["cases"] as? [[String: Any]])
        for c in cases {
            let i = c["input"] as! [String: Any], e = c["expected"] as! [String: Any]
            var v = Zakat.Input()
            v.goldPricePerGram24 = (i["gp"] as! NSNumber).doubleValue; v.silverPricePerGram = (i["spr"] as! NSNumber).doubleValue
            v.cash = (i["cash"] as! NSNumber).doubleValue; v.trade = (i["trade"] as! NSNumber).doubleValue
            v.gold24 = (i["g24"] as! NSNumber).doubleValue; v.gold21 = (i["g21"] as! NSNumber).doubleValue
            v.gold18 = (i["g18"] as! NSNumber).doubleValue; v.silverGrams = (i["sv"] as! NSNumber).doubleValue
            v.receivables = (i["rec"] as! NSNumber).doubleValue; v.debts = (i["debt"] as! NSNumber).doubleValue
            v.basis = Zakat.Basis(rawValue: i["basis"] as! String)!
            let r = Zakat.calculate(v)
            XCTAssertEqual(r.total, (e["total"] as! NSNumber).doubleValue, accuracy: 1e-6)
            XCTAssertEqual(r.nisab, (e["nisab"] as! NSNumber).doubleValue, accuracy: 1e-6)
            XCTAssertEqual(r.due, (e["due"] as! NSNumber).doubleValue, accuracy: 1e-6)
        }
    }
}
