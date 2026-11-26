import AppKit
import SwiftUI

extension Color {
    /// "#ff6a55" or "ff6a55"
    init(hex: String, opacity: Double = 1) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: Double
        if s.count == 3 {
            r = Double((v >> 8) & 0xF) / 15; g = Double((v >> 4) & 0xF) / 15; b = Double(v & 0xF) / 15
        } else {
            r = Double((v >> 16) & 0xFF) / 255; g = Double((v >> 8) & 0xFF) / 255; b = Double(v & 0xFF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    var hexString: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return String(format: "#%02x%02x%02x", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}

/// A colour combination. The default "Graphite & Coral" is a cockpit at night: graphite
/// panels, coral for "now" and what needs attention.
struct Skin: Equatable {
    var id: String
    var name: String
    var light = false
    var bg: Color
    var side: Color
    var panel: Color
    var panel2: Color
    var track: Color
    var line: Color
    var line2: Color
    var ink: Color
    var muted: Color
    var dim: Color
    var acc: Color
    var good = Color(hex: "#3ddc97")
    var warn = Color(hex: "#ffc46b")
    var bad = Color(hex: "#ff6b6b")
    var neu = Color(hex: "#8b9bb4")
    var blue = Color(hex: "#6ea8ff")
    var hover: Color
    var onAcc = Color.white

    static let darkLine = Color.white.opacity(0.07)
    static let darkLine2 = Color.white.opacity(0.12)

    static let all: [Skin] = [
        Skin(id: "coral", name: "Graphite & Coral", bg: Color(hex: "#0a0c10"), side: Color(hex: "#0d1015"), panel: Color(hex: "#12161d"),
             panel2: Color(hex: "#191e27"), track: Color(hex: "#232a35"), line: darkLine, line2: darkLine2, ink: Color(hex: "#eef1f6"),
             muted: Color(hex: "#8c95a5"), dim: Color(hex: "#5f6878"), acc: Color(hex: "#ff6a55"), hover: Color(hex: "#1f2530")),
        Skin(id: "midnight", name: "Midnight & Blue", bg: Color(hex: "#060a14"), side: Color(hex: "#0a1020"), panel: Color(hex: "#0d1527"),
             panel2: Color(hex: "#132037"), track: Color(hex: "#1c2b45"), line: darkLine, line2: darkLine2, ink: Color(hex: "#eaf1ff"),
             muted: Color(hex: "#8a9bba"), dim: Color(hex: "#56688a"), acc: Color(hex: "#4c8dff"), hover: Color(hex: "#1a2a46")),
        Skin(id: "emerald", name: "Obsidian & Mint", bg: Color(hex: "#050f0c"), side: Color(hex: "#091612"), panel: Color(hex: "#0c1915"),
             panel2: Color(hex: "#12241e"), track: Color(hex: "#1a332b"), line: darkLine, line2: darkLine2, ink: Color(hex: "#e8f7f0"),
             muted: Color(hex: "#86a89b"), dim: Color(hex: "#557466"), acc: Color(hex: "#2ee59d"), hover: Color(hex: "#173027"),
             onAcc: Color(hex: "#04120c")),
        Skin(id: "plum", name: "Plum & Gold", bg: Color(hex: "#0e0912"), side: Color(hex: "#140d1a"), panel: Color(hex: "#18111f"),
             panel2: Color(hex: "#21182a"), track: Color(hex: "#2e2238"), line: darkLine, line2: darkLine2, ink: Color(hex: "#f6effa"),
             muted: Color(hex: "#a593b0"), dim: Color(hex: "#6d5d78"), acc: Color(hex: "#f5b342"), hover: Color(hex: "#2a1f35"),
             onAcc: Color(hex: "#1a1206")),
        Skin(id: "mono", name: "Pure Black", bg: Color(hex: "#000000"), side: Color(hex: "#060606"), panel: Color(hex: "#0d0d0d"),
             panel2: Color(hex: "#161616"), track: Color(hex: "#262626"), line: darkLine, line2: darkLine2, ink: Color(hex: "#f5f5f5"),
             muted: Color(hex: "#9a9a9a"), dim: Color(hex: "#626262"), acc: Color(hex: "#f5f5f5"), hover: Color(hex: "#1f1f1f"),
             onAcc: .black),
        Skin(id: "paper", name: "Paper & Indigo", light: true, bg: Color(hex: "#f3f4f7"), side: Color(hex: "#eceef3"), panel: .white,
             panel2: Color(hex: "#f5f6f9"), track: Color(hex: "#e3e6ec"), line: Color(hex: "#0a1428", opacity: 0.08),
             line2: Color(hex: "#0a1428", opacity: 0.15), ink: Color(hex: "#12151c"), muted: Color(hex: "#5b6474"), dim: Color(hex: "#8a93a3"),
             acc: Color(hex: "#3b5bfd"), good: Color(hex: "#12a66a"), warn: Color(hex: "#c58610"), bad: Color(hex: "#e0484b"),
             blue: Color(hex: "#3b82f6"), hover: Color(hex: "#eceef4")),
        Skin(id: "sand", name: "Sand & Terracotta", light: true, bg: Color(hex: "#f5f1ea"), side: Color(hex: "#ede6db"), panel: Color(hex: "#fffdf9"),
             panel2: Color(hex: "#f7f2ea"), track: Color(hex: "#e8e0d3"), line: Color(hex: "#3c2814", opacity: 0.09),
             line2: Color(hex: "#3c2814", opacity: 0.17), ink: Color(hex: "#231a12"), muted: Color(hex: "#6f6254"), dim: Color(hex: "#9c8f80"),
             acc: Color(hex: "#d2583a"), good: Color(hex: "#2f9e6a"), warn: Color(hex: "#c4861c"), bad: Color(hex: "#d64545"),
             blue: Color(hex: "#3b7bd6"), hover: Color(hex: "#efe7da")),
    ]

    static let defaultAccents: [String: String] = [
        "coral": "#ff6a55", "midnight": "#4c8dff", "emerald": "#2ee59d", "plum": "#f5b342",
        "mono": "#f5f5f5", "paper": "#3b5bfd", "sand": "#d2583a",
    ]

    static func from(settings: Settings) -> Skin {
        var s = all.first { $0.id == (settings.theme ?? "coral") } ?? all[0]
        if let a = settings.accent, !a.isEmpty { s.acc = Color(hex: a) }
        return s
    }

    func kindColor(_ k: Kind) -> Color {
        switch k {
        case .p: return good
        case .n: return neu
        case .d: return bad
        }
    }

    func scoreColor(_ v: Int?) -> Color {
        guard let v else { return dim }
        return v >= 70 ? good : v >= 45 ? warn : bad
    }
}

private struct SkinKey: EnvironmentKey {
    static let defaultValue = Skin.all[0]
}

extension EnvironmentValues {
    var skin: Skin {
        get { self[SkinKey.self] }
        set { self[SkinKey.self] = newValue }
    }
}

enum Theme {
    /// Draws the clock icon in the current accent colour and sets it as the Dock icon.
    @MainActor
    static func applyDockIcon(settings: Settings) {
        let skin = Skin.from(settings: settings)
        NSApp.applicationIconImage = icon(accent: NSColor(skin.acc), on: NSColor(skin.onAcc), size: 512)
    }

    static func icon(accent: NSColor, on: NSColor, size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let s = size / 512
            let bg = NSBezierPath(roundedRect: NSRect(x: 40 * s, y: 40 * s, width: 432 * s, height: 432 * s), xRadius: 100 * s, yRadius: 100 * s)
            accent.setFill()
            bg.fill()
            NSGradient(starting: NSColor.white.withAlphaComponent(0.22), ending: NSColor.black.withAlphaComponent(0.18))?.draw(in: bg, angle: -90)
            on.setStroke()
            let ring = NSBezierPath(ovalIn: NSRect(x: 132 * s, y: 132 * s, width: 248 * s, height: 248 * s))
            ring.lineWidth = 34 * s
            ring.stroke()
            let hands = NSBezierPath()
            hands.move(to: NSPoint(x: 256 * s, y: 256 * s)); hands.line(to: NSPoint(x: 256 * s, y: 336 * s))
            hands.move(to: NSPoint(x: 256 * s, y: 256 * s)); hands.line(to: NSPoint(x: 310 * s, y: 222 * s))
            hands.lineWidth = 34 * s
            hands.lineCapStyle = .round
            hands.stroke()
            return true
        }
    }
}
