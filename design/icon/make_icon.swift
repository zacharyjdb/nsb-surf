// Renders the DUE EAST app icon (light, dark and tinted variants) at 1024x1024.
// The mark: stacked wave strokes whose ends taper into an
// arrowhead pointing east (see design/inspo/logo-*.png).
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
    var bgTop: UInt32?, bgBottom: UInt32?   // nil = transparent (tinted)
    var deep: UInt32, light: UInt32         // the two stroke colors
}

let lightPal = Palette(bgTop: 0xF4F8FD, bgBottom: 0xE3ECF8, deep: 0x2457E6, light: 0x4FB6E6)
let darkPal = Palette(bgTop: 0x173763, bgBottom: 0x0C1E3C, deep: 0x4D82FF, light: 0x6CCBF2)
let tintPal = Palette(bgTop: nil, bgBottom: nil, deep: 0xFFFFFF, light: 0xA8A8A8)

// Layout
let rows = 5
let rowGap: CGFloat = 104
let stroke: CGFloat = 54
let tip: CGFloat = 852          // the middle row reaches furthest east...
let taper: CGFloat = 118        // ...each row out from the middle stops this much shorter...
let tail: CGFloat = 352         // ...and starts this much earlier, so the whole mark is a ">" pointing east
let tailStep: CGFloat = 92
let left: CGFloat = tail - tailStep * 2
let amp: CGFloat = 30
let wavelength: CGFloat = 600

func waveY(_ row: Int, _ x: CGFloat) -> CGFloat {
    let y0 = S / 2 + CGFloat(row - rows / 2) * rowGap
    return y0 + amp * sin((x - left) / wavelength * 2 * .pi + .pi)
}

func render(_ pal: Palette, to url: URL) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: S)
    ctx.scaleBy(x: 1, y: -1)

    if let top = pal.bgTop, let bottom = pal.bgBottom {
        let g = CGGradient(colorsSpace: space, colors: [rgb(top), rgb(bottom)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: S), options: [])
    }

    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(stroke)

    for r in 0..<rows {
        let fromMiddle = CGFloat(abs(r - rows / 2))
        let end = tip - taper * fromMiddle
        let start = tail - tailStep * fromMiddle
        // Solid rows: royal blue through the middle, sky blue on the outer edges.
        ctx.setStrokeColor(rgb(fromMiddle == 2 ? pal.light : pal.deep))
        let p = CGMutablePath()
        var x = start
        p.move(to: CGPoint(x: x, y: waveY(r, x)))
        while x < end { x = min(x + 4, end); p.addLine(to: CGPoint(x: x, y: waveY(r, x))) }
        ctx.addPath(p); ctx.strokePath()
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
