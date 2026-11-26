// Renders the Spent clock icon into an .iconset folder.
import AppKit

let out = CommandLine.arguments[1]
let glyphPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Resources/AppIconGlyph.png"
let accent = NSColor(srgbRed: 1.0, green: 0.416, blue: 0.333, alpha: 1)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 512
    let rect = NSRect(x: 40 * s, y: 40 * s, width: 432 * s, height: 432 * s)
    let bg = NSBezierPath(roundedRect: rect, xRadius: 100 * s, yRadius: 100 * s)
    accent.setFill(); bg.fill()
    NSGradient(starting: NSColor.white.withAlphaComponent(0.22), ending: NSColor.black.withAlphaComponent(0.18))!
        .draw(in: bg, angle: -90)
    // Icons8 "clock" (ios7, id 34), white, see icons8.json
    if let glyph = NSImage(contentsOfFile: glyphPath) {
        glyph.draw(in: NSRect(x: 116 * s, y: 116 * s, width: 280 * s, height: 280 * s))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! render(px).write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
