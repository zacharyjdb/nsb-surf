import Foundation

/// A group of spots with its own forecast file and timezone. The app shows one region at a time.
enum Region: String, CaseIterable, Identifiable {
    case florida, kauai

    var id: String { rawValue }

    var name: String {
        switch self {
        case .florida: "Florida"
        case .kauai: "Kauai"
        }
    }

    /// Published by engine/build.py. Florida keeps the original name so older builds still work.
    var fileName: String {
        switch self {
        case .florida: "forecast.json"
        case .kauai: "forecast-kauai.json"
        }
    }

    var remoteURL: URL { URL(string: "https://zacharyjdb.github.io/nsb-surf/\(fileName)")! }

    var timeZone: TimeZone {
        switch self {
        case .florida: TimeZone(identifier: "America/New_York")!
        case .kauai: TimeZone(identifier: "Pacific/Honolulu")!
        }
    }
}
