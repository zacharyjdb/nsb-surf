// Draws the Home tab icon: a small-size cut of the DUE EAST app icon ("Swell panel": a framed
// window onto a rolling swell, two contour lines cut through it, a sun ring in the east).
// Strokes are much heavier than the app icon's so it holds up at 25pt. Template image: black on clear.
// Writes TabWave.png (25px), TabWave@2x.png, TabWave@3x.png, plus preview.png, into <output dir>.
// Installed into ios/NSBSurf/Assets.xcassets/TabWave.imageset (delete preview.png after).
// Run: swift design/icon/make_tab_wave.swift <output dir>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let space = CGColorSpace(name: CGColorSpace.sRGB)!

// Geometry in a 100-unit box, y down. Portrait panel like the app icon's.
let frame = CGRect(x: 16, y: 6, width: 68, height: 88)

/// A rolling sea: two swells, the near one bigger, leaning east like a wave about to break.
func surface(_ x: CGFloat) -> CGFloat {
    let u = (x - frame.minX) / frame.width
    return 58 - 9 * sin(u * 2 * .pi * 1.25 + 0.3) - 6 * u
}

/// Contour k below the surface, following it and flattening with depth.
func contour(_ k: Int, _ x: CGFloat) -> CGFloat {
    let u = (x - frame.minX) / frame.width
    let flat = 1 - CGFloat(k) * 0.25
    return 58 + CGFloat(k) * 12 - flat * (9 * sin(u * 2 * .pi * 1.25 + 0.3 + CGFloat(k) * 0.5) + 6 * u)
}

func draw(_ ctx: CGContext, scale s: CGFloat, ink: CGColor, paper: CGColor?) {
    ctx.saveGState()
    ctx.scaleBy(x: s, y: s)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.setStrokeColor(ink); ctx.setFillColor(ink)

    // Frame
    ctx.setLineWidth(8)
    ctx.addPath(CGPath(roundedRect: frame, cornerWidth: 9, cornerHeight: 9, transform: nil)); ctx.strokePath()

    // Sun ring, upper right
    ctx.setLineWidth(6)
    ctx.addEllipse(in: CGRect(x: 56, y: 18, width: 14, height: 14)); ctx.strokePath()

    // Swell body, clipped inside the frame
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: frame.insetBy(dx: 2, dy: 2), cornerWidth: 7, cornerHeight: 7, transform: nil))
    ctx.clip()
    let body = CGMutablePath()
    var x = frame.minX
    body.move(to: CGPoint(x: x, y: surface(x)))
    while x < frame.maxX { x += 1; body.addLine(to: CGPoint(x: x, y: surface(x))) }
    body.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
    body.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
    body.closeSubpath()
    ctx.addPath(body); ctx.fillPath()

    // Two contour lines cut out of the swell
    if let paper { ctx.setStrokeColor(paper) } else { ctx.setBlendMode(.clear) }
    ctx.setLineWidth(4.5)
    for k in 1...2 {
        let c = CGMutablePath()
        x = frame.minX - 4
        c.move(to: CGPoint(x: x, y: contour(k, x)))
        while x < frame.maxX + 4 { x += 1; c.addLine(to: CGPoint(x: x, y: contour(k, x))) }
        ctx.addPath(c); ctx.strokePath()
    }
    ctx.restoreGState()
    ctx.restoreGState()
}

func render(px: Int, ink: CGColor, paper: CGColor? = nil) -> CGImage {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    if let paper { ctx.setFillColor(paper); ctx.fill(CGRect(x: 0, y: 0, width: px, height: px)) }
    ctx.translateBy(x: 0, y: CGFloat(px)); ctx.scaleBy(x: 1, y: -1)
    draw(ctx, scale: CGFloat(px) / 100, ink: ink, paper: paper)
    return ctx.makeImage()!
}

func save(_ img: CGImage, _ url: URL) {
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let black = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
save(render(px: 25, ink: black), out.appendingPathComponent("TabWave.png"))
save(render(px: 50, ink: black), out.appendingPathComponent("TabWave@2x.png"))
save(render(px: 75, ink: black), out.appendingPathComponent("TabWave@3x.png"))
save(render(px: 400, ink: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
            paper: CGColor(srgbRed: 0.23, green: 0.47, blue: 0.72, alpha: 1)), out.appendingPathComponent("preview.png"))
print("ok")
