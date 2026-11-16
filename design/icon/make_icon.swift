// Renders the DUE EAST app icon (light, dark and tinted variants) at 1024x1024.
// The mark: an original, hand-inked shark tooth in a screen-print style, black on off-white
// with grain (mood from design/inspo/due-east-*.png; not a copy of that artwork).
// Run: swift design/icon/make_icon.swift <output dir>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

struct Palette {
    var paper: UInt32?   // nil = transparent (tinted)
    var ink: UInt32
    var grain: CGFloat
}

let lightPal = Palette(paper: 0xF1EEE7, ink: 0x161616, grain: 0.08)
let darkPal = Palette(paper: 0x151515, ink: 0xEDE8DD, grain: 0.07)
let tintPal = Palette(paper: nil, ink: 0xFFFFFF, grain: 0)

// MARK: geometry helpers

func cubic(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    return CGPoint(x: u*u*u*p0.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*p1.x,
                   y: u*u*u*p0.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*p1.y)
}

/// Points along a cubic, with a small saw-tooth pushed outward to suggest serrations.
/// `outward` is the side (+1/-1) of the travel direction that faces away from the tooth.
func serrated(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint, outward: CGFloat,
              depth: CGFloat = 7, pitch: CGFloat = 16) -> [CGPoint] {
    var pts: [CGPoint] = []
    let steps = 400
    var travelled: CGFloat = 0
    var last = p0
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps)
        let p = cubic(p0, c1, c2, p1, t)
        let dx = p.x - last.x, dy = p.y - last.y
        let len = max(sqrt(dx*dx + dy*dy), 0.0001)
        travelled += len
        // Saw wave: rises over one pitch, drops sharply. Fades out near both ends.
        let phase = travelled.truncatingRemainder(dividingBy: pitch) / pitch
        let fade = min(t / 0.12, (1 - t) / 0.08, 1)
        let off = depth * phase * max(fade, 0)
        let nx = -dy / len * outward, ny = dx / len * outward
        pts.append(CGPoint(x: p.x + nx * off, y: p.y + ny * off))
        last = p
    }
    return pts
}

// MARK: the tooth (top-left coordinates)

/// The root: two rounded lobes with a notch in the middle, sitting on a flat base.
func rootPath() -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 206, y: 418))
    p.addCurve(to: CGPoint(x: 330, y: 268), control1: CGPoint(x: 196, y: 330), control2: CGPoint(x: 250, y: 272))
    p.addCurve(to: CGPoint(x: 512, y: 352), control1: CGPoint(x: 420, y: 262), control2: CGPoint(x: 480, y: 300))
    p.addCurve(to: CGPoint(x: 700, y: 262), control1: CGPoint(x: 548, y: 296), control2: CGPoint(x: 610, y: 256))
    p.addCurve(to: CGPoint(x: 820, y: 408), control1: CGPoint(x: 780, y: 268), control2: CGPoint(x: 830, y: 320))
    p.addCurve(to: CGPoint(x: 206, y: 418), control1: CGPoint(x: 640, y: 440), control2: CGPoint(x: 390, y: 446))
    p.closeSubpath()
    return p
}

/// The blade: narrower than the root, tall, with a tip that hooks east.
func bladePath() -> CGPath {
    let topL = CGPoint(x: 296, y: 460), topR = CGPoint(x: 732, y: 452)
    let tip = CGPoint(x: 608, y: 900)
    // left edge: full shoulder, then a long concave sweep into the hooked tip
    let left = serrated(topL, CGPoint(x: 380, y: 590), CGPoint(x: 520, y: 740), tip, outward: 1)
    // right edge from the tip back up: short and nearly straight
    let right = serrated(tip, CGPoint(x: 650, y: 790), CGPoint(x: 712, y: 620), topR, outward: 1)
    let p = CGMutablePath()
    p.addLines(between: left + right)
    p.addCurve(to: topL, control1: CGPoint(x: 600, y: 484), control2: CGPoint(x: 430, y: 488))
    p.closeSubpath()
    return p
}

func render(_ pal: Palette, to url: URL) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: S)
    ctx.scaleBy(x: 1, y: -1)

    if let paper = pal.paper {
        ctx.setFillColor(rgb(paper)); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
    }

    ctx.setFillColor(rgb(pal.ink))
    ctx.addPath(rootPath()); ctx.fillPath()
    ctx.addPath(bladePath()); ctx.fillPath()

    // Engraved highlights cut out of the ink: a sweep down the blade and a few hatch lines on the root.
    let cut = pal.paper.map { rgb($0) } ?? rgb(0x000000, 0)
    if pal.paper == nil { ctx.setBlendMode(.clear) }
    ctx.setStrokeColor(cut)
    ctx.setLineCap(.round)
    ctx.setLineWidth(16)
    let sweep = CGMutablePath()
    sweep.move(to: CGPoint(x: 572, y: 540))
    sweep.addCurve(to: CGPoint(x: 606, y: 830), control1: CGPoint(x: 612, y: 630), control2: CGPoint(x: 622, y: 740))
    ctx.addPath(sweep); ctx.strokePath()
    ctx.setLineWidth(9)
    let sweep2 = CGMutablePath()
    sweep2.move(to: CGPoint(x: 648, y: 540))
    sweep2.addCurve(to: CGPoint(x: 662, y: 690), control1: CGPoint(x: 668, y: 590), control2: CGPoint(x: 672, y: 640))
    ctx.addPath(sweep2); ctx.strokePath()
    ctx.setLineWidth(7)
    for (i, x) in stride(from: 268.0, through: 740.0, by: 40.0).enumerated() {
        let y0: CGFloat = (i % 2 == 0 ? 368 : 378) + (abs(CGFloat(i) - 6) < 2 ? 14 : 0)
        ctx.move(to: CGPoint(x: x, y: y0)); ctx.addLine(to: CGPoint(x: x + 14, y: y0 + 34))
    }
    ctx.strokePath()
    ctx.setBlendMode(.normal)

    // Screen-print grain: specks of paper in the ink and ink on the paper.
    if pal.grain > 0, let paper = pal.paper {
        var seed: UInt64 = 7
        func next() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(1 << 31) }
        for _ in 0..<30000 {
            let x = next() * S, y = next() * S, r = 0.8 + next() * 2.0
            ctx.setFillColor(next() < 0.6 ? rgb(paper, pal.grain * 2.2) : rgb(pal.ink, pal.grain))
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
        }
    }

    let img = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
render(lightPal, to: out.appendingPathComponent("AppIcon.png"))
render(darkPal, to: out.appendingPathComponent("AppIcon-Dark.png"))
render(tintPal, to: out.appendingPathComponent("AppIcon-Tinted.png"))
print("wrote icons to \(out.path)")
