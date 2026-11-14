import SwiftUI

/// Where to go: a spot, optionally opened on a given day.
struct SpotLink: Hashable {
    let spotID: String
    var date: String?
}

/// The landing screen: a welcome, the one day to target this week, and a few other good bets.
struct HomeView: View {
    @Environment(ForecastStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let f = store.forecast {
                        let target = Outlook.target(f)
                        header(target: target)
                        if let target {
                            NavigationLink(value: SpotLink(spotID: target.spot.id, date: target.day.date)) {
                                TargetCard(target: target, others: Outlook.spots(on: target.day.date, f))
                            }
                            .buttonStyle(.plain)
                        }
                        WeekGlance(days: Outlook.bestPerDay(f), target: target?.day.date)
                        BestBets(bets: Outlook.bestBets(f, excluding: target))
                        if let h = Outlook.horizon(f, beating: target) {
                            NavigationLink(value: SpotLink(spotID: h.spot.id, date: h.day.date)) {
                                HorizonCard(item: h)
                            }
                            .buttonStyle(.plain)
                        }
                        RightNow(spots: f.spots)
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.bg.ignoresSafeArea())
            .refreshable { await store.refresh() }
            .navigationDestination(for: SpotLink.self) { SpotDetailView(spotID: $0.spotID, date: $0.date) }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func header(target: SpotDay?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalTime.format(Date(), "EEEE, MMM d").uppercased())
                .font(.system(size: 12, weight: .heavy)).tracking(1)
                .foregroundStyle(Theme.secondary)
            Text(Outlook.greeting())
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Theme.text)
            Text(Outlook.verdict(target: target))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.secondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Day to target

struct TargetCard: View {
    let target: SpotDay
    let others: [SpotDay]

    var body: some View {
        let day = target.day
        let color = Theme.rating(target.stars)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("DAY TO TARGET", systemImage: "scope")
                    .font(.system(size: 12, weight: .heavy)).tracking(1)
                    .foregroundStyle(Theme.accent)
                Spacer()
                if day.confidence != "high" {
                    Text(day.isLowConfidence ? "TREND ONLY" : "MEDIUM CONFIDENCE")
                        .font(.system(size: 10, weight: .heavy)).tracking(0.6)
                        .foregroundStyle(Theme.secondary)
                }
            }

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(dayName(day))
                        .font(.system(size: 34, weight: .heavy))
                    Text(LocalTime.format(day.day, "MMMM d"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(day.surfLabel).font(.system(size: 34, weight: .heavy))
                        Text("ft").font(.system(size: 15, weight: .bold))
                    }
                    RatingPill(stars: target.stars)
                }
            }
            .foregroundStyle(Theme.text)

            VStack(alignment: .leading, spacing: 4) {
                Text(target.spot.name)
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.text)
                Text("\(day.headline) \(day.advice)")
                    .font(.system(size: 15)).foregroundStyle(Theme.secondary)
            }

            HStack(spacing: 0) {
                fact("BEST TIME", day.bestWindow.map { $0.isAllDay ? "All day" : $0.label } ?? "–")
                if let p = day.primary {
                    fact("SWELL", "\(p.heightFt.oneDecimal)ft \(p.periodS.noDecimal)s \(p.dirLabel)")
                }
                fact("WIND AM", "\(day.windAm.mph ?? 0) \(day.windAm.dirLabel)", color: Theme.windSpeedText(day.windAm.mph))
            }

            if others.count > 1 {
                Divider().overlay(Theme.divider)
                VStack(alignment: .leading, spacing: 8) {
                    Text("ALL SPOTS THAT DAY")
                        .font(.system(size: 11, weight: .heavy)).tracking(0.8)
                        .foregroundStyle(Theme.secondary)
                    ForEach(others) { o in
                        HStack(spacing: 8) {
                            Circle().fill(Theme.rating(o.stars)).frame(width: 8, height: 8).glow(o.stars)
                            Text(o.spot.name)
                                .font(.system(size: 14, weight: o.spot.id == target.spot.id ? .bold : .regular))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Text("\(o.day.surfLabel) ft")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Text("Open forecast")
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.accent)
        }
        .padding(18)
        .background {
            ZStack(alignment: .top) {
                Theme.card
                // Two layered waves across the top, like water in a glass.
                LinearGradient(colors: [Theme.cardRaised, Theme.cardRaised.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 132)
                WaveShape(level: 0.74, amplitude: 7, phase: .pi).fill(Theme.accent.opacity(0.14)).frame(height: 132)
                WaveShape(level: 0.86, amplitude: 6).fill(Theme.card).frame(height: 132)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .overlay(RoundedRectangle(cornerRadius: 24)
            .stroke(target.stars >= 4 ? color : Theme.accent.opacity(0.25), lineWidth: target.stars >= 4 ? 2 : 1))
        .shadow(color: target.stars >= 4 ? color.opacity(0.45) : Theme.shadow, radius: target.stars >= 4 ? 18 : 14, y: 5)
    }

    private func dayName(_ day: Day) -> String {
        let today = LocalTime.format(Date(), "yyyy-MM-dd")
        let tomorrow = LocalTime.format(Date().addingTimeInterval(86_400), "yyyy-MM-dd")
        if day.date == today { return "Today" }
        if day.date == tomorrow { return "Tomorrow" }
        return LocalTime.format(day.day, "EEEE")
    }

    private func fact(_ title: String, _ value: String, color: Color = Theme.text) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 10, weight: .heavy)).tracking(0.8).foregroundStyle(Theme.secondary)
            Text(value).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Week at a glance

/// Seven columns: the best rating anywhere each day, with the target day ringed.
struct WeekGlance: View {
    let days: [SpotDay]
    let target: String?

    var body: some View {
        Card(title: "This week, best spot each day") {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(days) { d in
                    let isTarget = d.day.date == target
                    NavigationLink(value: SpotLink(spotID: d.spot.id, date: d.day.date)) {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.rating(d.stars))
                                .frame(height: 10 + CGFloat(max(d.score, 0.3)) * 14)
                                .glow(d.stars)
                            Text(d.day.surfLabel)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.text)
                            Text(LocalTime.format(d.day.day, "EEE").uppercased())
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(isTarget ? Theme.text : Theme.secondary)
                        }
                        .padding(.vertical, 6).padding(.horizontal, 2)
                        .frame(maxWidth: .infinity)
                        .background(isTarget ? Theme.cardRaised : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(isTarget ? Theme.rating(d.stars) : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(LocalTime.format(d.day.day, "EEEE")), \(d.spot.name), \(d.day.surfLabel) feet, \(Theme.ratingName(d.stars))")
                }
            }
            .frame(height: 120, alignment: .bottom)
        }
    }
}

// MARK: - Best bets

struct BestBets: View {
    let bets: [SpotDay]

    var body: some View {
        Card(title: "Other best bets") {
            if bets.isEmpty {
                Text("Nothing else worth paddling out for this week.")
                    .font(.system(size: 15)).foregroundStyle(Theme.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(bets.enumerated()), id: \.element.id) { i, b in
                        NavigationLink(value: SpotLink(spotID: b.spot.id, date: b.day.date)) { row(b) }
                            .buttonStyle(.plain)
                        if i < bets.count - 1 { Divider().overlay(Theme.divider) }
                    }
                }
            }
        }
    }

    private func row(_ b: SpotDay) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(LocalTime.format(b.day.day, "EEE").uppercased())
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.secondary)
                Text(LocalTime.format(b.day.day, "d"))
                    .font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.text)
            }
            .frame(width: 40)
            Rectangle().fill(Theme.rating(b.stars)).frame(width: 4).clipShape(Capsule())
            VStack(alignment: .leading, spacing: 2) {
                Text(b.spot.name).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                Text([b.day.headline, b.day.bestWindow.flatMap { $0.isAllDay ? nil : "Best \($0.label)" }].compactMap { $0 }.joined(separator: " "))
                    .font(.system(size: 13)).foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(b.day.surfLabel) ft").font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.text)
                RatingPill(stars: b.stars)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - On the horizon

struct HorizonCard: View {
    let item: SpotDay
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "binoculars.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("ON THE HORIZON")
                    .font(.system(size: 11, weight: .heavy)).tracking(0.8).foregroundStyle(Theme.accent)
                Text("Possible \(item.day.surfLabel) ft around \(LocalTime.format(item.day.day, "EEE, MMM d")).")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                Text("Long range, so treat it as a heads-up, not a plan.")
                    .font(.system(size: 13)).foregroundStyle(Theme.secondary)
                RatingPill(stars: item.stars).padding(.top, 4)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(Theme.secondary)
        }
        .padding(16)
        .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Right now

struct RightNow: View {
    let spots: [Spot]
    var body: some View {
        let ranked = spots.compactMap { s in s.currentHour.map { (s, $0) } }.sorted { $0.1.score > $1.1.score }
        Card(title: "Right now") {
            VStack(spacing: 0) {
                ForEach(Array(ranked.enumerated()), id: \.element.0.id) { i, pair in
                    let (spot, h) = pair
                    NavigationLink(value: SpotLink(spotID: spot.id)) {
                        HStack(spacing: 10) {
                            Circle().fill(Theme.rating(h.stars)).frame(width: 8, height: 8).glow(h.stars)
                            Text(spot.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                HStack(spacing: 3) {
                                    DirectionArrow(from: h.windDir, size: 10, color: Theme.windSpeed(h.windMph))
                                    Text("\(h.windMph ?? 0) mph \(h.windDirLabel)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Theme.windSpeedText(h.windMph))
                                }
                                Text("\(Theme.windName(h.windKind)) wind")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.secondary)
                            }
                            Text("\(h.surfLabel) ft")
                                .font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.text)
                                .frame(width: 54, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if i < ranked.count - 1 { Divider().overlay(Theme.divider) }
                }
            }
        }
    }
}
