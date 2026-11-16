// DUE EAST icon mockups built around the Offshore Films wave mark (wave + gulls, no text),
// in the navy / white / green compass style of mockup C6. Heading is always due east (090°).
// Writes O1.png ... O4.png at 1024px plus sheet.png.
// Run: swift design/icon/offshore_mockups.swift <mark.png> <output dir>
//   <mark.png>: the wave mark cropped from the Offshore Films logo (dark ink on transparent or white).
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024
let C = CGPoint(x: S / 2, y: S / 2)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let gray = CGColorSpaceCreateDeviceGray()

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let navyTop: UInt32 = 0x34507E, navyBottom: UInt32 = 0x223962
let green: UInt32 = 0x2FD18A
let white = rgb(0xFFFFFF)

func polar(_ deg: CGFloat, _ r: CGFloat) -> CGPoint {
    let a = deg * .pi / 180
    return CGPoint(x: C.x + r * sin(a), y: C.y - r * cos(a))
}
func arc(_ r: CGFloat, from a: CGFloat, to b: CGFloat) -> CGPath {
    let p = CGMutablePath(); var d = a
    p.move(to: polar(d, r))
    while d < b { d = min(d + 0.5, b); p.addLine(to: polar(d, r)) }
    return p
}

/// Turns the logo into a clip mask: white where there's ink (dark and opaque), black elsewhere.
func inkMask(_ url: URL) -> CGImage {
    let src = CGImageSourceCreateWithURL(url as CFURL, nil)!
    let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
    let w = img.width, h = img.height
    var px = [UInt8](repeating: 0, count: w * h * 4)
    let rgba = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                         space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    rgba.setFillColor(white); rgba.fill(CGRect(x: 0, y: 0, width: w, height: h))   // flatten onto white
    rgba.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    var m = [UInt8](repeating: 0, count: w * h)
    for i in 0..<(w * h) {
        let lum = (Int(px[i*4]) * 299 + Int(px[i*4+1]) * 587 + Int(px[i*4+2]) * 114) / 1000
        m[i] = UInt8(255 - lum)
    }
    let g = CGContext(data: &m, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                      space: gray, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    return g.makeImage()!
}

let args = CommandLine.arguments
let mask = inkMask(URL(fileURLWithPath: args[1]))
let out = URL(fileURLWithPath: args.count > 2 ? args[2] : ".")
let aspect = CGFloat(mask.height) / CGFloat(mask.width)

/// Paints the wave mark in `color`, `width` wide, centered at `center` (top-left coordinates).
func drawMark(_ ctx: CGContext, center: CGPoint, width: CGFloat, color: CGColor) {
    let h = width * aspect
    let rect = CGRect(x: center.x - width / 2, y: center.y - h / 2, width: width, height: h)
    ctx.saveGState()
    // the context is flipped; flip back locally so the mask isn't upside down
    ctx.translateBy(x: 0, y: rect.minY + rect.maxY); ctx.scaleBy(x: 1, y: -1)
    ctx.clip(to: rect, mask: mask)
    ctx.setFillColor(color); ctx.fill(rect)
    ctx.restoreGState()
}

func canvas() -> CGContext {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)
    let g = CGGradient(colorsSpace: space, colors: [rgb(navyTop), rgb(navyBottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: S), options: [])
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    return ctx
}

func glowDot(_ ctx: CGContext, _ p: CGPoint, r: CGFloat) {
    let halo = CGGradient(colorsSpace: space, colors: [rgb(green, 0.55), rgb(green, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(halo, startCenter: p, startRadius: r * 0.9, endCenter: p, endRadius: r * 2.8, options: [])
    ctx.setFillColor(rgb(green))
    ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
}

func ticks(_ ctx: CGContext, r0: CGFloat, r1: CGFloat, width: CGFloat) {
    ctx.setStrokeColor(white); ctx.setLineWidth(width)
    for d in [0.0, 180.0, 270.0] as [CGFloat] {
        ctx.move(to: polar(d, r0)); ctx.addLine(to: polar(d, r1)); ctx.strokePath()
    }
}

/// Teardrop pointing east: round body at `p`, tip `len` further east.
func teardrop(_ ctx: CGContext, _ p: CGPoint, r: CGFloat, len: CGFloat) {
    let a = acos(r / len)
    let t = CGMutablePath()
    t.move(to: CGPoint(x: p.x + len, y: p.y))
    t.addLine(to: CGPoint(x: p.x + r * cos(a), y: p.y - r * sin(a)))
    t.addArc(center: p, radius: r, startAngle: -a, endAngle: a, clockwise: true)
    t.closeSubpath()
    ctx.setFillColor(rgb(green)); ctx.addPath(t); ctx.fillPath()
}

// O1 — Compass ring: the wave inside a single ring with N/S/W ticks, open at east with the green heading dot.
func ringWave() -> CGImage {
    let ctx = canvas()
    ctx.setStrokeColor(white); ctx.setLineWidth(30)
    ctx.addPath(arc(318, from: 90 + 22, to: 450 - 22)); ctx.strokePath()
    ticks(ctx, r0: 362, r1: 402, width: 22)
    drawMark(ctx, center: CGPoint(x: C.x - 6, y: C.y + 10), width: 470, color: white)
    glowDot(ctx, polar(90, 318), r: 40)
    return ctx.makeImage()!
}

// O2 — Arcs: C6's two outer arcs around the wave, opening east with the green dot in the gap.
func arcsWave() -> CGImage {
    let ctx = canvas()
    ctx.setStrokeColor(white)
    ctx.setLineWidth(46); ctx.addPath(arc(330, from: 90 + 32, to: 450 - 32)); ctx.strokePath()
    ctx.setLineWidth(38); ctx.addPath(arc(240, from: 90 + 44, to: 450 - 44)); ctx.strokePath()
    drawMark(ctx, center: CGPoint(x: C.x - 10, y: C.y + 8), width: 330, color: white)
    glowDot(ctx, polar(90, 330), r: 44)
    return ctx.makeImage()!
}

// O3 — Bearing: the wave riding a green bearing line that points east, with compass ticks.
func bearingWave() -> CGImage {
    let ctx = canvas()
    drawMark(ctx, center: CGPoint(x: C.x - 10, y: 460), width: 600, color: white)
    let y: CGFloat = 640
    ctx.setStrokeColor(rgb(green)); ctx.setLineWidth(20)
    ctx.move(to: CGPoint(x: 196, y: y)); ctx.addLine(to: CGPoint(x: 740, y: y)); ctx.strokePath()
    let head = CGPoint(x: 740, y: y)
    let halo = CGGradient(colorsSpace: space, colors: [rgb(green, 0.5), rgb(green, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(halo, startCenter: head, startRadius: 30, endCenter: head, endRadius: 120, options: [])
    teardrop(ctx, head, r: 40, len: 100)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.6)); ctx.setLineWidth(14)
    for x in stride(from: 250.0, through: 690.0, by: 110.0) {
        ctx.move(to: CGPoint(x: x, y: y + 44)); ctx.addLine(to: CGPoint(x: x, y: y + 70)); ctx.strokePath()
    }
    return ctx.makeImage()!
}

// O4 — Simple: just the wave, big, with a glowing green sun rising due east of it.
func simpleWave() -> CGImage {
    let ctx = canvas()
    drawMark(ctx, center: CGPoint(x: C.x - 40, y: 560), width: 660, color: white)
    glowDot(ctx, CGPoint(x: 820, y: 360), r: 52)
    return ctx.makeImage()!
}

func save(_ img: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
}

let mocks: [(String, String, CGImage)] = [("O1", "Compass ring", ringWave()), ("O2", "Arcs", arcsWave()),
                                          ("O3", "Bearing line", bearingWave()), ("O4", "Wave + sun", simpleWave())]
for (k, _, img) in mocks { save(img, out.appendingPathComponent("\(k).png")) }

let tile: CGFloat = 360, pad: CGFloat = 60
let W = pad + CGFloat(mocks.count) * (tile + pad), H = pad + tile + 70 + pad / 2
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
