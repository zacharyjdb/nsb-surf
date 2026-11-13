import SwiftUI

enum Theme {
    // Light, all-blue palette: cool white-blue background, white cards, one bright ocean blue, navy text.
    static let bg = Color(hex: 0xF1F5FB)          // cool white-blue
    static let card = Color.white
    static let cardRaised = Color(hex: 0xE7F0FD)  // pale blue chip
    static let divider = Color(hex: 0xE3E9F2)
    static let text = Color(hex: 0x0F1E3A)        // navy
    static let secondary = Color(hex: 0x6B7A90)   // blue-gray
    static let accent = Color(hex: 0x2F7CF6)      // bright ocean blue
    static let shadow = Color(hex: 0x1B3A6B).opacity(0.07)

    /// 0 Flat … 5 Epic, as deepening water: pale shallows to deep navy.
    static func rating(_ stars: Int) -> Color {
        switch stars {
        case ...0: return Color(hex: 0xD3DAE4)  // flat: gray
        case 1: return Color(hex: 0xB9D4F8)     // poor: shallow
        case 2: return Color(hex: 0x86B5F6)     // poor to fair
        case 3: return Color(hex: 0x4A90F0)     // fair
        case 4: return Color(hex: 0x2563EB)     // good
        default: return Color(hex: 0x1A3A8F)    // epic: deep water
        }
    }

    /// Text color that reads on top of a rating color.
    static func onRating(_ stars: Int) -> Color {
        stars <= 2 ? text : .white
    }

    static let ratingNames = ["Flat", "Poor", "Poor to fair", "Fair", "Good", "Epic"]
    static func ratingName(_ stars: Int) -> String { ratingNames[max(0, min(5, stars))] }

    static func wind(_ kind: String) -> Color {
        switch kind {
        case "glassy", "offshore": return Color(hex: 0x2563EB)
        case "cross-offshore": return Color(hex: 0x4A90F0)
        case "cross": return Color(hex: 0x7C8BA3)
        case "cross-onshore": return Color(hex: 0xD98A4E)
        case "onshore": return Color(hex: 0xD9534F)
        default: return secondary
        }
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
            .font(.system(size: 11, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(Theme.onRating(stars))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.rating(stars), in: Capsule())
    }
}

struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .heavy))
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
