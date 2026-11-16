// Renders the DUE EAST app icon (light, dark and tinted variants) at 1024x1024.
// The mark ("Swell panel"): a framed window onto a rolling swell with flowing contour lines,
// and a sun ring rising in the east (upper right). One ink color on paper
// (mood from design/inspo/mark-*.png; an original drawing).
// Run: swift design/icon/make_icon.swift <output dir>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

struct Palette {
    var paper: UInt32?   // nil = transparent (tinted)
    var ink: UInt32
}
let lightPal = Palette(paper: 0xECEAE4, ink: 0x171717)
let darkPal = Palette(paper: 0x171717, ink: 0xECE6D8)
let tintPal = Palette(paper: nil, ink: 0xFFFFFF)

let frame = CGRect(x: 214, y: 176, width: 596, height: 672)

/// Height of the swell's surface at x: one big crest left of center plus a smaller rolling sea.
func surface(_ x: CGFloat) -> CGFloat {
    let u = (x - frame.minX) / frame.width
    return 560 - 120 * exp(-pow((u - 0.34) / 0.2, 2)) + 26 * sin(u * 9)
}

/// Contour line k below the surface: follows the swell, flattening and drifting east with depth.
func contour(_ k: Int, _ x: CGFloat) -> CGFloat {
    let u = (x - frame.minX) / frame.width
    let off = CGFloat(k) * 54, flat = 1 - CGFloat(k) * 0.18
    return 560 + off - flat * (120 * exp(-pow((u - 0.34 - CGFloat(k) * 0.05) / 0.22, 2)) - 26 * sin(u * 9 + CGFloat(k) * 0.6))
}

func render(_ pal: Palette, to url: URL) {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)
    if let paper = pal.paper { ctx.setFillColor(rgb(paper)); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S)) }
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    let ink = rgb(pal.ink)

    // Frame
    ctx.setStrokeColor(ink); ctx.setLineWidth(22)
    ctx.addPath(CGPath(roundedRect: frame, cornerWidth: 26, cornerHeight: 26, transform: nil)); ctx.strokePath()

    // Sun ring, east
    ctx.setLineWidth(20)
    ctx.addEllipse(in: CGRect(x: 640, y: 262, width: 92, height: 92)); ctx.strokePath()

    // Swell body, clipped to the inside of the frame
    ctx.saveGState()
    // inset a little less than half the frame stroke, so the fill tucks under the frame line
    ctx.addPath(CGPath(roundedRect: frame.insetBy(dx: 6, dy: 6), cornerWidth: 20, cornerHeight: 20, transform: nil))
    ctx.clip()
    let body = CGMutablePath()
    var x = frame.minX
    body.move(to: CGPoint(x: x, y: surface(x)))
    while x < frame.maxX { x += 4; body.addLine(to: CGPoint(x: x, y: surface(x))) }
    body.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
    body.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
    body.closeSubpath()
    ctx.setFillColor(ink); ctx.addPath(body); ctx.fillPath()

    // Contour lines cut out of the swell (paper color, or clear for the tinted version)
    if pal.paper == nil { ctx.setBlendMode(.clear) }
    ctx.setStrokeColor(pal.paper.map { rgb($0) } ?? rgb(0x000000)); ctx.setLineWidth(13)
    for k in 1...4 {
        let p = CGMutablePath()
        var x = frame.minX - 10
        p.move(to: CGPoint(x: x, y: contour(k, x)))
        while x < frame.maxX + 10 { x += 4; p.addLine(to: CGPoint(x: x, y: contour(k, x))) }
        ctx.addPath(p); ctx.strokePath()
    }
    ctx.restoreGState()

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
