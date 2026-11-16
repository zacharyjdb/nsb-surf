// DUE EAST icon mockups in a bold, flat, single-color mark style with organic, slightly rough linework
// (mood from design/inspo/mark-*.png; original drawings, not copies).
// Writes M1.png ... M6.png at 1024px plus sheet.png (3 x 2 grid).
// Run: swift design/icon/mark_mockups.swift <output dir>
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

let cream: UInt32 = 0xEEE8DA, paper: UInt32 = 0xECEAE4, ink: UInt32 = 0x171717
let navy: UInt32 = 0x1F3557, oxblood: UInt32 = 0x7A2B31, olive: UInt32 = 0x4B4B39

/// Smooth, repeatable wobble for hand-cut edges.
func wob(_ x: CGFloat, _ seed: CGFloat) -> CGFloat {
    sin(x * 0.021 + seed) * 2.6 + sin(x * 0.057 + seed * 1.7) * 1.6 + sin(x * 0.13 + seed * 3.1) * 0.9
}

func canvas(_ bg: UInt32) -> CGContext {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)
    ctx.setFillColor(rgb(bg)); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    return ctx
}

/// A horizontal band with rough top and bottom edges and a slightly ragged right end.
func roughBand(_ ctx: CGContext, x0: CGFloat, x1: CGFloat, y: CGFloat, t: CGFloat, seed: CGFloat) {
    let p = CGMutablePath()
    var x = x0
    p.move(to: CGPoint(x: x, y: y - t / 2 + wob(x, seed)))
    while x < x1 { x = min(x + 4, x1); p.addLine(to: CGPoint(x: x, y: y - t / 2 + wob(x, seed))) }
    p.addLine(to: CGPoint(x: x1 + wob(y, seed + 2) * 1.5, y: y))
    while x > x0 { x = max(x - 4, x0); p.addLine(to: CGPoint(x: x, y: y + t / 2 + wob(x, seed + 5))) }
    p.closeSubpath()
    ctx.addPath(p); ctx.fillPath()
}

/// Bearing (0 = north, clockwise) at radius r from c, top-left coordinates.
func polar(_ c: CGPoint, _ deg: CGFloat, _ r: CGFloat) -> CGPoint {
    let a = deg * .pi / 180
    return CGPoint(x: c.x + r * sin(a), y: c.y - r * cos(a))
}

// M1/M2 — Sunrise: the sun coming up due east over a striped sea. Rays, a thick sun ring, rough stripes.
func sunrise(bg: UInt32, fg: UInt32) -> CGImage {
    let ctx = canvas(bg)
    ctx.setFillColor(rgb(fg))
    let horizon: CGFloat = 486, sunC = CGPoint(x: 512, y: 486)
    // Sun: a thick half ring
    let ring = CGMutablePath()
    ring.addArc(center: sunC, radius: 116, startAngle: .pi, endAngle: 0, clockwise: false)
    ring.addArc(center: sunC, radius: 70, startAngle: 0, endAngle: .pi, clockwise: true)
    ring.closeSubpath()
    ctx.addPath(ring); ctx.fillPath()
    // Rays: tapered, slightly uneven wedges
    let rays: [(CGFloat, CGFloat)] = [(-72, 236), (-48, 252), (-24, 262), (0, 268), (24, 258), (48, 250), (72, 238)]
    for (i, (deg, len)) in rays.enumerated() {
        let r0: CGFloat = 150
        let w0: CGFloat = 13, w1: CGFloat = 25 + CGFloat(i % 2) * 3
        let a = polar(sunC, deg - w0 / r0 * 57.3, r0), b = polar(sunC, deg + w0 / r0 * 57.3, r0)
        let c = polar(sunC, deg + w1 / len * 57.3, len), d = polar(sunC, deg - w1 / len * 57.3, len)
        let p = CGMutablePath(); p.addLines(between: [a, b, c, d]); p.closeSubpath()
        ctx.addPath(p); ctx.fillPath()
    }
    // Sea: rough stripes, right ends uneven like hand-cut paper
    let ends: [CGFloat] = [776, 790, 768, 784, 772, 790]
    for i in 0..<6 {
        let y = horizon + 34 + CGFloat(i) * 56
        roughBand(ctx, x0: 236, x1: ends[i], y: y, t: 34, seed: CGFloat(i) * 2.3)
    }
    return ctx.makeImage()!
}

// M3 — Swell panel: a framed window onto a rolling swell, with a sun ring rising in the east (upper right).
func swellPanel(bg: UInt32, fg: UInt32) -> CGImage {
    let ctx = canvas(bg)
    let frame = CGRect(x: 214, y: 176, width: 596, height: 672)
    ctx.setStrokeColor(rgb(fg)); ctx.setLineWidth(22)
    ctx.addPath(CGPath(roundedRect: frame, cornerWidth: 26, cornerHeight: 26, transform: nil)); ctx.strokePath()
    // Sun, east
    ctx.setLineWidth(20)
    ctx.addEllipse(in: CGRect(x: 640, y: 262, width: 92, height: 92)); ctx.strokePath()
    // Swell body clipped to the frame
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: frame.insetBy(dx: 11, dy: 11), cornerWidth: 16, cornerHeight: 16, transform: nil)); ctx.clip()
    func top(_ x: CGFloat) -> CGFloat {
        let u = (x - frame.minX) / frame.width
        return 560 - 120 * exp(-pow((u - 0.34) / 0.2, 2)) + 26 * sin(u * 9)
    }
    let body = CGMutablePath()
    var x = frame.minX
    body.move(to: CGPoint(x: x, y: top(x)))
    while x < frame.maxX { x += 4; body.addLine(to: CGPoint(x: x, y: top(x))) }
    body.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY)); body.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
    body.closeSubpath()
    ctx.setFillColor(rgb(fg)); ctx.addPath(body); ctx.fillPath()
    // Contour lines in the swell, following its shape and flattening with depth
    ctx.setStrokeColor(rgb(bg)); ctx.setLineWidth(13)
    for k in 1...4 {
        let off = CGFloat(k) * 54, flat = 1 - CGFloat(k) * 0.18
        let p = CGMutablePath()
        var x = frame.minX - 10
        func yy(_ x: CGFloat) -> CGFloat {
            let u = (x - frame.minX) / frame.width
            return 560 + off - flat * (120 * exp(-pow((u - 0.34 - CGFloat(k) * 0.05) / 0.22, 2)) - 26 * sin(u * 9 + CGFloat(k) * 0.6))
        }
        p.move(to: CGPoint(x: x, y: yy(x)))
        while x < frame.maxX + 10 { x += 4; p.addLine(to: CGPoint(x: x, y: yy(x))) }
        ctx.addPath(p); ctx.strokePath()
    }
    ctx.restoreGState()
    return ctx.makeImage()!
}

// M4 — Banded block: a rounded block cut by flowing gaps that rise toward the east.
func bandedBlock(bg: UInt32, fg: UInt32) -> CGImage {
    let ctx = canvas(bg)
    let box = CGRect(x: 230, y: 230, width: 564, height: 564)
    ctx.setFillColor(rgb(fg))
    ctx.addPath(CGPath(roundedRect: box, cornerWidth: 70, cornerHeight: 70, transform: nil)); ctx.fillPath()
    ctx.setStrokeColor(rgb(bg)); ctx.setLineWidth(34)
    // Each cut: a gentle swell line, rising to the right (east).
    let cuts: [(y0: CGFloat, rise: CGFloat, amp: CGFloat, ph: CGFloat)] =
        [(390, 120, 34, 0.3), (540, 90, 30, 1.4), (680, 50, 24, 2.4)]
    for c in cuts {
        let p = CGMutablePath()
        var x = box.minX - 20
        func y(_ x: CGFloat) -> CGFloat {
            let u = (x - box.minX) / box.width
            return c.y0 - c.rise * u + c.amp * sin(u * 2 * .pi + c.ph)
        }
        p.move(to: CGPoint(x: x, y: y(x)))
        while x < box.maxX + 20 { x += 4; p.addLine(to: CGPoint(x: x, y: y(x))) }
        ctx.addPath(p); ctx.strokePath()
    }
    return ctx.makeImage()!
}

// M5 — Brush swell: two loose brush-stroke waves rolling east.
func brushWaves(bg: UInt32, fg: UInt32) -> CGImage {
    let ctx = canvas(bg)
    ctx.setFillColor(rgb(fg))
    for (row, y0) in [(0, 430.0), (1, 600.0)] as [(Int, CGFloat)] {
        let x0: CGFloat = 196, x1: CGFloat = 828
        var x = x0
        while x <= x1 {
            let u = (x - x0) / (x1 - x0)
            // swell crests that lean east: a sawtooth-ish wave via a skewed sine
            let ph = u * 2.5 * 2 * .pi + CGFloat(row) * 0.9
            let y = y0 - 52 * sin(ph + 0.45 * sin(ph))
            // brush pressure: thick in the middle, thinner at ends, with bristle wobble
            let press = sin(u * .pi) * 0.55 + 0.45
            let r = (24 + wob(x, CGFloat(row) * 4) * 1.4) * press + 6
            ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            x += 2
        }
    }
    return ctx.makeImage()!
}

func save(_ img: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let mocks: [(String, String, CGImage)] = [
    ("M1", "Sunrise, navy", sunrise(bg: navy, fg: cream)),
    ("M2", "Sunrise, oxblood", sunrise(bg: oxblood, fg: cream)),
    ("M3", "Swell panel", swellPanel(bg: paper, fg: ink)),
    ("M4", "Banded block", bandedBlock(bg: navy, fg: cream)),
    ("M5", "Brush swell", brushWaves(bg: olive, fg: cream)),
    ("M6", "Sunrise, ink", sunrise(bg: paper, fg: ink)),
]
for (k, _, img) in mocks { save(img, out.appendingPathComponent("\(k).png")) }

let cols = 3, rowsN = 2
let tile: CGFloat = 340, pad: CGFloat = 56, labelH: CGFloat = 64
let W = pad + CGFloat(cols) * (tile + pad), H = pad + CGFloat(rowsN) * (tile + labelH + pad / 2) + pad / 2
let sheet = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
sheet.setFillColor(rgb(0xF4F6FA)); sheet.fill(CGRect(x: 0, y: 0, width: W, height: H))
let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 28, nil)
for (i, (k, name, img)) in mocks.enumerated() {
    let col = i % cols, row = i / cols
    let x = pad + CGFloat(col) * (tile + pad)
    let top = pad + CGFloat(row) * (tile + labelH + pad / 2)
    let rect = CGRect(x: x, y: H - top - tile, width: tile, height: tile)
    sheet.saveGState()
    sheet.addPath(CGPath(roundedRect: rect, cornerWidth: tile * 0.225, cornerHeight: tile * 0.225, transform: nil))
    sheet.clip(); sheet.draw(img, in: rect); sheet.restoreGState()
    let str = NSAttributedString(string: "\(k)  \(name)", attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): rgb(0x2A3550)])
    let line = CTLineCreateWithAttributedString(str)
    let w = CTLineGetTypographicBounds(line, nil, nil, nil)
    sheet.textPosition = CGPoint(x: x + (tile - CGFloat(w)) / 2, y: H - top - tile - 44)
    CTLineDraw(line, sheet)
}
save(sheet.makeImage()!, out.appendingPathComponent("sheet.png"))
print("wrote mockups to \(out.path)")
