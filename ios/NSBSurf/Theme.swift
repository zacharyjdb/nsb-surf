import SwiftUI

enum Theme {
    // Light "beach morning" palette: off-white sand, sea-glass greens, ocean blues, deep-water navy text.
    static let bg = Color(hex: 0xF4F1EA)          // warm off-white
    static let card = Color(hex: 0xFFFDF8)        // paper white
    static let cardRaised = Color(hex: 0xE6F0EE)  // pale sea glass
    static let divider = Color(hex: 0xE2E3DC)
    static let text = Color(hex: 0x0E2A3B)        // deep-water navy
    static let secondary = Color(hex: 0x5F7480)   // slate
    static let accent = Color(hex: 0x1C6E9E)      // ocean blue
    static let shadow = Color(hex: 0x0E2A3B).opacity(0.07)

    /// 0 Flat … 5 Epic, from dry sand through sea glass to deep water.
    static func rating(_ stars: Int) -> Color {
        switch stars {
        case ...0: return Color(hex: 0xC3C8C6)  // flat: driftwood
        case 1: return Color(hex: 0xDCC39A)     // poor: wet sand
        case 2: return Color(hex: 0x9ED5C3)     // poor to fair: shallow seafoam
        case 3: return Color(hex: 0x3FAE8C)     // fair: sea glass
        case 4: return Color(hex: 0x16856F)     // good: deep teal-green
        default: return Color(hex: 0x1D5FA6)    // epic: deep blue
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
        case "glassy", "offshore": return Color(hex: 0x1F9470)
        case "cross-offshore": return Color(hex: 0x3FA284)
        case "cross": return Color(hex: 0xB98A1E)
        case "cross-onshore": return Color(hex: 0xD2693F)
        case "onshore": return Color(hex: 0xC2493A)
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
            .background(Theme.rating(stars), in: RoundedRectangle(cornerRadius: 4))
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
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: Theme.shadow, radius: 8, y: 2)
    }
}

extension Double {
    var oneDecimal: String { String(format: "%.1f", self) }
    var noDecimal: String { String(format: "%.0f", self) }
}
