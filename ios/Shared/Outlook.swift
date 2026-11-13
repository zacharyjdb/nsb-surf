import Foundation

/// One spot on one day, scored for "is this worth going out for?"
struct SpotDay: Hashable, Identifiable {
    let spot: Spot
    let day: Day
    /// Average of the day's best few daylight hours (0–5). Finer-grained than the day's integer stars,
    /// so it breaks ties between days that are both "Fair".
    let score: Double
    let bestHour: Hour?

    var id: String { spot.id + day.date }
    var stars: Int { Int((score + 0.5).rounded(.down)) }
}

/// Picks the day to target and the best bets for the week, across every spot.
enum Outlook {
    static let weekDays = 7
    /// Scores a spot-day from its daylight hours (sunrise to half an hour before sunset).
    /// For today, only the hours still ahead count, and it drops out once there's under an hour of light left.
    static func score(_ spot: Spot, _ day: Day, now: Date = Date()) -> SpotDay? {
        let today = LocalTime.format(now, "yyyy-MM-dd")
        let rise = LocalTime.parse(day.sunrise).addingTimeInterval(-30 * 60)
        let set = LocalTime.parse(day.sunset).addingTimeInterval(-30 * 60)
        var hours = spot.hours(on: day).filter { $0.date >= rise && $0.date <= set }
        if day.date == today {
            if set.timeIntervalSince(now) < 30 * 60 { return nil }  // too late to go today
            hours = hours.filter { $0.date >= now.addingTimeInterval(-30 * 60) }
        }
        guard !hours.isEmpty else {
            return SpotDay(spot: spot, day: day, score: Double(day.stars), bestHour: nil)
        }
        let top = hours.map(\.score).sorted(by: >).prefix(3)
        let avg = top.reduce(0, +) / Double(top.count)
        return SpotDay(spot: spot, day: day, score: avg, bestHour: hours.max { $0.score < $1.score })
    }

    /// For each of the next `weekDays` days, the best spot that day (in date order).
    static func bestPerDay(_ f: Forecast, now: Date = Date()) -> [SpotDay] {
        // One spare day, so the week is still 7 long after today drops out at dusk.
        let dates = f.spots.first.map { Array($0.upcomingDays.prefix(weekDays + 1)).map(\.date) } ?? []
        let days = dates.compactMap { date in
            f.spots.compactMap { spot in
                spot.days.first { $0.date == date }.flatMap { score(spot, $0, now: now) }
            }
            .max { $0.score < $1.score }
        }
        return Array(days.prefix(weekDays))
    }

    /// The single best day this week. Ties go to the sooner day (a bird in the hand).
    static func target(_ f: Forecast, now: Date = Date()) -> SpotDay? {
        let days = bestPerDay(f, now: now)
        return days.enumerated().max { a, b in
            a.element.score + 0.02 * Double(days.count - a.offset)
                < b.element.score + 0.02 * Double(days.count - b.offset)
        }?.element
    }

    /// Other good days this week (not the target day), best first. Skips flat days.
    static func bestBets(_ f: Forecast, excluding target: SpotDay?, count: Int = 3, now: Date = Date()) -> [SpotDay] {
        bestPerDay(f, now: now)
            .filter { $0.day.date != target?.day.date && $0.score >= 0.8 }
            .sorted { $0.score > $1.score }
            .prefix(count)
            .map { $0 }
    }

    /// Every spot's take on one day, best first.
    static func spots(on date: String, _ f: Forecast, now: Date = Date()) -> [SpotDay] {
        f.spots.compactMap { spot in spot.days.first { $0.date == date }.flatMap { score(spot, $0, now: now) } }
            .sorted { $0.score > $1.score }
    }

    /// A bigger swell showing up past the reliable range (days 8–16), if it beats this week.
    static func horizon(_ f: Forecast, beating target: SpotDay?, now: Date = Date()) -> SpotDay? {
        guard let first = f.spots.first else { return nil }
        let week = Set(bestPerDay(f, now: now).map(\.day.date))
        let last = week.max() ?? ""
        let dates = first.upcomingDays.map(\.date).filter { $0 > last }
        let best = dates.compactMap { date in
            f.spots.compactMap { spot in spot.days.first { $0.date == date }.flatMap { score(spot, $0, now: now) } }
                .max { $0.score < $1.score }
        }
        .max { $0.score < $1.score }
        guard let best, best.stars >= 2, best.score > (target?.score ?? 0) + 0.5 else { return nil }
        return best
    }

    /// "Good morning" etc.
    static func greeting(now: Date = Date()) -> String {
        switch LocalTime.calendar.component(.hour, from: now) {
        case 4..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    /// One plain sentence about the week.
    static func verdict(target: SpotDay?, now: Date = Date()) -> String {
        guard let t = target else { return "No forecast loaded yet." }
        let isToday = t.day.date == LocalTime.format(now, "yyyy-MM-dd")
        let tomorrow = LocalTime.format(now.addingTimeInterval(86_400), "yyyy-MM-dd")
        let when = isToday ? "today" : (t.day.date == tomorrow ? "tomorrow" : LocalTime.format(t.day.day, "EEEE"))
        switch t.stars {
        case ...0: return "A flat week. Best shot is \(when), and it's slim."
        case 1: return "Slim pickings this week. \(when.capitalizedFirst) is your best shot."
        case 2: return isToday ? "Today's as good as it gets this week." : "Nothing special, but \(when) is the pick."
        case 3: return isToday ? "Today's the day. Go surf." : "Circle \(when). It's the best day this week."
        default: return isToday ? "It's on today. Drop everything." : "Get ready: \(when) looks really good."
        }
    }
}

extension Window {
    /// Good for most of the daylight, so a time range isn't worth showing.
    var isAllDay: Bool { LocalTime.parse(end).timeIntervalSince(LocalTime.parse(start)) >= 8 * 3600 }

    /// "7–10a", "6a–5p"
    var label: String {
        let s = LocalTime.parse(start), e = LocalTime.parse(end)
        let a = LocalTime.shortHour(s), b = LocalTime.shortHour(e)
        if a == b { return a }
        if a.last == b.last { return "\(a.dropLast())–\(b)" }
        return "\(a)–\(b)"
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
