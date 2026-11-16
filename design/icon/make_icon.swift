// Renders the DUE EAST app icon (light, dark and tinted variants) at 1024x1024.
// The mark: "DUE" stacked over "EAST" in puffy, slightly wonky 70s-style lettering,
// black ink on off-white with screen-print grain (mood from design/inspo/due-east-*.png).
// The puffiness comes from stroking a heavy font's outlines with thick round joins.
// Run: swift design/icon/make_icon.swift <output dir>
import CoreGraphics
import CoreText
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

let fontName = "ArchivoBlack-Regular" as CFString
let fontSize: CGFloat = 240
let puff: CGFloat = 16            // outline stroke width that rounds and fattens the letters
let tracking: CGFloat = 22
let lineGap: CGFloat = 44
// Per-letter tilt (degrees) and nudge, so it looks hand-set rather than typed.
let tilts: [CGFloat] = [-4, 3, -2, 3, -3, 4, -2]
let nudges: [CGFloat] = [6, -8, 4, -6, 8, -4, 6]

struct Letter { let path: CGPath; let width: CGFloat }

func letters(_ text: String, font: CTFont) -> [Letter] {
    text.map { ch in
        var u = Array(String(ch).utf16)
        var g = [CGGlyph](repeating: 0, count: u.count)
        CTFontGetGlyphsForCharacters(font, &u, &g, u.count)
        var adv = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &g, &adv, 1)
        return Letter(path: CTFontCreatePathForGlyph(font, g[0], nil)!, width: adv.width)
    }
}

func render(_ pal: Palette, to url: URL) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // CoreGraphics' native bottom-left origin matches glyph paths, so no flip here.
    if let paper = pal.paper {
        ctx.setFillColor(rgb(paper)); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
    }

    let font = CTFontCreateWithName(fontName, fontSize, nil)
    let capH = CTFontGetCapHeight(font)
    let lines = ["DUE", "EAST"].map { letters($0, font: font) }
    let blockH = capH * 2 + lineGap + puff
    var baseline = S / 2 + blockH / 2 - capH - puff / 2   // top line's baseline

    ctx.setFillColor(rgb(pal.ink))
    ctx.setStrokeColor(rgb(pal.ink))
    ctx.setLineWidth(puff)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)

    var k = 0
    for line in lines {
        let width = line.reduce(0) { $0 + $1.width } + tracking * CGFloat(line.count - 1)
        var x = (S - width) / 2
        for l in line {
            let box = l.path.boundingBox
            var t = CGAffineTransform(translationX: x + box.midX, y: baseline + box.midY + nudges[k])
                .rotated(by: tilts[k] * .pi / 180)
                .translatedBy(x: -box.midX, y: -box.midY)
            let p = l.path.copy(using: &t)!
            ctx.addPath(p); ctx.fillPath()
            ctx.addPath(p); ctx.strokePath()
            x += l.width + tracking
            k += 1
        }
        baseline -= capH + lineGap + puff / 2
    }

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
