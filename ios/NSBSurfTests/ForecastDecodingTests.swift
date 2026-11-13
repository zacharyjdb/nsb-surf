import XCTest
@testable import NSBSurf

final class ForecastDecodingTests: XCTestCase {
    func testBundledSampleDecodes() throws {
        let url = try XCTUnwrap(Bundle(for: ForecastStore.self).url(forResource: "SampleForecast", withExtension: "json"))
        let f = try Forecast.decode(Data(contentsOf: url))
        XCTAssertEqual(f.schema, 1)
        XCTAssertEqual(f.spots.count, 5)
        let spot = try XCTUnwrap(f.spots.first)
        XCTAssertGreaterThanOrEqual(spot.days.count, 15)
        XCTAssertFalse(spot.hourly.isEmpty)
        XCTAssertTrue(spot.days.allSatisfy { (0...5).contains($0.stars) })
    }

    func testLocalTimeParsesWallClock() {
        let d = LocalTime.parse("2026-11-13T14:00")
        XCTAssertEqual(LocalTime.calendar.component(.hour, from: d), 14)
        XCTAssertEqual(LocalTime.shortHour(d), "2p")
        XCTAssertEqual(LocalTime.shortHour(LocalTime.parse("2026-11-13T00:00")), "12a")
    }
}
