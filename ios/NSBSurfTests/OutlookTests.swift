import XCTest
@testable import NSBSurf

final class OutlookTests: XCTestCase {
    private func sample() throws -> Forecast {
        let url = try XCTUnwrap(Bundle(for: ForecastStore.self).url(forResource: "SampleForecast", withExtension: "json"))
        return try Forecast.decode(Data(contentsOf: url))
    }

    /// Noon on the sample's first day, so the tests don't depend on today's date.
    private func noon(_ f: Forecast) throws -> Date {
        let first = try XCTUnwrap(f.spots.first?.days.first)
        return LocalTime.parse(first.date + "T12:00")
    }

    func testTargetIsTheBestDayOfTheWeek() throws {
        let f = try sample(), now = try noon(f)
        let week = Outlook.bestPerDay(f, now: now)
        XCTAssertEqual(week.count, Outlook.weekDays)
        let target = try XCTUnwrap(Outlook.target(f, now: now))
        let best = try XCTUnwrap(week.map(\.score).max())
        XCTAssertGreaterThanOrEqual(target.score, best - 0.15)  // only the sooner-day nudge can beat it
    }

    func testBestBetsSkipTargetDayAndAreDistinctDays() throws {
        let f = try sample(), now = try noon(f)
        let target = Outlook.target(f, now: now)
        let bets = Outlook.bestBets(f, excluding: target, now: now)
        XCTAssertLessThanOrEqual(bets.count, 3)
        XCTAssertFalse(bets.contains { $0.day.date == target?.day.date })
        XCTAssertEqual(Set(bets.map(\.day.date)).count, bets.count)
        XCTAssertEqual(bets.map(\.score), bets.map(\.score).sorted(by: >))
    }

    func testTodayIgnoresHoursAlreadyGone() throws {
        let f = try sample()
        let spot = try XCTUnwrap(f.spots.first), day = try XCTUnwrap(spot.days.first)
        let late = LocalTime.parse(day.date + "T17:30")
        XCTAssertNil(Outlook.score(spot, day, now: late))
    }

    func testWindowLabel() {
        XCTAssertEqual(Window(start: "2026-11-14T07:00", end: "2026-11-14T10:00").label, "7–10a")
        XCTAssertEqual(Window(start: "2026-11-14T06:00", end: "2026-11-14T17:00").label, "6a–5p")
    }
}
