import Foundation
import Observation

/// Loads the published forecast, caches it on disk, and falls back to the cache (then the bundled sample)
/// when offline.
@MainActor
@Observable
final class ForecastStore {
    enum Status: Equatable { case idle, loading, failed(String) }

    /// The region on screen. Remembered between launches; changing it swaps in that region's cached
    /// forecast right away (RootView then refreshes it).
    var region: Region {
        didSet {
            guard region != oldValue else { return }
            UserDefaults.standard.set(region.rawValue, forKey: Self.regionKey)
            LocalTime.zone = region.timeZone
            forecast = loadCache(region) ?? Self.bundledSample(region)
            isStale = true
            status = .idle
        }
    }

    private(set) var forecast: Forecast?
    private(set) var status: Status = .idle
    private(set) var isStale = false

    private static let regionKey = "region"

    private func cacheURL(_ r: Region) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(r.fileName)
    }

    init(preview: Bool = false) {
        let saved = UserDefaults.standard.string(forKey: Self.regionKey).flatMap(Region.init(rawValue:))
        region = preview ? .florida : (saved ?? .florida)
        LocalTime.zone = region.timeZone
        if preview {
            forecast = Self.bundledSample(.florida)
        } else {
            forecast = loadCache(region) ?? Self.bundledSample(region)
            isStale = true
        }
    }

    func refresh() async {
        let r = region
        status = .loading
        do {
            var req = URLRequest(url: r.remoteURL)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 20
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let f = try Forecast.decode(data)
            try? data.write(to: cacheURL(r), options: .atomic)
            guard r == region else { return }  // switched regions while this was loading
            forecast = f
            isStale = false
            status = .idle
        } catch {
            if r == region { status = .failed(error.localizedDescription) }
        }
    }

    func spot(_ id: String) -> Spot? { forecast?.spots.first { $0.id == id } }

    private func loadCache(_ r: Region) -> Forecast? {
        guard let data = try? Data(contentsOf: cacheURL(r)) else { return nil }
        return try? Forecast.decode(data)
    }

    /// Offline fallback for a fresh install. Only Florida ships a sample.
    static func bundledSample(_ r: Region = .florida) -> Forecast? {
        guard r == .florida, let url = Bundle.main.url(forResource: "SampleForecast", withExtension: "json"),
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
