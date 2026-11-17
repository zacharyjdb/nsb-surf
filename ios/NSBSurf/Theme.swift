import SwiftUI

enum Theme {
    // Ocean blue and white: a blue gradient backdrop, white text, see-through lighter-blue cards,
    // and an aqua accent (tide lines, links).
    static let bgTop: UInt32 = 0x3A79B8, bgBottom: UInt32 = 0x1B3F6B
    static let bg = Color(hex: bgTop)             // solid stand-in (nav bar)
    static let backdrop = LinearGradient(colors: [Color(hex: bgTop), Color(hex: bgBottom)],
                                         startPoint: .top, endPoint: .bottom)
    static let card = Color.white.opacity(0.11)
    static let cardRaised = Color.white.opacity(0.18)
    static let divider = Color.white.opacity(0.14)
    static let text = Color.white
    static let secondary = Color(hex: 0xBFD3EA)   // pale blue-white
    static let accent = Color(hex: 0x8BE3F5)      // aqua
    static let ink = Color(hex: 0x10274A)         // deep navy, for text on light chips
    static let shadow = Color.black.opacity(0.14)

    /// 0 Flat … 5 Epic. The one place the blue theme gives way: bad is red/amber, fair is yellow, good is green.
    static func rating(_ stars: Int) -> Color {
        switch stars {
        case ...0: return Color(hex: 0xC5CDD8)  // flat: gray
        case 1: return Color(hex: 0xE5534B)     // poor: red
        case 2: return Color(hex: 0xF29A38)     // poor to fair: amber
        case 3: return Color(hex: 0xF2C94C)     // fair: yellow
        case 4: return Color(hex: 0x22B573)     // good: green
        default: return Color(hex: 0x0FCB7E)    // epic: bright green, bigger glow
        }
    }

    /// Text color that reads on top of a rating color.
    static func onRating(_ stars: Int) -> Color {
        (stars == 2 || stars == 3 || stars <= 0) ? ink : .white
    }

    /// Good and epic surf glows; everything else sits flat.
    static func glowRadius(_ stars: Int) -> CGFloat {
        stars >= 5 ? 12 : (stars == 4 ? 7 : 0)
    }

    static let ratingNames = ["Flat", "Poor", "Poor to fair", "Fair", "Good", "Epic"]
    static func ratingName(_ stars: Int) -> String { ratingNames[max(0, min(5, stars))] }

    /// Wind colored by speed, Windy-style: one smooth ramp from calm to howling.
    /// Direction (offshore, onshore…) is shown in words; color is strength.
    static let windStops: [(mph: Double, hex: UInt32)] = [
        (0, 0x9DB2EC),   // calm: periwinkle
        (4, 0x5B8DEF),   // light: blue
        (8, 0x2DB3B5),   // gentle: teal
        (12, 0x45BF63),  // moderate: green
        (16, 0xD9C531),  // fresh: yellow
        (20, 0xF08A2C),  // strong: orange
        (26, 0xE0473D),  // very strong: red
        (34, 0xB0399C),  // gale: magenta
    ]

    static func windSpeed(_ mph: Double?) -> Color {
        let v = max(0, mph ?? 0)
        let stops = windStops
        guard let hi = stops.firstIndex(where: { $0.mph >= v }) else { return Color(hex: stops.last!.hex) }
        if hi == 0 { return Color(hex: stops[0].hex) }
        let a = stops[hi - 1], b = stops[hi]
        let t = (v - a.mph) / (b.mph - a.mph)
        return Color(mix: a.hex, b.hex, t)
    }

    static func windSpeed(_ mph: Int?) -> Color { windSpeed(mph.map(Double.init)) }

    /// The same ramp, lightened a touch so it reads as text on the blue backdrop.
    static func windSpeedText(_ mph: Int?) -> Color {
        let v = Double(max(0, mph ?? 0))
        let stops = windStops
        let hi = stops.firstIndex(where: { $0.mph >= v }) ?? stops.count - 1
        let lo = max(0, hi - 1)
        let t = hi == lo ? 0 : min(1, (v - stops[lo].mph) / (stops[hi].mph - stops[lo].mph))
        return Color(mix: stops[lo].hex, stops[hi].hex, t, lighten: 0.45)
    }

    static func windName(_ kind: String) -> String {
        switch kind {
        case "glassy": return "Glassy"
        case "offshore": return "Offshore"
        case "cross-offshore": return "Cross-off"
        case "cross": return "Cross"
        case "cross-onshore": return "Cross-on"
        case "onshore": return "Onshore"
        default: return "–"
        }
    }
}

extension Color {
    /// Linear blend of two hex colors, optionally lightened toward white.
    init(mix a: UInt32, _ b: UInt32, _ t: Double, lighten: Double = 0) {
        func ch(_ h: UInt32, _ shift: UInt32) -> Double { Double((h >> shift) & 0xFF) / 255 }
        let k = max(0, min(1, t))
        func c(_ shift: UInt32) -> Double {
            let v = ch(a, shift) + (ch(b, shift) - ch(a, shift)) * k
            return v + (1 - v) * lighten
        }
        self.init(.sRGB, red: c(16), green: c(8), blue: c(0))
    }

    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - Small shared pieces

/// Arrow showing where swell or wind is travelling. `from` is the compass bearing it comes from.
struct DirectionArrow: View {
    let from: Double?
    var size: CGFloat = 14
    var color: Color = Theme.text

    var body: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(color)
            .rotationEffect(.degrees(from ?? 0))
            .opacity(from == nil ? 0 : 1)
            .accessibilityHidden(true)
    }
}

struct RatingPill: View {
    let stars: Int
    var body: some View {
        Text(Theme.ratingName(stars).uppercased())
            .font(.ui(11, .heavy))
            .tracking(0.6)
            .foregroundStyle(Theme.onRating(stars))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.rating(stars), in: Capsule())
            .glow(stars)
    }
}

struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(.ui(12, .heavy))
                    .tracking(1)
                    .foregroundStyle(Theme.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: Theme.shadow, radius: 12, y: 4)
    }
}

extension Double {
    var oneDecimal: String { String(format: "%.1f", self) }
    var noDecimal: String { String(format: "%.0f", self) }
}

/// A soft wave band, used behind hero numbers (filled from the wave down).
struct WaveShape: Shape {
    var level: CGFloat = 0.6   // 0 = top, 1 = bottom
    var amplitude: CGFloat = 8
    var phase: CGFloat = 0
    func path(in r: CGRect) -> Path {
        var p = Path()
        let y = r.minY + r.height * level
        p.move(to: CGPoint(x: r.minX, y: y))
        let steps = 48
        for i in 0...steps {
            let x = r.minX + r.width * CGFloat(i) / CGFloat(steps)
            let yy = y + sin(CGFloat(i) / CGFloat(steps) * .pi * 2.4 + phase) * amplitude
            p.addLine(to: CGPoint(x: x, y: yy))
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

extension View {
    /// A soft halo in the rating color for good and epic surf.
    func glow(_ stars: Int) -> some View {
        let r = Theme.glowRadius(stars)
        return shadow(color: r > 0 ? Theme.rating(stars).opacity(0.6) : .clear, radius: r)
    }
}

/// Windy-style legend: the speed ramp with a few mph ticks.
struct WindSpeedLegend: View {
    var body: some View {
        VStack(spacing: 3) {
            LinearGradient(stops: Theme.windStops.map {
                .init(color: Color(hex: $0.hex), location: $0.mph / 34)
            }, startPoint: .leading, endPoint: .trailing)
            .frame(height: 6)
            .clipShape(Capsule())
            HStack {
                ForEach([0, 8, 16, 26, 34], id: \.self) { v in
                    Text(v == 34 ? "34+" : "\(v)")
                    if v != 34 { Spacer() }
                }
            }
            .font(.ui(9, .semibold))
            .foregroundStyle(Theme.secondary)
        }
    }
}

// MARK: - Type

extension Font {
    /// The app's type: squared-off DIN for anything bold, the system font for plain text.
    /// Black and big heavy text (headlines, hero numbers) use DIN Condensed, scaled up since it runs narrow;
    /// small heavy labels and bold values use DIN Alternate. Both ship with iOS.
    /// Surf numbers: heavy, blocky and tight (SF Pro Black, condensed width), with chunky digits.
    static func num(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.condensed)
    }

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .black:
            return .custom("DINCondensed-Bold", fixedSize: size * 1.25)
        case .heavy where size >= 18:
            return .custom("DINCondensed-Bold", fixedSize: size * 1.25)
        case .heavy, .bold:
            return .custom("DINAlternate-Bold", fixedSize: size)
        default:
            return .system(size: size, weight: weight)
        }
    }
}

extension String {
    /// A surf range with a short hyphen instead of the long en dash ("4-8" not "4–8"), so the
    /// numbers carry the weight. Number displays only; prose keeps proper punctuation.
    var shortDash: String { replacingOccurrences(of: "–", with: "-") }
}
