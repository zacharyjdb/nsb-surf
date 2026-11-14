// Renders the NSB Surf app icon (light, dark and tinted variants) at 1024x1024.
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
    var skyTop: UInt32, skyBottom: UInt32
    var sun: UInt32, sunGlow: CGFloat
    var waveTop: UInt32, waveBottom: UInt32
    var foam: UInt32, barrel: UInt32, glow: UInt32
    var backSwell: UInt32, backSwellAlpha: CGFloat
    var transparentBG = false
}

let light = Palette(skyTop: 0x8CC8FF, skyBottom: 0x3B8BF7, sun: 0xFFD25E, sunGlow: 0.45,
                    waveTop: 0x1F6FE8, waveBottom: 0x0B2E78, foam: 0xFFFFFF, barrel: 0x5FB0FF, glow: 0xFFFFFF,
                    backSwell: 0xFFFFFF, backSwellAlpha: 0.22)
let dark = Palette(skyTop: 0x0B1730, skyBottom: 0x13306B, sun: 0xFFC94D, sunGlow: 0.25,
                   waveTop: 0x2F7CF6, waveBottom: 0x0B2A6B, foam: 0xEAF3FF, barrel: 0x1E4FA8, glow: 0xFFC94D,
                   backSwell: 0x5B8DEF, backSwellAlpha: 0.25)
// Tinted: grayscale on transparent; iOS applies the user's tint.
let tinted = Palette(skyTop: 0x000000, skyBottom: 0x000000, sun: 0xFFFFFF, sunGlow: 0,
                     waveTop: 0x9A9A9A, waveBottom: 0x5A5A5A, foam: 0xFFFFFF, barrel: 0x3A3A3A, glow: 0xFFFFFF,
                     backSwell: 0xFFFFFF, backSwellAlpha: 0.2, transparentBG: true)

/// The breaking wave: back of the swell rising from the left, a lip pitching forward, curling into a barrel.
func wavePath() -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: -20, y: 790))
    p.addCurve(to: CGPoint(x: 560, y: 300), control1: CGPoint(x: 200, y: 700), control2: CGPoint(x: 330, y: 300))
    // lip throwing forward and down
    p.addCurve(to: CGPoint(x: 850, y: 560), control1: CGPoint(x: 760, y: 300), control2: CGPoint(x: 880, y: 430))
    // lip curls back up into the barrel
    p.addCurve(to: CGPoint(x: 660, y: 560), control1: CGPoint(x: 810, y: 640), control2: CGPoint(x: 690, y: 640))
    p.addCurve(to: CGPoint(x: 740, y: 470), control1: CGPoint(x: 645, y: 515), control2: CGPoint(x: 690, y: 465))
    // inside of the barrel back down to the face
    p.addCurve(to: CGPoint(x: 600, y: 470), control1: CGPoint(x: 690, y: 420), control2: CGPoint(x: 620, y: 420))
    p.addCurve(to: CGPoint(x: 1044, y: 800), control1: CGPoint(x: 560, y: 640), control2: CGPoint(x: 800, y: 780))
    p.addLine(to: CGPoint(x: 1044, y: 1044))
    p.addLine(to: CGPoint(x: -20, y: 1044))
    p.closeSubpath()
    return p
}

/// The foam line along the crest and lip.
func foamPath() -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 330, y: 470))
    p.addCurve(to: CGPoint(x: 560, y: 300), control1: CGPoint(x: 400, y: 360), control2: CGPoint(x: 470, y: 300))
    p.addCurve(to: CGPoint(x: 850, y: 560), control1: CGPoint(x: 760, y: 300), control2: CGPoint(x: 880, y: 430))
    p.addCurve(to: CGPoint(x: 660, y: 560), control1: CGPoint(x: 810, y: 640), control2: CGPoint(x: 690, y: 640))
    p.addCurve(to: CGPoint(x: 740, y: 470), control1: CGPoint(x: 645, y: 515), control2: CGPoint(x: 690, y: 465))
    return p
}

/// A soft swell line out to sea behind the wave.
func swellPath(y: CGFloat, amp: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: -20, y: y))
    var x: CGFloat = -20
    while x <= S + 20 {
        p.addLine(to: CGPoint(x: x, y: y + amp * sin(x / S * .pi * 3)))
        x += 8
    }
    p.addLine(to: CGPoint(x: S + 20, y: S + 20))
    p.addLine(to: CGPoint(x: -20, y: S + 20))
    p.closeSubpath()
    return p
}

func render(_ pal: Palette, to url: URL) {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Work in top-left coordinates.
    ctx.translateBy(x: 0, y: S)
    ctx.scaleBy(x: 1, y: -1)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!

    if !pal.transparentBG {
        let sky = CGGradient(colorsSpace: space, colors: [rgb(pal.skyTop), rgb(pal.skyBottom)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: S), options: [])
    }

    // Sun, top left, with a soft halo.
    let sunC = CGPoint(x: 290, y: 250), sunR: CGFloat = 105
    if pal.sunGlow > 0 {
        let glow = CGGradient(colorsSpace: space, colors: [rgb(pal.glow, pal.sunGlow), rgb(pal.glow, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: sunC, startRadius: sunR, endCenter: sunC, endRadius: sunR * 2.4, options: [])
    }
    ctx.setFillColor(rgb(pal.sun))
    ctx.fillEllipse(in: CGRect(x: sunC.x - sunR, y: sunC.y - sunR, width: sunR * 2, height: sunR * 2))

    // Distant swell lines.
    ctx.setFillColor(rgb(pal.backSwell, pal.backSwellAlpha))
    ctx.addPath(swellPath(y: 640, amp: 14)); ctx.fillPath()

    // Inside of the barrel, seen through the curl.
    ctx.setFillColor(rgb(pal.barrel))
    ctx.fillEllipse(in: CGRect(x: 560, y: 400, width: 260, height: 260))

    // The wave, filled with a deep-water gradient.
    ctx.saveGState()
    ctx.addPath(wavePath()); ctx.clip()
    let water = CGGradient(colorsSpace: space, colors: [rgb(pal.waveTop), rgb(pal.waveBottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(water, start: CGPoint(x: 0, y: 300), end: CGPoint(x: 0, y: S), options: [.drawsAfterEndLocation])
    ctx.restoreGState()

    // Foam on the lip.
    ctx.setStrokeColor(rgb(pal.foam))
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.setLineWidth(42)
    ctx.addPath(foamPath()); ctx.strokePath()

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
