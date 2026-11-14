// Renders the NSB Surf app icon (light, dark and tinted variants) at 1024x1024.
// Style: flat, two colors, hand-drawn wave bands and a half sun, faint print grain
// (see design/inspo/icon-*.png).
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
    var bg: UInt32?      // nil = transparent (tinted)
    var ink: UInt32      // sun and waves
    var grain: CGFloat   // grain strength
}

let light = Palette(bg: 0x2F5FA8, ink: 0xF1EAD8, grain: 0.07)
let dark = Palette(bg: 0x0E1F3F, ink: 0xE9DFC6, grain: 0.06)
let tinted = Palette(bg: nil, ink: 0xFFFFFF, grain: 0)

/// Deterministic wobble so the lines look drawn by hand but render the same every time.
func wobble(_ x: CGFloat, _ seed: CGFloat) -> CGFloat {
    sin(x * 0.011 + seed) * 5 + sin(x * 0.027 + seed * 2.3) * 3
}

/// A wave band: a thick, round-capped stroke along a gently wobbling line, like a brush mark.
func band(y: CGFloat, amp: CGFloat, phase: CGFloat, x0: CGFloat, x1: CGFloat, seed: CGFloat) -> CGMutablePath {
    let p = CGMutablePath()
    var x = x0
    p.move(to: CGPoint(x: x, y: y + amp * sin((x / S) * .pi * 2.4 + phase) + wobble(x, seed) * 0.6))
    while x < x1 {
        x = min(x + 6, x1)
        p.addLine(to: CGPoint(x: x, y: y + amp * sin((x / S) * .pi * 2.4 + phase) + wobble(x, seed) * 0.6))
    }
    return p
}

func render(_ pal: Palette, to url: URL) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: S)
    ctx.scaleBy(x: 1, y: -1)

    if let bg = pal.bg {
        ctx.setFillColor(rgb(bg)); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
    }
    ctx.setFillColor(rgb(pal.ink))

    // Half sun sitting on the water.
    let sun = CGMutablePath()
    sun.addArc(center: CGPoint(x: 512, y: 440), radius: 190, startAngle: .pi, endAngle: 0, clockwise: false)
    sun.closeSubpath()
    ctx.addPath(sun); ctx.fillPath()

    // Wave bands, longer and thicker toward the viewer. The nearest one breaks into a curl.
    ctx.setStrokeColor(rgb(pal.ink))
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.setLineWidth(44); ctx.addPath(band(y: 505, amp: 8, phase: 0.4, x0: 340, x1: 684, seed: 1)); ctx.strokePath()
    ctx.setLineWidth(58); ctx.addPath(band(y: 615, amp: 14, phase: 1.6, x0: 230, x1: 640, seed: 4)); ctx.strokePath()
    let near = band(y: 745, amp: 18, phase: 3.0, x0: 150, x1: 700, seed: 7)
    let end = near.currentPoint
    near.addCurve(to: CGPoint(x: 868, y: 640), control1: CGPoint(x: end.x + 100, y: end.y + 8),
                  control2: CGPoint(x: 872, y: 700))
    near.addCurve(to: CGPoint(x: 772, y: 612), control1: CGPoint(x: 864, y: 575), control2: CGPoint(x: 790, y: 560))
    ctx.setLineWidth(72); ctx.addPath(near); ctx.strokePath()

    // Faint print grain.
    if pal.grain > 0 {
        var seed: UInt64 = 42
        func next() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(1 << 31) }
        for _ in 0..<26000 {
            let x = next() * S, y = next() * S, r = 0.8 + next() * 1.6
            ctx.setFillColor(next() < 0.5 ? rgb(0x000000, pal.grain) : rgb(0xFFFFFF, pal.grain))
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
        }
    }

    let img = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
render(light, to: out.appendingPathComponent("AppIcon.png"))
render(dark, to: out.appendingPathComponent("AppIcon-Dark.png"))
render(tinted, to: out.appendingPathComponent("AppIcon-Tinted.png"))
print("wrote icons to \(out.path)")
