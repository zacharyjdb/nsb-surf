import Foundation

// Mirrors engine/build.py output (schema 1). Keys are snake_case in JSON.

struct Forecast: Codable {
    let schema: Int
    let generatedUtc: String
    let timezone: String
    let sources: [String]
    let buoys: [Buoy]
    let spots: [Spot]

    var generatedAt: Date? { ISO8601DateFormatter().date(from: generatedUtc) }
}

struct Buoy: Codable, Identifiable {
    let id: String
    let name: String
    let observedUtc: String
    let waveM: Double?
    let waveFt: Double?
    let dominantPeriodS: Double?
    let meanDir: Double?
    let waterF: Int?
    let swellM: Double?
    let swellPeriodS: Double?
    let swellDir: String?
    let windseaM: Double?
    let windseaPeriodS: Double?

    var observedAt: Date? { ISO8601DateFormatter().date(from: observedUtc) }
}

struct Spot: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let lat: Double
    let lon: Double
    let facing: Double
    let tideStation: String
    let now: Hour?
    let nextTide: TideEvent?
    let days: [Day]
    let hourly: [Hour]
    let buoyNudge: Double?

    static func == (a: Spot, b: Spot) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct SwellTrain: Codable, Hashable {
    let heightFt: Double
    let periodS: Double
    let dir: Double
    let dirLabel: String
    let kind: String  // "swell" | "wind"
}

struct Hour: Codable, Identifiable, Hashable {
    let t: String
    let surfMinFt: Double
    let surfMaxFt: Double
    let surfLabel: String
    let primary: SwellTrain?
    let trains: [SwellTrain]
    let windMph: Int?
    let gustMph: Int?
    let windDir: Double?
    let windDirLabel: String
    let windKind: String
    let tideFt: Double?
    let waterF: Int?
    let score: Double
    let stars: Int
    let model: String

    var id: String { t }
    var date: Date { LocalTime.parse(t) }
}

struct TideEvent: Codable, Hashable {
    let type: String  // "H" | "L"
    let t: String
    let label: String
    let ft: Double

    var date: Date { LocalTime.parse(t) }
    var isHigh: Bool { type == "H" }
}

struct Wind: Codable, Hashable {
    let mph: Int?
    let dirLabel: String
    let kind: String
}

struct Window: Codable, Hashable {
    let start: String
    let end: String
}

struct Day: Codable, Identifiable, Hashable {
    let date: String
    let confidence: String  // high | medium | low
    let surfMinFt: Double
    let surfMaxFt: Double
    let surfLabel: String
    let stars: Int
    let rating: String
    let starsAm: Int
    let starsPm: Int
    let bestWindow: Window?
    let primary: SwellTrain?
    let windAm: Wind
    let windPm: Wind
    let headline: String
    let advice: String
    let summary: String
    let tides: [TideEvent]
    let sunrise: String
    let sunset: String
    let waterF: Int?

    var id: String { date }
    var day: Date { LocalTime.parse(date + "T12:00") }
    var isLowConfidence: Bool { confidence == "low" }
}

enum LocalTime {
    /// All forecast times are local wall-clock strings for the spot's timezone ("2026-11-13T14:00").
    static let zone = TimeZone(identifier: "America/New_York")!

    private static let parser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zone
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f
    }()

    static func parse(_ s: String) -> Date {
        parser.date(from: String(s.prefix(16))) ?? .distantPast
    }

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        return c
    }

    static func format(_ d: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zone
        f.dateFormat = pattern
        return f.string(from: d)
    }

    /// "6a", "12p"
    static func shortHour(_ d: Date) -> String {
        let h = calendar.component(.hour, from: d)
        return "\(h % 12 == 0 ? 12 : h % 12)\(h < 12 ? "a" : "p")"
    }
}

extension Forecast {
    static func decode(_ data: Data) throws -> Forecast {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(Forecast.self, from: data)
    }
}
