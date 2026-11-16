// Variations of mockup C ("Arcs") for DUE EAST: rounded arcs opening due east, with a colored accent
// on the point heading out. Writes C1.png ... C6.png at 1024px plus sheet.png (3 x 2 grid).
// Run: swift design/icon/compass_c_mockups.swift <output dir>
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

/// Compass bearing (0 = north, 90 = east, clockwise) at radius r, top-left coordinates.
func polar(_ deg: CGFloat, _ r: CGFloat) -> CGPoint {
    let a = deg * .pi / 180
    return CGPoint(x: C.x + r * sin(a), y: C.y - r * cos(a))
}

func arc(_ r: CGFloat, from a: CGFloat, to b: CGFloat) -> CGPath {
    let p = CGMutablePath()
    var d = a
    p.move(to: polar(d, r))
    while d < b { d = min(d + 1, b); p.addLine(to: polar(d, r)) }
    return p
}

// Accent colors, matching the app's rating colors (yellow = fair, green = good).
let yellow: UInt32 = 0xF5C84C
let green: UInt32 = 0x2FD18A

enum Pointer { case dot, triangle }

struct Variant {
    let key: String, name: String
    let bgTop: UInt32, bgBottom: UInt32
    let lines: UInt32
    let accent: UInt32
    var pointer: Pointer = .dot
    var glow = false
    var accentCenter = false
}

let variants = [
    Variant(key: "C1", name: "Yellow dot", bgTop: 0x9DB0C8, bgBottom: 0x8299B8, lines: 0xFFFFFF, accent: yellow),
    Variant(key: "C2", name: "Green dot", bgTop: 0x9DB0C8, bgBottom: 0x8299B8, lines: 0xFFFFFF, accent: green),
    Variant(key: "C3", name: "Rising sun", bgTop: 0x9DB0C8, bgBottom: 0x8299B8, lines: 0xFFFFFF, accent: yellow, glow: true),
    Variant(key: "C4", name: "Navy + yellow", bgTop: 0x34507E, bgBottom: 0x223962, lines: 0xFFFFFF, accent: yellow, glow: true),
    Variant(key: "C5", name: "Green pointer", bgTop: 0x9BBCE2, bgBottom: 0x7FA4D2, lines: 0xFFFFFF, accent: green, pointer: .triangle),
    Variant(key: "C6", name: "Navy + green", bgTop: 0x34507E, bgBottom: 0x223962, lines: 0xFFFFFF, accent: green, glow: true, accentCenter: true),
]

func render(_ v: Variant) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)
    let g = CGGradient(colorsSpace: space, colors: [rgb(v.bgTop), rgb(v.bgBottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: S), options: [])
    ctx.setLineCap(.round); ctx.setLineJoin(.round)

    // Arcs, each opening toward the east.
    ctx.setStrokeColor(rgb(v.lines))
    for (r, w, gap) in [(318.0, 54.0, 34.0), (214.0, 50.0, 46.0), (112.0, 48.0, 70.0)] as [(CGFloat, CGFloat, CGFloat)] {
        ctx.setLineWidth(w)
        ctx.addPath(arc(r, from: 90 + gap, to: 450 - gap)); ctx.strokePath()
    }
    // Center dot.
    ctx.setFillColor(rgb(v.accentCenter ? v.accent : v.lines))
    ctx.fillEllipse(in: CGRect(x: C.x - 34, y: C.y - 34, width: 68, height: 68))

    // The accent heading out through the gap at 090.
    let p = polar(90, 318)
    if v.glow {
        let halo = CGGradient(colorsSpace: space, colors: [rgb(v.accent, 0.55), rgb(v.accent, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(halo, startCenter: p, startRadius: 40, endCenter: p, endRadius: 120, options: [])
    }
    ctx.setFillColor(rgb(v.accent))
    switch v.pointer {
    case .dot:
        ctx.fillEllipse(in: CGRect(x: p.x - 46, y: p.y - 46, width: 92, height: 92))
    case .triangle:
        let tip = polar(90, 392), a = CGPoint(x: p.x - 34, y: p.y - 52), b = CGPoint(x: p.x - 34, y: p.y + 52)
        let t = CGMutablePath(); t.move(to: tip); t.addLine(to: a); t.addLine(to: b); t.closeSubpath()
        // soften the corners a little
        ctx.setStrokeColor(rgb(v.accent)); ctx.setLineWidth(16)
        ctx.addPath(t); ctx.fillPath(); ctx.addPath(t); ctx.strokePath()
    }
    return ctx.makeImage()!
}

func save(_ img: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let images = variants.map { ($0, render($0)) }
for (v, img) in images { save(img, out.appendingPathComponent("\(v.key).png")) }

// Contact sheet, 3 across.
let cols = 3, rowsN = (images.count + cols - 1) / cols
let tile: CGFloat = 340, pad: CGFloat = 56, labelH: CGFloat = 64
let W = pad + CGFloat(cols) * (tile + pad), H = pad + CGFloat(rowsN) * (tile + labelH + pad / 2) + pad / 2
let sheet = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
sheet.setFillColor(rgb(0xF4F6FA)); sheet.fill(CGRect(x: 0, y: 0, width: W, height: H))
let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 28, nil)
for (i, (v, img)) in images.enumerated() {
    let col = i % cols, row = i / cols
    let x = pad + CGFloat(col) * (tile + pad)
    let top = pad + CGFloat(row) * (tile + labelH + pad / 2)
    let rect = CGRect(x: x, y: H - top - tile, width: tile, height: tile)
    sheet.saveGState()
    sheet.addPath(CGPath(roundedRect: rect, cornerWidth: tile * 0.225, cornerHeight: tile * 0.225, transform: nil))
    sheet.clip(); sheet.draw(img, in: rect); sheet.restoreGState()
    let str = NSAttributedString(string: "\(v.key)  \(v.name)", attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): rgb(0x2A3550)])
    let line = CTLineCreateWithAttributedString(str)
    let w = CTLineGetTypographicBounds(line, nil, nil, nil)
    sheet.textPosition = CGPoint(x: x + (tile - CGFloat(w)) / 2, y: H - top - tile - 44)
    CTLineDraw(line, sheet)
}
save(sheet.makeImage()!, out.appendingPathComponent("sheet.png"))
print("wrote mockups to \(out.path)")
