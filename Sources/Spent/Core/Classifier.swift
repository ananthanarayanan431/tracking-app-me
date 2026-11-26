import Foundation

/// Maps apps and websites to categories and productive/neutral/distracting labels,
/// honouring the user's overrides from Settings › Labels.
final class Classifier {
    static let browsers: Set<String> = [
        "Google Chrome", "Safari", "Arc", "Brave Browser", "Microsoft Edge", "Comet", "Firefox", "Chromium",
        "Vivaldi", "Opera", "Dia", "Safari Technology Preview", "Google Chrome Canary", "Zen",
    ]

    static let rules: [(String, [String])] = [
        ("AI", ["claude", "chatgpt", "openai", "gemini", "perplexity", "anthropic", "copilot"]),
        ("Social", ["instagram", "facebook", "twitter", "x.com", "threads", "linkedin", "reddit", "snapchat", "tiktok", "pinterest", "^x$"]),
        ("Entertainment", ["youtube", "netflix", "prime", "hotstar", "spotify", "music", "twitch", "jiocinema", "tv", "podcast", "games"]),
        ("Communication", ["whatsapp", "telegram", "slack", "messages", "mail", "gmail", "zoom", "teams", "discord", "facetime", "meet.google", "outlook", "signal"]),
        ("Development", ["code", "cursor", "terminal", "iterm", "xcode", "github", "warp", "zed", "docker", "postman", "stackoverflow", "vercel", "localhost", "ghostty"]),
        ("Productivity", ["notion", "docs.google", "sheets", "calendar", "figma", "excel", "word", "powerpoint", "keynote", "pages", "numbers", "finder", "linear", "jira", "obsidian", "notes", "drive"]),
        ("Shopping", ["amazon", "flipkart", "myntra", "swiggy", "zomato", "blinkit"]),
        ("News & reading", ["news", "medium", "substack", "hacker", "wikipedia", "kindle", "books"]),
    ]

    static let categoryColors: [String: String] = [
        "AI": "#ff6a55", "Social": "#f78fc3", "Entertainment": "#b794ff", "Communication": "#4dd4e8",
        "Development": "#6ea8ff", "Productivity": "#3ddc97", "Shopping": "#ffc46b", "News & reading": "#e9a66b",
        "Browsing": "#8c9bff", "Other": "#5f6878",
    ]

    static let categories = ["AI", "Social", "Entertainment", "Communication", "Development", "Productivity",
                             "Shopping", "News & reading", "Browsing", "Other"]

    static let defaultKind: [String: Kind] = [
        "Development": .p, "Productivity": .p, "AI": .p, "Communication": .n, "Browsing": .n,
        "News & reading": .n, "Other": .n, "Social": .d, "Entertainment": .d, "Shopping": .d,
    ]

    static let kindColors: [Kind: String] = [.p: "#3ddc97", .n: "#8b9bb4", .d: "#ff6b6b"]

    var overrides: [String: Override] = [:] {
        didSet { memo.removeAll() }
    }
    private var memo: [String: (String, Kind)] = [:]

    static func builtinCategory(app: String, dom: String) -> String {
        func match(_ s: String) -> String? {
            let s = s.lowercased()
            guard !s.isEmpty else { return nil }
            for (cat, keys) in rules {
                for k in keys {
                    if k.hasPrefix("^") {
                        if s.range(of: k, options: .regularExpression) != nil { return cat }
                    } else if s.contains(k) {
                        return cat
                    }
                }
            }
            return nil
        }
        return match(dom) ?? match(app) ?? (browsers.contains(app) ? "Browsing" : "Other")
    }

    func classify(app: String, dom: String = "", prof: String = "") -> (cat: String, kind: Kind) {
        let k = app + "\u{1}" + dom + "\u{1}" + prof
        if let r = memo[k] { return r }
        let o = (dom.isEmpty ? nil : overrides["site:" + dom])
            ?? (prof.isEmpty ? nil : overrides["prof:" + app + " · " + prof])
            ?? overrides["app:" + app]
            ?? Override()
        let cat = o.cat ?? Self.builtinCategory(app: app, dom: dom)
        let r = (cat, o.type ?? Self.defaultKind[cat] ?? .n)
        memo[k] = r
        return r
    }

    /// Stable hash of the overrides, used to invalidate cached summaries.
    var overridesHash: String {
        let enc = JSONEncoder()
        enc.outputFormatting = .sortedKeys
        let data = (try? enc.encode(overrides)) ?? Data()
        var h: UInt32 = 2_166_136_261
        for b in data { h = (h ^ UInt32(b)) &* 16_777_619 }
        return String(h)
    }
}

/// Colours for apps/sites: assigned from a palette in order of first appearance, so the
/// biggest item in a period gets the first colour.
final class Palette {
    static let shared = Palette()
    static let colors = ["#6ea8ff", "#3ddc97", "#ffc46b", "#b794ff", "#ff8a65", "#4dd4e8",
                         "#f78fc3", "#9be15d", "#e9a66b", "#8c9bff", "#3cc6b4", "#ff7085"]
    private var map: [String: String] = [:]
    private var idx = 0

    func color(_ name: String) -> String {
        if name == "Other" { return "#5f6878" }
        if let c = map[name] { return c }
        let c = Self.colors[idx % Self.colors.count]
        idx += 1
        map[name] = c
        return c
    }
}
