import Charts
import SwiftUI

struct SpotDetailView: View {
    @Environment(ForecastStore.self) private var store
    let spotID: String
    @State private var selectedDate: String?

    init(spotID: String, date: String? = nil) {
        self.spotID = spotID
        _selectedDate = State(initialValue: date)
    }

    var body: some View {
        if let spot = store.spot(spotID) {
            let days = spot.upcomingDays
            let day = days.first { $0.date == selectedDate } ?? days.first
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    NowHeader(spot: spot)
                    DayPicker(spot: spot, days: days, selected: day?.date) { selectedDate = $0 }
                    if let day {
                        let hours = spot.hours(on: day)
                        DaySummaryCard(day: day)
                        SurfChartCard(day: day, hours: hours)
                        SwellCard(hour: representativeHour(hours: hours, day: day))
                        WindChartCard(hours: hours)
                        TideChartCard(day: day, hours: hours)
                    }
                    LongRangeCard(days: days, selected: day?.date) { selectedDate = $0 }
                    if let f = store.forecast, !f.buoys.isEmpty {
                        Card(title: "Live buoys") { BuoyList(buoys: f.buoys).padding(.horizontal, -16).padding(.vertical, -12) }
                    }
                    Text("Wave models: ECMWF to ~10 days, NOAA GFS-Wave after. Next 24 h corrected by the nearest buoy when it's reporting.")
                        .font(.footnote).foregroundStyle(Theme.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Theme.backdrop.ignoresSafeArea())
            .navigationTitle(spot.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .refreshable { await store.refresh() }
        } else {
            ContentUnavailableView("Spot not found", systemImage: "water.waves")
        }
    }

    /// Now for today, otherwise the best hour of the day.
    private func representativeHour(hours: [Hour], day: Day) -> Hour? {
        if day.date == LocalTime.format(Date(), "yyyy-MM-dd") {
            let now = Date()
            return hours.min { abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now)) }
        }
        return hours.max { $0.score < $1.score }
    }
}

// MARK: - Header

struct NowHeader: View {
    let spot: Spot
    var body: some View {
        let h = spot.currentHour
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(spot.subtitle.uppercased())
                    .font(.ui(12, .heavy)).tracking(1).foregroundStyle(Theme.secondary)
                    .padding(.bottom, 4)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text((h?.surfLabel ?? "–").shortDash).font(.num(80))
                    Text("ft").font(.ui(24, .bold))
                    Spacer()
                    RatingPill(stars: h?.stars ?? 0)
                }
                .foregroundStyle(Theme.text)
                Rectangle().fill(Theme.rating(h?.stars ?? 0)).frame(height: 4).clipShape(Capsule())
            }
            HStack(alignment: .top, spacing: 0) {
                stat("SWELL") {
                    if let p = h?.primary {
                        HStack(spacing: 4) {
                            DirectionArrow(from: p.dir, size: 12)
                            Text("\(p.heightFt.oneDecimal)ft")
                        }
                        Text("\(p.periodS.noDecimal)s \(p.dirLabel)").foregroundStyle(Theme.secondary)
                    } else { Text("–") }
                }
                stat("WIND") {
                    HStack(spacing: 4) {
                        DirectionArrow(from: h?.windDir, size: 12, color: Theme.windSpeed(h?.windMph))
                        Text("\(h?.windMph ?? 0) \(h?.windDirLabel ?? "")")
                    }
                    Text(Theme.windName(h?.windKind ?? "")).foregroundStyle(Theme.secondary)
                }
                stat("TIDE") {
                    Text("\(h?.tideFt?.oneDecimal ?? "–")ft")
                    if let t = spot.nextTide {
                        Text("\(t.isHigh ? "High" : "Low") \(t.label)").foregroundStyle(Theme.secondary)
                    }
                }
                stat("WATER") {
                    Text("\(h?.waterF.map(String.init) ?? "–")°F")
                }
            }
        }
        .padding(.top, 8)
    }

    private func stat<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.ui(11, .heavy)).tracking(0.8).foregroundStyle(Theme.secondary)
            c()
        }
        .font(.ui(15, .bold))
        .foregroundStyle(Theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Day picker

struct DayPicker: View {
    var spot: Spot? = nil
    let days: [Day]
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days) { d in
                    let isSel = d.date == selected
                    Button { onSelect(d.date) } label: {
                        VStack(spacing: 6) {
                            Text(LocalTime.format(d.day, "EEE").uppercased())
                                .font(.ui(11, .heavy))
                            Text(LocalTime.format(d.day, "d"))
                                .font(.num(24))
                            RoundedRectangle(cornerRadius: 2).fill(Theme.rating(d.stars)).frame(height: 4).glow(d.stars)
                            Text(d.surfLabel.shortDash).font(.num(15))
                            if let spot { WindTrio(hours: spot.hours(on: d), onDark: isSel) }
                        }
                        .foregroundStyle(isSel ? Theme.ink : Theme.text)
                        .frame(width: 52)
                        .padding(.vertical, 10)
                        .background(isSel ? Color.white : Theme.card, in: RoundedRectangle(cornerRadius: 10))
                        .opacity(d.isLowConfidence && !isSel ? 0.55 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(LocalTime.format(d.day, "EEEE MMMM d")), \(d.surfLabel) feet, \(d.rating)")
                    .id(d.date)
                }
            }
        }
        .onAppear { if let selected { proxy.scrollTo(selected, anchor: .center) } }
        }
    }
}

// MARK: - Day summary

struct DaySummaryCard: View {
    let day: Day
    var body: some View {
        Card {
            HStack {
                Text(LocalTime.format(day.day, "EEEE").uppercased())
                    .font(.ui(12, .heavy)).tracking(1).foregroundStyle(Theme.secondary)
                Spacer()
                if day.confidence != "high" {
                    Text(day.isLowConfidence ? "LONG RANGE · TREND ONLY" : "MEDIUM CONFIDENCE")
                        .font(.ui(10, .heavy)).tracking(0.6)
                        .foregroundStyle(day.isLowConfidence ? Theme.rating(2) : Theme.secondary)
                }
            }
            Text("\(day.headline) \(day.advice)")
                .font(.ui(22, .heavy)).foregroundStyle(Theme.text)
            Text(day.summary).font(.system(size: 15)).foregroundStyle(Theme.secondary)
            HStack(spacing: 16) {
                amPm("AM", day.starsAm, day.windAm)
                amPm("PM", day.starsPm, day.windPm)
                Spacer()
                if let w = day.bestWindow {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("BEST").font(.ui(10, .heavy)).foregroundStyle(Theme.secondary)
                        Text("\(LocalTime.shortHour(LocalTime.parse(w.start)))–\(LocalTime.shortHour(LocalTime.parse(w.end).addingTimeInterval(3600)))")
                            .font(.ui(15, .bold)).foregroundStyle(Theme.text)
                    }
                }
            }
        }
    }

    private func amPm(_ label: String, _ stars: Int, _ wind: Wind) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(Theme.rating(stars)).frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.ui(10, .heavy)).foregroundStyle(Theme.secondary)
                Text("\(wind.mph ?? 0) \(wind.dirLabel)").font(.ui(14, .bold))
                    .foregroundStyle(Theme.windSpeedText(wind.mph))
            }
        }
    }
}

// MARK: - Charts

private func hourAxis() -> some AxisContent {
    AxisMarks(values: .stride(by: .hour, count: 3)) { v in
        AxisGridLine().foregroundStyle(Theme.divider)
        AxisValueLabel {
            if let d = v.as(Date.self) {
                Text(LocalTime.shortHour(d)).font(.system(size: 10)).foregroundStyle(Theme.secondary)
            }
        }
    }
}

private func dayDomain(_ day: Day) -> ClosedRange<Date> {
    let start = LocalTime.parse(day.date + "T00:00")
    return start...start.addingTimeInterval(24 * 3600)
}

struct SurfChartCard: View {
    let day: Day
    let hours: [Hour]
    var body: some View {
        Card(title: "Surf height (ft)") {
            Chart(hours) { h in
                BarMark(x: .value("Hour", h.date, unit: .hour),
                        yStart: .value("Min", h.surfMinFt),
                        yEnd: .value("Max", max(h.surfMaxFt, h.surfMinFt + 0.15)),
                        width: .ratio(0.8))
                    .foregroundStyle(Theme.rating(h.stars))
                    .cornerRadius(2)
            }
            .chartXScale(domain: dayDomain(day))
            .chartXAxis { hourAxis() }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Theme.divider)
                    AxisValueLabel().foregroundStyle(Theme.secondary)
                }
            }
            .frame(height: 150)
            .opacity(day.isLowConfidence ? 0.6 : 1)
            RatingLegend()
        }
    }
}

struct RatingLegend: View {
    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { s in
                HStack(spacing: 4) {
                    Circle().fill(Theme.rating(s)).frame(width: 7, height: 7)
                    Text(Theme.ratingName(s)).font(.ui(10, .semibold)).foregroundStyle(Theme.secondary)
                }
            }
        }
    }
}

struct SwellCard: View {
    let hour: Hour?
    var body: some View {
        Card(title: "Swell\(hour.map { " · " + LocalTime.shortHour($0.date) } ?? "")") {
            if let trains = hour?.trains, !trains.isEmpty {
                ForEach(Array(trains.enumerated()), id: \.offset) { i, t in
                    HStack(spacing: 12) {
                        DirectionArrow(from: t.dir, size: 18, color: i == 0 ? Theme.text : Theme.secondary)
                            .frame(width: 24)
                        Text("\(t.heightFt.oneDecimal) ft").font(.ui(17, .heavy)).frame(width: 64, alignment: .leading)
                        Text("\(t.periodS.noDecimal)s").font(.ui(17, .bold)).frame(width: 40, alignment: .leading)
                        Text("\(t.dirLabel) \(t.dir.noDecimal)°").font(.system(size: 15))
                        Spacer()
                        Text(t.kind == "wind" ? "wind swell" : (i == 0 ? "primary" : "secondary"))
                            .font(.ui(12, .semibold)).foregroundStyle(Theme.secondary)
                    }
                    .foregroundStyle(i == 0 ? Theme.text : Theme.secondary)
                }
            } else {
                Text("No swell data").foregroundStyle(Theme.secondary)
            }
        }
    }
}

struct WindChartCard: View {
    let hours: [Hour]
    var body: some View {
        Card(title: "Wind (mph)") {
            Chart(hours) { h in
                BarMark(x: .value("Hour", h.date, unit: .hour), y: .value("mph", h.windMph ?? 0), width: .ratio(0.7))
                    .foregroundStyle(Theme.windSpeed(h.windMph))
                    .cornerRadius(2)
                    .annotation(position: .top, spacing: 2) {
                        if LocalTime.calendar.component(.hour, from: h.date) % 3 == 0 {
                            DirectionArrow(from: h.windDir, size: 9, color: Theme.windSpeedText(h.windMph))
                        }
                    }
                if let g = h.gustMph {
                    PointMark(x: .value("Hour", h.date, unit: .hour), y: .value("gust", g))
                        .symbolSize(14)
                        .foregroundStyle(Theme.windSpeed(g))
                }
            }
            .chartXAxis { hourAxis() }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Theme.divider)
                    AxisValueLabel().foregroundStyle(Theme.secondary)
                }
            }
            .frame(height: 140)
            HStack(spacing: 12) {
                WindSpeedLegend().frame(maxWidth: 220)
                HStack(spacing: 4) {
                    Circle().fill(Theme.secondary.opacity(0.7)).frame(width: 4, height: 4)
                    Text("Gusts").font(.ui(10, .semibold)).foregroundStyle(Theme.secondary)
                }
            }
        }
    }
}

struct TideChartCard: View {
    let day: Day
    let hours: [Hour]
    var body: some View {
        let pts = hours.filter { $0.tideFt != nil }
        let now = Date()
        let domain = dayDomain(day)
        Card(title: "Tide (ft)") {
            Chart {
                ForEach(pts) { h in
                    AreaMark(x: .value("Hour", h.date), y: .value("ft", h.tideFt ?? 0))
                        .foregroundStyle(Theme.accent.opacity(0.18))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Hour", h.date), y: .value("ft", h.tideFt ?? 0))
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(day.tides, id: \.t) { t in
                    PointMark(x: .value("Hour", t.date), y: .value("ft", t.ft))
                        .foregroundStyle(Theme.text)
                        .symbolSize(30)
                        .annotation(position: t.isHigh ? .top : .bottom, spacing: 4,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            Text("\(t.label) \(t.ft.oneDecimal)").font(.ui(10, .bold))
                                .foregroundStyle(Theme.text)
                        }
                }
                if domain.contains(now) {
                    RuleMark(x: .value("Now", now))
                        .foregroundStyle(Theme.text.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartXScale(domain: domain)
            .chartYScale(domain: -0.5...5.5)
            .chartXAxis { hourAxis() }
            .chartYAxis(.hidden)
            .frame(height: 140)
            HStack(spacing: 16) {
                Label(LocalTime.format(LocalTime.parse(day.sunrise), "h:mm a").lowercased(), systemImage: "sunrise.fill")
                Label(LocalTime.format(LocalTime.parse(day.sunset), "h:mm a").lowercased(), systemImage: "sunset.fill")
                Spacer()
                if let w = day.waterF { Label("\(w)°F", systemImage: "thermometer.medium") }
            }
            .font(.ui(12, .semibold))
            .foregroundStyle(Theme.secondary)
        }
    }
}

struct LongRangeCard: View {
    let days: [Day]
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        Card(title: "16-day outlook") {
            Chart(days) { d in
                BarMark(x: .value("Day", d.day, unit: .day),
                        yStart: .value("Min", d.surfMinFt),
                        yEnd: .value("Max", max(d.surfMaxFt, d.surfMinFt + 0.2)),
                        width: .ratio(0.7))
                    .foregroundStyle(Theme.rating(d.stars).opacity(d.isLowConfidence ? 0.45 : 1))
                    .cornerRadius(3)
                if d.date == selected {
                    RuleMark(x: .value("Day", d.day, unit: .day))
                        .foregroundStyle(Theme.text.opacity(0.15))
                        .lineStyle(StrokeStyle(lineWidth: 18))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { v in
                    AxisValueLabel {
                        if let d = v.as(Date.self) {
                            Text(LocalTime.format(d, "E d")).font(.system(size: 9)).foregroundStyle(Theme.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Theme.divider)
                    AxisValueLabel().foregroundStyle(Theme.secondary)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { loc in
                            guard let plot = proxy.plotFrame else { return }
                            let x = loc.x - geo[plot].origin.x
                            if let date: Date = proxy.value(atX: x) {
                                let key = LocalTime.format(date, "yyyy-MM-dd")
                                if days.contains(where: { $0.date == key }) { onSelect(key) }
                            }
                        }
                }
            }
            .frame(height: 140)
            Text("Faded bars are past day 7: useful for spotting a swell coming, not for planning a session.")
                .font(.system(size: 12)).foregroundStyle(Theme.secondary)
        }
    }
}

/// Three wind arrows for a day (9a, noon, 3p), colored by speed.
struct WindTrio: View {
    let hours: [Hour]
    var onDark = false
    var body: some View {
        HStack(spacing: 3) {
            ForEach([9, 12, 15], id: \.self) { hr in
                let h = hours.first { LocalTime.calendar.component(.hour, from: $0.date) == hr }
                DirectionArrow(from: h?.windDir, size: 10, color: Theme.windSpeed(h?.windMph))
            }
        }
        .padding(.horizontal, 3).padding(.vertical, 2)
        .background(onDark ? Theme.ink.opacity(0.85) : .clear, in: Capsule())
    }
}
