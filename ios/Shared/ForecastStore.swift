import Foundation
import Observation

/// Loads the published forecast, caches it on disk, and falls back to the cache (then the bundled sample)
/// when offline.
@MainActor
@Observable
final class ForecastStore {
    static let remoteURL = URL(string: "https://zacharyjdb.github.io/nsb-surf/forecast.json")!

    enum Status: Equatable { case idle, loading, failed(String) }

    private(set) var forecast: Forecast?
    private(set) var status: Status = .idle
    private(set) var isStale = false

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("forecast.json")
    }

    init(preview: Bool = false) {
        if preview {
            forecast = Self.bundledSample()
        } else {
            forecast = loadCache() ?? Self.bundledSample()
            isStale = true
        }
    }

    func refresh() async {
        status = .loading
        do {
            var req = URLRequest(url: Self.remoteURL)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 20
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let f = try Forecast.decode(data)
            forecast = f
            isStale = false
            try? data.write(to: cacheURL, options: .atomic)
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func spot(_ id: String) -> Spot? { forecast?.spots.first { $0.id == id } }

    private func loadCache() -> Forecast? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? Forecast.decode(data)
    }

    static func bundledSample() -> Forecast? {
        guard let url = Bundle.main.url(forResource: "SampleForecast", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? Forecast.decode(data)
    }
}

extension Spot {
    /// The hour closest to now (falls back to the engine's "now").
    var currentHour: Hour? {
        let now = Date()
        return hourly.min(by: { abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now)) }) ?? self.now
    }

    func hours(on day: Day) -> [Hour] {
        hourly.filter { $0.t.hasPrefix(day.date) }
    }

    /// Days from today onward (the published file may be a few hours old and start yesterday).
    var upcomingDays: [Day] {
        let today = LocalTime.format(Date(), "yyyy-MM-dd")
        let d = days.filter { $0.date >= today }
        return d.isEmpty ? days : d
    }

    var allTides: [TideEvent] { days.flatMap(\.tides) }
}
