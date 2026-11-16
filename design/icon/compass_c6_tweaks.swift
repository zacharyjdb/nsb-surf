// Tweaks on mockup C6 (navy, white arcs opening due east, glowing green accent) for DUE EAST:
// a bearing line, compass ticks, wavy "swell" arcs and a teardrop pointer, alone and combined.
// Writes T1.png ... T6.png at 1024px plus sheet.png (3 x 2 grid).
// Run: swift design/icon/compass_c6_tweaks.swift <output dir>
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

/// An arc between two bearings. With `waves`, the radius ripples so the ring reads as a swell line.
func arc(_ r: CGFloat, from a: CGFloat, to b: CGFloat, waves: CGFloat = 0, amp: CGFloat = 0) -> CGPath {
    let p = CGMutablePath()
    func pt(_ d: CGFloat) -> CGPoint { polar(d, r + amp * sin(d * .pi / 180 * waves)) }
    var d = a
    p.move(to: pt(d))
    while d < b { d = min(d + 0.5, b); p.addLine(to: pt(d)) }
    return p
}

let navyTop: UInt32 = 0x34507E, navyBottom: UInt32 = 0x223962
let green: UInt32 = 0x2FD18A

struct Tweak {
    let key: String, name: String
    var line = false, ticks = false, wavy = false, teardrop = false
}

let tweaks = [
    Tweak(key: "T1", name: "Bearing line", line: true),
    Tweak(key: "T2", name: "Compass ticks", ticks: true),
    Tweak(key: "T3", name: "Line + ticks", line: true, ticks: true),
    Tweak(key: "T4", name: "Swell arcs", ticks: true, wavy: true),
    Tweak(key: "T5", name: "Teardrop + line", line: true, teardrop: true),
    Tweak(key: "T6", name: "All together", line: true, ticks: true, wavy: true, teardrop: true),
]

func render(_ t: Tweak) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)
    let g = CGGradient(colorsSpace: space, colors: [rgb(navyTop), rgb(navyBottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: S), options: [])
    ctx.setLineCap(.round); ctx.setLineJoin(.round)

    // Arcs opening east. Wavy ones ripple with more crests further out, like swell lines.
    ctx.setStrokeColor(rgb(0xFFFFFF))
    let rings: [(r: CGFloat, w: CGFloat, gap: CGFloat, waves: CGFloat, amp: CGFloat)] =
        [(306, 50, 34, 9, 8), (206, 46, 46, 7, 7), (110, 44, 70, 0, 0)]
    for ring in rings {
        ctx.setLineWidth(ring.w)
        ctx.addPath(arc(ring.r, from: 90 + ring.gap, to: 450 - ring.gap,
                        waves: t.wavy ? ring.waves : 0, amp: t.wavy ? ring.amp : 0))
        ctx.strokePath()
    }

    // Compass ticks at N, S and W, outside the outer ring (east is the open gap).
    if t.ticks {
        ctx.setLineWidth(22)
        for d in [0.0, 180.0, 270.0] as [CGFloat] {
            ctx.move(to: polar(d, 364)); ctx.addLine(to: polar(d, 404)); ctx.strokePath()
        }
    }

    let head = polar(90, 306)
    // Glow behind the heading marker.
    let halo = CGGradient(colorsSpace: space, colors: [rgb(green, 0.55), rgb(green, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(halo, startCenter: head, startRadius: 40, endCenter: head, endRadius: 124, options: [])

    // Bearing line from center to the heading marker.
    if t.line {
        ctx.setStrokeColor(rgb(green)); ctx.setLineWidth(18)
        ctx.move(to: C); ctx.addLine(to: head); ctx.strokePath()
    }

    ctx.setFillColor(rgb(green))
    // Center dot.
    ctx.fillEllipse(in: CGRect(x: C.x - 34, y: C.y - 34, width: 68, height: 68))
    // Heading marker: a dot, or a teardrop whose point aims east.
    let R: CGFloat = 44
    if t.teardrop {
        let tip = CGPoint(x: head.x + 110, y: head.y)
        let d = tip.x - head.x
        let a = acos(R / d)           // tangent points, measured from the east direction
        let p = CGMutablePath()
        p.move(to: tip)
        p.addLine(to: CGPoint(x: head.x + R * cos(a), y: head.y - R * sin(a)))
        p.addArc(center: head, radius: R, startAngle: -a, endAngle: a, clockwise: true)
        p.closeSubpath()
        ctx.addPath(p); ctx.fillPath()
    } else {
        ctx.fillEllipse(in: CGRect(x: head.x - R, y: head.y - R, width: R * 2, height: R * 2))
    }
    return ctx.makeImage()!
}

func save(_ img: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let images = tweaks.map { ($0, render($0)) }
for (t, img) in images { save(img, out.appendingPathComponent("\(t.key).png")) }

// Contact sheet, 3 across.
let cols = 3, rowsN = (images.count + cols - 1) / cols
let tile: CGFloat = 340, pad: CGFloat = 56, labelH: CGFloat = 64
let W = pad + CGFloat(cols) * (tile + pad), H = pad + CGFloat(rowsN) * (tile + labelH + pad / 2) + pad / 2
let sheet = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
sheet.setFillColor(rgb(0xF4F6FA)); sheet.fill(CGRect(x: 0, y: 0, width: W, height: H))
let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 28, nil)
for (i, (t, img)) in images.enumerated() {
    let col = i % cols, row = i / cols
    let x = pad + CGFloat(col) * (tile + pad)
    let top = pad + CGFloat(row) * (tile + labelH + pad / 2)
    let rect = CGRect(x: x, y: H - top - tile, width: tile, height: tile)
    sheet.saveGState()
    sheet.addPath(CGPath(roundedRect: rect, cornerWidth: tile * 0.225, cornerHeight: tile * 0.225, transform: nil))
    sheet.clip(); sheet.draw(img, in: rect); sheet.restoreGState()
    let str = NSAttributedString(string: "\(t.key)  \(t.name)", attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): rgb(0x2A3550)])
    let line = CTLineCreateWithAttributedString(str)
    let w = CTLineGetTypographicBounds(line, nil, nil, nil)
    sheet.textPosition = CGPoint(x: x + (tile - CGFloat(w)) / 2, y: H - top - tile - 44)
    CTLineDraw(line, sheet)
}
save(sheet.makeImage()!, out.appendingPathComponent("sheet.png"))
print("wrote tweaks to \(out.path)")
