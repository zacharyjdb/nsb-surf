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
                                TargetCard(target: target)
                            }
                            .buttonStyle(.plain)
                        }
                        RightNow(spots: f.spots)
                        WeekGlance(days: Outlook.bestPerDay(f), target: target?.day.date)
                        BestBets(bets: Outlook.bestBets(f, excluding: target))
                        if let h = Outlook.horizon(f, beating: target) {
                            NavigationLink(value: SpotLink(spotID: h.spot.id, date: h.day.date)) {
                                HorizonCard(item: h)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.backdrop.ignoresSafeArea())
            .refreshable { await store.refresh() }
            .navigationDestination(for: SpotLink.self) { SpotDetailView(spotID: $0.spotID, date: $0.date) }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func header(target: SpotDay?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalTime.format(Date(), "EEEE, MMM d").uppercased())
                .font(.ui(12, .heavy)).tracking(1)
                .foregroundStyle(Theme.secondary)
            Text(Outlook.greeting())
                .font(.ui(34, .heavy))
                .foregroundStyle(Theme.text)
            Text(Outlook.verdict(target: target))
                .font(.ui(17, .medium))
                .foregroundStyle(Theme.secondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Day to target

struct TargetCard: View {
    let target: SpotDay

    var body: some View {
        let day = target.day
        let color = Theme.rating(target.stars)
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("DAY TO TARGET", systemImage: "scope")
                    .font(.ui(12, .heavy)).tracking(1)
                    .foregroundStyle(Theme.accent)
                Spacer()
                if day.confidence != "high" {
                    Text(day.isLowConfidence ? "TREND ONLY" : "MEDIUM CONFIDENCE")
                        .font(.ui(10, .heavy)).tracking(0.6)
                        .foregroundStyle(Theme.secondary)
                }
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayName(day))
                        .font(.ui(38, .black))
                    Text(LocalTime.format(day.day, "MMMM d"))
                        .font(.ui(15, .semibold))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(day.surfLabel.shortDash).font(.num(46))
                        Text("ft").font(.ui(15, .bold))
                    }
                    RatingPill(stars: target.stars)
                }
            }
            .foregroundStyle(Theme.text)

            // The best spot that day, highlighted in its rating color.
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 1) {
                    Text("BEST SPOT")
                        .font(.ui(10, .heavy)).tracking(0.8)
                        .foregroundStyle(Theme.secondary)
                    Text(target.spot.name)
                        .font(.ui(18, .bold))
                        .foregroundStyle(Theme.text)
                }
                Spacer()
            }
            .padding(12)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.55), lineWidth: 1))

            Text("\(day.headline) \(day.advice)")
                .font(.system(size: 15)).foregroundStyle(Theme.secondary)

            HStack(spacing: 0) {
                fact("BEST TIME", day.bestWindow.map { $0.isAllDay ? "All day" : $0.label } ?? "–")
                if let p = day.primary {
                    fact("SWELL", "\(p.heightFt.oneDecimal)ft \(p.periodS.noDecimal)s \(p.dirLabel)")
                }
                fact("WIND AM", "\(day.windAm.mph ?? 0) \(day.windAm.dirLabel)", color: Theme.windSpeedText(day.windAm.mph))
            }

            HStack {
                Spacer()
                Text("Open forecast")
                Image(systemName: "chevron.right")
            }
            .font(.ui(13, .bold))
            .foregroundStyle(Theme.accent)
        }
        .padding(18)
        .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 24))
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
            Text(title).font(.ui(10, .heavy)).tracking(0.8).foregroundStyle(Theme.secondary)
            Text(value).font(.ui(14, .bold)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Week at a glance

/// This week, always Sunday to Saturday: the best rating anywhere each day, with the target day ringed.
/// Days already gone drop out of the forecast, so the last forecast seen for them is kept on the phone
/// (WeekHistory) and shown in gray.
struct WeekGlance: View {
    let days: [SpotDay]
    let target: String?
    @State private var past: [String: WeekHistory.Entry] = WeekHistory.load()

    var body: some View {
        let byDate = Dictionary(days.map { ($0.day.date, $0) }, uniquingKeysWith: { a, _ in a })
        let cal = LocalTime.calendar
        let today = cal.startOfDay(for: Date())
        let sunday = cal.date(byAdding: .day, value: 1 - cal.component(.weekday, from: today), to: today)!
        let week = (0..<7).map { cal.date(byAdding: .day, value: $0, to: sunday)! }
        Card(title: "This week, best spot each day") {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(week, id: \.self) { date in
                    let key = LocalTime.format(date, "yyyy-MM-dd")
                    if let d = byDate[key] {
                        column(d, isTarget: key == target, isToday: date == today)
                    } else if let e = past[key] {
                        pastColumn(e, date)
                    } else {
                        placeholder(date)
                    }
                }
            }
            .frame(height: 120, alignment: .bottom)
        }
        .task(id: days.map(\.id)) {
            WeekHistory.record(days)
            past = WeekHistory.load()
        }
    }

    private func column(_ d: SpotDay, isTarget: Bool, isToday: Bool) -> some View {
        NavigationLink(value: SpotLink(spotID: d.spot.id, date: d.day.date)) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.rating(d.stars))
                    .frame(height: 10 + CGFloat(max(d.score, 0.3)) * 14)
                    .glow(d.stars)
                Text(d.day.surfLabel.shortDash)
                    .font(.num(14))
                    .foregroundStyle(Theme.text)
                dayLabel(d.day.day, highlight: isTarget || isToday)
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

    /// A day that has passed: its last forecast height, all in gray.
    private func pastColumn(_ e: WeekHistory.Entry, _ date: Date) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.secondary.opacity(0.35))
                .frame(height: 10 + CGFloat(max(e.score, 0.3)) * 14)
            Text(e.surfLabel.shortDash)
                .font(.num(14))
                .foregroundStyle(Theme.secondary)
            dayLabel(date, highlight: false)
        }
        .padding(.vertical, 6).padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .opacity(0.7)
        .accessibilityLabel("\(LocalTime.format(date, "EEEE")), past, \(e.surfLabel) feet")
    }

    private func placeholder(_ date: Date) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(Theme.divider).frame(height: 4)
            Text("–").font(.ui(11, .bold)).foregroundStyle(Theme.secondary)
            dayLabel(date, highlight: false)
        }
        .padding(.vertical, 6).padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .opacity(0.45)
        .accessibilityLabel("\(LocalTime.format(date, "EEEE")), past")
    }

    private func dayLabel(_ date: Date, highlight: Bool) -> some View {
        Text(LocalTime.format(date, "EEE").uppercased())
            .font(.ui(10, .heavy))
            .foregroundStyle(highlight ? Theme.text : Theme.secondary)
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
                    .font(.ui(11, .heavy)).foregroundStyle(Theme.secondary)
                Text(LocalTime.format(b.day.day, "d"))
                    .font(.num(24)).foregroundStyle(Theme.text)
            }
            .frame(width: 40)
            Rectangle().fill(Theme.rating(b.stars)).frame(width: 4).clipShape(Capsule())
            VStack(alignment: .leading, spacing: 2) {
                Text(b.spot.name).font(.ui(15, .bold)).foregroundStyle(Theme.text)
                Text([b.day.headline, b.day.bestWindow.flatMap { $0.isAllDay ? nil : "Best \($0.label)" }].compactMap { $0 }.joined(separator: " "))
                    .font(.system(size: 13)).foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(b.day.surfLabel.shortDash) ft").font(.num(18)).foregroundStyle(Theme.text)
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
                    .font(.ui(11, .heavy)).tracking(0.8).foregroundStyle(Theme.accent)
                Text("Possible \(item.day.surfLabel) ft around \(LocalTime.format(item.day.day, "EEE, MMM d")).")
                    .font(.ui(15, .bold)).foregroundStyle(Theme.text)
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
                            Text(spot.name).font(.ui(15, .semibold)).foregroundStyle(Theme.text)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                HStack(spacing: 3) {
                                    DirectionArrow(from: h.windDir, size: 10, color: Theme.windSpeed(h.windMph))
                                    Text("\(h.windMph ?? 0) mph \(h.windDirLabel)")
                                        .font(.ui(12, .bold))
                                        .foregroundStyle(Theme.windSpeedText(h.windMph))
                                }
                                Text("\(Theme.windName(h.windKind)) wind")
                                    .font(.ui(10, .semibold))
                                    .foregroundStyle(Theme.secondary)
                            }
                            Text("\(h.surfLabel.shortDash) ft")
                                .font(.num(18)).foregroundStyle(Theme.text)
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

// MARK: - Week history

/// Remembers the best spot's forecast for each day, so days that have passed (and dropped out of the
/// forecast) can still show in the week chart. Kept in UserDefaults on this phone; two weeks of entries.
enum WeekHistory {
    struct Entry: Codable {
        let surfLabel: String
        let score: Double
    }

    private static let key = "weekHistory.v1"

    static func load() -> [String: Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let all = try? JSONDecoder().decode([String: Entry].self, from: data) else { return [:] }
        return all
    }

    /// Stores the latest forecast for each upcoming day (newer forecasts overwrite older ones) and
    /// drops anything more than two weeks old.
    static func record(_ days: [SpotDay]) {
        var all = load()
        for d in days { all[d.day.date] = Entry(surfLabel: d.day.surfLabel, score: d.score) }
        let cutoff = LocalTime.format(Date().addingTimeInterval(-14 * 86_400), "yyyy-MM-dd")
        all = all.filter { $0.key >= cutoff }
        if let data = try? JSONEncoder().encode(all) { UserDefaults.standard.set(data, forKey: key) }
    }
}
