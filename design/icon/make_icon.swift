// Renders the DUE EAST app icon (light, dark and tinted variants) at 1024x1024.
// The mark: the Offshore Films wave (offshore-wave-mark.png, no text) inside a compass bezel,
// with dashes around the ring and a green heading dash at due east (090°).
// Run: swift design/icon/make_icon.swift <output dir>   (run from the repo root)
import CoreGraphics
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

struct Palette {
    var bgTop: UInt32?, bgBottom: UInt32?   // nil = transparent (tinted)
    var line: UInt32                        // ring, dashes and wave
    var heading: UInt32                     // the east dash
    var glow: Bool
}
let lightPal = Palette(bgTop: 0x34507E, bgBottom: 0x223962, line: 0xFFFFFF, heading: 0x2FD18A, glow: true)
let darkPal = Palette(bgTop: 0x1E3254, bgBottom: 0x111F3A, line: 0xEAF0F8, heading: 0x2FD18A, glow: true)
let tintPal = Palette(bgTop: nil, bgBottom: nil, line: 0xFFFFFF, heading: 0xFFFFFF, glow: false)

/// Compass bearing (0 = north, 90 = east, clockwise) at radius r, top-left coordinates.
func polar(_ deg: CGFloat, _ r: CGFloat) -> CGPoint {
    let a = deg * .pi / 180
    return CGPoint(x: C.x + r * sin(a), y: C.y - r * cos(a))
}

// Bezel geometry
let ringR: CGFloat = 300
let ringW: CGFloat = 26

/// The wave mark as a clip mask: white where the logo has ink, black elsewhere.
func inkMask(_ url: URL) -> CGImage {
    let src = CGImageSourceCreateWithURL(url as CFURL, nil)!
    let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
    let w = img.width, h = img.height
    var px = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(rgb(0xFFFFFF)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))   // flatten onto white
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    var m = [UInt8](repeating: 0, count: w * h)
    for i in 0..<(w * h) {
        let lum = (Int(px[i*4]) * 299 + Int(px[i*4+1]) * 587 + Int(px[i*4+2]) * 114) / 1000
        m[i] = UInt8(255 - lum)
    }
    let g = CGContext(data: &m, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    return g.makeImage()!
}

let markURL = URL(fileURLWithPath: "design/icon/offshore-wave-mark.png")
let mask = inkMask(markURL)

func render(_ pal: Palette, to url: URL) {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)
    if let top = pal.bgTop, let bottom = pal.bgBottom {
        let g = CGGradient(colorsSpace: space, colors: [rgb(top), rgb(bottom)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: S), options: [])
    }
    ctx.setLineCap(.round)

    // Ring.
    ctx.setStrokeColor(rgb(pal.line)); ctx.setLineWidth(ringW)
    ctx.addEllipse(in: CGRect(x: C.x - ringR, y: C.y - ringR, width: ringR * 2, height: ringR * 2))
    ctx.strokePath()

    // Dashes around the outside of the ring, every 15°: long at N/S/W, medium on the diagonals, short between.
    let r0 = ringR + ringW / 2 + 26
    for i in 0..<24 {
        let d = CGFloat(i) * 15
        if d == 90 { continue }                     // east gets the green heading dash
        let cardinal = i % 6 == 0, diagonal = i % 3 == 0
        let len: CGFloat = cardinal ? 56 : (diagonal ? 38 : 24)
        ctx.setLineWidth(cardinal ? 22 : (diagonal ? 16 : 12))
        ctx.setStrokeColor(rgb(pal.line, cardinal ? 1 : (diagonal ? 0.85 : 0.55)))
        ctx.move(to: polar(d, r0)); ctx.addLine(to: polar(d, r0 + len)); ctx.strokePath()
    }

    // Heading dash at due east, crossing the ring so it reads as the lubber line.
    let a = polar(90, ringR - 34), b = polar(90, r0 + 70)
    if pal.glow {
        let mid = polar(90, (ringR - 34 + r0 + 70) / 2)
        let halo = CGGradient(colorsSpace: space, colors: [rgb(pal.heading, 0.45), rgb(pal.heading, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(halo, startCenter: mid, startRadius: 0, endCenter: mid, endRadius: 150, options: [])
    }
    ctx.setStrokeColor(rgb(pal.heading)); ctx.setLineWidth(30)
    ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()

    // The Offshore Films wave in the middle.
    let width: CGFloat = 430
    let h = width * CGFloat(mask.height) / CGFloat(mask.width)
    let rect = CGRect(x: C.x - width / 2 - 6, y: C.y - h / 2 + 8, width: width, height: h)
    ctx.saveGState()
    ctx.translateBy(x: 0, y: rect.minY + rect.maxY); ctx.scaleBy(x: 1, y: -1)   // un-flip for the mask
    ctx.clip(to: rect, mask: mask)
    ctx.setFillColor(rgb(pal.line)); ctx.fill(rect)
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
