// Compass-bearing icon mockups for DUE EAST: four directions, all heading due east (090°).
// Writes A.png ... D.png at 1024px plus sheet.png (all four as rounded icons, side by side).
// Run: swift design/icon/compass_mockups.swift <output dir>
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024
let C = CGPoint(x: S / 2, y: S / 2)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let white = rgb(0xFFFFFF)

/// A compass bearing (0 = north, 90 = east, clockwise) at radius r from the center, top-left coordinates.
func polar(_ deg: CGFloat, _ r: CGFloat, _ c: CGPoint = C) -> CGPoint {
    let a = deg * .pi / 180
    return CGPoint(x: c.x + r * sin(a), y: c.y - r * cos(a))
}

/// Arc along bearings from a to b (clockwise on the compass), as a stroked path.
func arc(_ r: CGFloat, from a: CGFloat, to b: CGFloat) -> CGPath {
    let p = CGMutablePath()
    var d = a
    p.move(to: polar(d, r))
    while d < b { d = min(d + 1, b); p.addLine(to: polar(d, r)) }
    return p
}

func canvas(_ bgTop: UInt32, _ bgBottom: UInt32) -> CGContext {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)
    let g = CGGradient(colorsSpace: space, colors: [rgb(bgTop), rgb(bgBottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: S), options: [])
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    return ctx
}

func fillTriangle(_ ctx: CGContext, _ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ color: CGColor) {
    ctx.setFillColor(color)
    ctx.move(to: a); ctx.addLine(to: b); ctx.addLine(to: c); ctx.closePath(); ctx.fillPath()
}

// A — Dial: a tick bezel like a compass app, crosshair center, heading marker at east.
func dial() -> CGImage {
    let ctx = canvas(0x9BBCE2, 0x7FA4D2)
    for i in 0..<72 {
        let d = CGFloat(i) * 5
        let major = i % 6 == 0
        let isEast = d == 90
        ctx.setStrokeColor(isEast ? white : rgb(0xFFFFFF, major ? 0.95 : 0.6))
        ctx.setLineWidth(isEast ? 22 : (major ? 14 : 8))
        ctx.move(to: polar(d, isEast ? 262 : (major ? 278 : 296)))
        ctx.addLine(to: polar(d, 330))
        ctx.strokePath()
    }
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.85)); ctx.setLineWidth(10)
    ctx.move(to: polar(0, 120)); ctx.addLine(to: polar(180, 120))
    ctx.move(to: polar(270, 120)); ctx.addLine(to: polar(90, 120))
    ctx.strokePath()
    // heading marker outside the bezel, pointing east
    fillTriangle(ctx, polar(90, 432), polar(78, 368), polar(102, 368), white)
    return ctx.makeImage()!
}

// B — Needle: a classic compass needle lying east–west, east half white, inside a thin ring.
func needle() -> CGImage {
    let ctx = canvas(0x34507E, 0x223962)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.9)); ctx.setLineWidth(16)
    ctx.addEllipse(in: CGRect(x: C.x - 340, y: C.y - 340, width: 680, height: 680)); ctx.strokePath()
    for d in stride(from: 0.0, to: 360.0, by: 90.0) {
        ctx.setLineWidth(d == 90 ? 24 : 14)
        ctx.move(to: polar(d, 284)); ctx.addLine(to: polar(d, 340)); ctx.strokePath()
    }
    for d in stride(from: 45.0, to: 360.0, by: 90.0) {
        ctx.setLineWidth(10); ctx.setStrokeColor(rgb(0xFFFFFF, 0.55))
        ctx.move(to: polar(d, 306)); ctx.addLine(to: polar(d, 340)); ctx.strokePath()
    }
    let tipE = polar(90, 250), tipW = polar(270, 250), up = polar(0, 64), down = polar(180, 64)
    fillTriangle(ctx, tipE, up, down, white)
    fillTriangle(ctx, tipW, up, down, rgb(0x8DB0E0))
    ctx.setFillColor(rgb(0x2A4470))
    ctx.fillEllipse(in: CGRect(x: C.x - 26, y: C.y - 26, width: 52, height: 52))
    return ctx.makeImage()!
}

// C — Arcs: rounded concentric arcs that all open to the east, with a dot heading out through the gap.
func arcs() -> CGImage {
    let ctx = canvas(0x9DB0C8, 0x8299B8)
    ctx.setStrokeColor(white)
    for (r, w, gap) in [(318.0, 54.0, 34.0), (214.0, 50.0, 46.0), (112.0, 48.0, 70.0)] as [(CGFloat, CGFloat, CGFloat)] {
        ctx.setLineWidth(w)
        ctx.addPath(arc(r, from: 90 + gap, to: 450 - gap)); ctx.strokePath()
    }
    ctx.setFillColor(white)
    ctx.fillEllipse(in: CGRect(x: C.x - 34, y: C.y - 34, width: 68, height: 68))
    let dot = polar(90, 318)
    ctx.fillEllipse(in: CGRect(x: dot.x - 42, y: dot.y - 42, width: 84, height: 84))
    return ctx.makeImage()!
}

// D — Heading arrow: a bold navigation arrow pointing east inside a heavy bezel with a notch at 090.
func arrow() -> CGImage {
    let ctx = canvas(0x3F74C0, 0x2B5699)
    ctx.setStrokeColor(white); ctx.setLineWidth(38)
    ctx.addPath(arc(330, from: 104, to: 436)); ctx.strokePath()
    // marker in the notch
    ctx.setFillColor(white)
    let m = polar(90, 330)
    ctx.fillEllipse(in: CGRect(x: m.x - 22, y: m.y - 22, width: 44, height: 44))
    // navigation arrow, pointing east
    let p = CGMutablePath()
    p.move(to: polar(90, 220))
    p.addLine(to: polar(222, 210))
    p.addLine(to: polar(270, 62))
    p.addLine(to: polar(318, 210))
    p.closeSubpath()
    ctx.addPath(p); ctx.fillPath()
    return ctx.makeImage()!
}

func save(_ img: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let mocks: [(String, String, CGImage)] = [("A", "Dial", dial()), ("B", "Needle", needle()),
                                          ("C", "Arcs", arcs()), ("D", "Heading arrow", arrow())]
for (k, _, img) in mocks { save(img, out.appendingPathComponent("\(k).png")) }

// Contact sheet: four rounded icons in a row with labels.
let tile: CGFloat = 360, pad: CGFloat = 60, labelH: CGFloat = 70
let W = pad + CGFloat(mocks.count) * (tile + pad), H = pad + tile + labelH + pad / 2
let sheet = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
sheet.setFillColor(rgb(0xF4F6FA)); sheet.fill(CGRect(x: 0, y: 0, width: W, height: H))
let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 30, nil)
for (i, (k, name, img)) in mocks.enumerated() {
    let x = pad + CGFloat(i) * (tile + pad)
    let rect = CGRect(x: x, y: H - pad - tile, width: tile, height: tile)
    sheet.saveGState()
    sheet.addPath(CGPath(roundedRect: rect, cornerWidth: tile * 0.225, cornerHeight: tile * 0.225, transform: nil))
    sheet.clip(); sheet.draw(img, in: rect); sheet.restoreGState()
    let str = NSAttributedString(string: "\(k)  \(name)", attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): rgb(0x2A3550)])
    let line = CTLineCreateWithAttributedString(str)
    let w = CTLineGetTypographicBounds(line, nil, nil, nil)
    sheet.textPosition = CGPoint(x: x + (tile - CGFloat(w)) / 2, y: H - pad - tile - 48)
    CTLineDraw(line, sheet)
}
save(sheet.makeImage()!, out.appendingPathComponent("sheet.png"))
print("wrote mockups to \(out.path)")
