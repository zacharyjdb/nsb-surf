import SwiftUI

enum Theme {
    static let bg = Color(hex: 0x0A1220)
    static let card = Color(hex: 0x121B2C)
    static let cardRaised = Color(hex: 0x1A2538)
    static let divider = Color(hex: 0x243049)
    static let text = Color.white
    static let secondary = Color(hex: 0x9AA7BD)
    static let accent = Color(hex: 0x41C7F9)

    /// 0 Flat … 5 Epic
    static func rating(_ stars: Int) -> Color {
        switch stars {
        case ...0: return Color(hex: 0x5B6472)
        case 1: return Color(hex: 0xE5484D)
        case 2: return Color(hex: 0xF28C28)
        case 3: return Color(hex: 0xF5C518)
        case 4: return Color(hex: 0x30A46C)
        default: return Color(hex: 0x3E8BFF)
        }
    }

    static let ratingNames = ["Flat", "Poor", "Poor to fair", "Fair", "Good", "Epic"]
    static func ratingName(_ stars: Int) -> String { ratingNames[max(0, min(5, stars))] }

    static func wind(_ kind: String) -> Color {
        switch kind {
        case "glassy", "offshore": return Color(hex: 0x30A46C)
        case "cross-offshore": return Color(hex: 0x7BC96F)
        case "cross": return Color(hex: 0xF5C518)
        case "cross-onshore": return Color(hex: 0xF28C28)
        case "onshore": return Color(hex: 0xE5484D)
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
            .foregroundStyle(stars == 3 ? Color.black : Color.white)
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
    }
}

extension Double {
    var oneDecimal: String { String(format: "%.1f", self) }
    var noDecimal: String { String(format: "%.0f", self) }
}
