// Renders the app icon. Run from the repo root: swift scripts/make-icon.swift
// Writes Resources/AppIcon.icns and docs/icon.png.
import AppKit

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
}

func context(_ side: Int) -> CGContext {
    CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

func drawIcon() -> CGImage {
    let ctx = context(1024)
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0, 0, 0, 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0.1, 0.1, 0.25))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([color(0.27, 0.29, 0.70), color(0.10, 0.11, 0.30)]),
        start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: []
    )

    // Pool of light on the desk.
    ctx.saveGState()
    ctx.translateBy(x: 800, y: 262)
    ctx.scaleBy(x: 1, y: 0.22)
    ctx.drawRadialGradient(
        gradient([color(1.0, 0.85, 0.45, 0.55), color(1.0, 0.85, 0.45, 0)]),
        startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 260, options: []
    )
    ctx.restoreGState()

    // Light cone from the shade down to the desk.
    let shadeCenter = CGPoint(x: 560, y: 690)
    let angle: CGFloat = 0.5
    ctx.saveGState()
    ctx.translateBy(x: shadeCenter.x, y: shadeCenter.y)
    ctx.rotate(by: angle)
    let cone = CGMutablePath()
    cone.move(to: CGPoint(x: -105, y: -60))
    cone.addLine(to: CGPoint(x: 105, y: -60))
    cone.addLine(to: CGPoint(x: 300, y: -470))
    cone.addLine(to: CGPoint(x: -230, y: -470))
    cone.closeSubpath()
    ctx.addPath(cone)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([color(1.0, 0.86, 0.5, 0.42), color(1.0, 0.86, 0.5, 0)]),
        start: CGPoint(x: 0, y: -60), end: CGPoint(x: 0, y: -470), options: []
    )
    ctx.restoreGState()
    ctx.restoreGState()

    let metal = color(0.95, 0.95, 0.98)

    // Base.
    ctx.addPath(CGPath(roundedRect: CGRect(x: 235, y: 228, width: 250, height: 44), cornerWidth: 22, cornerHeight: 22, transform: nil))
    ctx.setFillColor(metal)
    ctx.fillPath()

    // Arm with an elbow joint.
    let foot = CGPoint(x: 360, y: 268)
    let elbow = CGPoint(x: 300, y: 548)
    ctx.setStrokeColor(metal)
    ctx.setLineWidth(34)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: foot)
    ctx.addLine(to: elbow)
    ctx.addLine(to: shadeCenter)
    ctx.strokePath()
    ctx.setFillColor(color(0.80, 0.82, 0.92))
    ctx.fillEllipse(in: CGRect(x: elbow.x - 26, y: elbow.y - 26, width: 52, height: 52))

    // Shade and the glowing bulb under it.
    ctx.saveGState()
    ctx.translateBy(x: shadeCenter.x, y: shadeCenter.y)
    ctx.rotate(by: angle)
    ctx.saveGState()
    ctx.translateBy(x: 0, y: -62)
    ctx.drawRadialGradient(
        gradient([color(1.0, 0.95, 0.75, 1), color(1.0, 0.85, 0.45, 0)]),
        startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 95, options: []
    )
    ctx.restoreGState()
    let shade = CGMutablePath()
    shade.move(to: CGPoint(x: -50, y: 72))
    shade.addLine(to: CGPoint(x: 50, y: 72))
    shade.addLine(to: CGPoint(x: 112, y: -60))
    shade.addLine(to: CGPoint(x: -112, y: -60))
    shade.closeSubpath()
    ctx.addPath(shade)
    ctx.setFillColor(metal)
    ctx.fillPath()
    ctx.restoreGState()

    return ctx.makeImage()!
}

func scaled(_ image: CGImage, to side: Int) -> CGImage {
    let ctx = context(side)
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) throws {
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try data.write(to: url)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let icon = drawIcon()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("NordvaDeskLamp.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try writePNG(scaled(icon, to: base), to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try writePNG(scaled(icon, to: base * 2), to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()

try FileManager.default.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
try writePNG(scaled(icon, to: 256), to: root.appendingPathComponent("docs/icon.png"))
print(iconutil.terminationStatus == 0 ? "wrote Resources/AppIcon.icns and docs/icon.png" : "iconutil failed")
