import AppKit
import SwiftUI

/// Icons8 icons (iOS outlined + iOS filled packs, see icons8.json), bundled as PNGs at 1x/2x/3x in
/// Contents/Resources/Icons and used as template images so they take the theme colour.
/// Free Icons8 icons: credited in Settings › About. Falls back to SF Symbols when the PNGs aren't
/// bundled (e.g. `swift run`).
enum AppIcon: String, CaseIterable {
    case overview, insights, focus, habits, campaigns, deskbreak, aadat, limits, settings
    case clock, walk, laptop, iphone, moon, pause, play, back, forward, close, check

    var fallbackSymbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .focus: return "scope"
        case .habits: return "checkmark.square"
        case .campaigns: return "flag"
        case .deskbreak: return "drop"
        case .aadat: return "checklist"
        case .limits: return "bell"
        case .settings: return "gearshape"
        case .clock: return "clock"
        case .walk: return "figure.walk"
        case .laptop: return "laptopcomputer"
        case .iphone: return "iphone"
        case .moon: return "moon"
        case .pause: return "pause"
        case .play: return "play"
        case .back: return "chevron.left"
        case .forward: return "chevron.right"
        case .close: return "xmark"
        case .check: return "checkmark"
        }
    }

    private static var cache: [String: NSImage] = [:]

    /// The icon as a template NSImage of `points` size, or nil if not bundled.
    func image(filled: Bool = false, points: CGFloat = 24) -> NSImage? {
        let name = rawValue + (filled ? "-filled" : "")
        let key = "\(name)@\(points)"
        if let hit = Self.cache[key] { return hit }
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("Icons") else { return nil }
        let img = NSImage(size: NSSize(width: points, height: points))
        for suffix in ["", "@2x", "@3x"] {
            let url = dir.appendingPathComponent("\(name)\(suffix).png")
            guard let data = try? Data(contentsOf: url), let rep = NSBitmapImageRep(data: data) else { continue }
            rep.size = NSSize(width: points, height: points)
            img.addRepresentation(rep)
        }
        guard !img.representations.isEmpty else { return nil }
        img.isTemplate = true
        Self.cache[key] = img
        return img
    }
}

/// SwiftUI view for an Icons8 icon; tinted by `.foregroundStyle`.
struct Icon: View {
    var icon: AppIcon
    var filled = false
    var size: CGFloat = 18

    init(_ icon: AppIcon, filled: Bool = false, size: CGFloat = 18) {
        self.icon = icon
        self.filled = filled
        self.size = size
    }

    var body: some View {
        if let img = icon.image(filled: filled, points: size) {
            Image(nsImage: img)
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            Image(systemName: icon.fallbackSymbol + (filled && icon.hasFilledSymbol ? ".fill" : ""))
                .font(.system(size: size * 0.8))
                .frame(width: size, height: size)
        }
    }
}

private extension AppIcon {
    var hasFilledSymbol: Bool {
        [.habits, .campaigns, .deskbreak, .limits, .settings].contains(self)
    }
}

extension Tab {
    var icon: AppIcon {
        switch self {
        case .overview: return .overview
        case .insights: return .insights
        case .focus: return .focus
        case .habits: return .habits
        case .campaigns: return .campaigns
        case .deskbreak: return .deskbreak
        case .aadat: return .aadat
        case .limits: return .limits
        case .settings: return .settings
        }
    }
}
