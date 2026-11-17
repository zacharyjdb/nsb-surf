import SwiftUI

struct SpotListView: View {
    @Environment(ForecastStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if let f = store.forecast {
                        ForEach(f.spots) { spot in
                            NavigationLink(value: spot) { SpotRow(spot: spot) }
                                .buttonStyle(.plain)
                        }
                        if !f.buoys.isEmpty {
                            Text("LIVE BUOYS")
                                .font(.ui(12, .heavy)).tracking(1)
                                .foregroundStyle(Theme.secondary)
                                .padding(.top, 12)
                            BuoyList(buoys: f.buoys)
                        }
                        footer(f)
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.backdrop.ignoresSafeArea())
            .refreshable { await store.refresh() }
            .navigationDestination(for: Spot.self) { spot in
                SpotDetailView(spotID: spot.id)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalTime.format(Date(), "EEEE, MMM d").uppercased())
                .font(.ui(12, .heavy)).tracking(1)
                .foregroundStyle(Theme.secondary)
            Text("Surf")
                .font(.ui(34, .heavy))
                .foregroundStyle(Theme.text)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func footer(_ f: Forecast) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let d = f.generatedAt {
                Text("Forecast updated \(d.formatted(.relative(presentation: .named)))")
            }
            if case .failed = store.status {
                Text("Offline. Showing the last saved forecast.")
                    .foregroundStyle(Theme.rating(2))
            }
        }
        .font(.footnote)
        .foregroundStyle(Theme.secondary)
        .padding(.top, 8)
    }
}

struct SpotRow: View {
    let spot: Spot

    var body: some View {
        let now = spot.currentHour
        let stars = now?.stars ?? 0
        HStack(spacing: 0) {
            Rectangle().fill(Theme.rating(stars)).frame(width: 6)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spot.name)
                            .font(.ui(19, .bold))
                            .foregroundStyle(Theme.text)
                        Text(spot.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text((now?.surfLabel ?? "–").shortDash)
                                .font(.num(36))
                            Text("ft").font(.ui(14, .bold))
                        }
                        .foregroundStyle(Theme.text)
                        RatingPill(stars: stars)
                    }
                }
                HStack(spacing: 14) {
                    if let p = now?.primary {
                        Label {
                            Text("\(p.heightFt.oneDecimal)ft \(p.periodS.noDecimal)s \(p.dirLabel)")
                        } icon: { DirectionArrow(from: p.dir, size: 11, color: Theme.secondary) }
                    }
                    if let n = now {
                        Label {
                            Text("\(n.windMph ?? 0) \(n.windDirLabel)")
                        } icon: { DirectionArrow(from: n.windDir, size: 11, color: Theme.windSpeed(n.windMph)) }
                        .foregroundStyle(Theme.windSpeedText(n.windMph))
                    }
                    Spacer()
                }
                .font(.ui(13, .semibold))
                .foregroundStyle(Theme.secondary)
                WeekStrip(days: Array(spot.upcomingDays.prefix(7)))
            }
            .padding(14)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Theme.shadow, radius: 8, y: 2)
        .accessibilityElement(children: .combine)
    }
}

/// Seven small rating bars, one per day.
struct WeekStrip: View {
    let days: [Day]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(days) { d in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.rating(d.stars))
                        .frame(height: 5)
                    Text(LocalTime.format(d.day, "EEEEE"))
                        .font(.ui(10, .bold))
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
    }
}

struct BuoyList: View {
    let buoys: [Buoy]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(buoys.enumerated()), id: \.element.id) { i, b in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.name).font(.ui(15, .semibold)).foregroundStyle(Theme.text)
                        Text("NDBC \(b.id)\(b.observedAt.map { " · " + $0.formatted(.relative(presentation: .named)) } ?? "")")
                            .font(.system(size: 12)).foregroundStyle(Theme.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 6) {
                            DirectionArrow(from: b.meanDir, size: 12, color: Theme.secondary)
                            Text("\(b.waveFt?.oneDecimal ?? "–") ft @ \(b.dominantPeriodS?.noDecimal ?? "–")s")
                                .font(.ui(15, .bold)).foregroundStyle(Theme.text)
                        }
                        if let w = b.waterF {
                            Text("\(w)° water").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                        }
                    }
                }
                .padding(.vertical, 12)
                if i < buoys.count - 1 { Divider().overlay(Theme.divider) }
            }
        }
        .padding(.horizontal, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Theme.shadow, radius: 8, y: 2)
    }
}
