import AppKit
import Observation

/// Real logos everywhere: app icons come from the apps on this Mac; website icons (and iPhone
/// apps without a Mac version) are fetched once by domain and cached in ~/.spent/icons.
@MainActor
@Observable
final class IconProvider {
    static let shared = IconProvider()

    private(set) var images: [String: NSImage] = [:]
    @ObservationIgnored private var tried: Set<String> = []
    @ObservationIgnored private var running = 0
    @ObservationIgnored private var queue: [String] = []
    /// Website icons need the network; Settings › Privacy can switch that off.
    @ObservationIgnored var allowNetwork = true

    nonisolated static let knownDomains: [String: String] = [
        "Instagram": "instagram.com", "YouTube": "youtube.com", "WhatsApp": "whatsapp.com", "X": "x.com", "Twitter": "x.com",
        "Gmail": "mail.google.com", "Spotify": "spotify.com", "Netflix": "netflix.com", "Snapchat": "snapchat.com",
        "Facebook": "facebook.com", "LinkedIn": "linkedin.com", "Reddit": "reddit.com", "Telegram": "telegram.org",
        "Threads": "threads.net", "TikTok": "tiktok.com", "Amazon": "amazon.in", "Swiggy": "swiggy.com", "Zomato": "zomato.com",
        "Pinterest": "pinterest.com", "Prime Video": "primevideo.com", "Hotstar": "hotstar.com", "JioHotstar": "hotstar.com",
        "Discord": "discord.com", "Slack": "slack.com", "ChatGPT": "chatgpt.com", "Claude": "claude.ai", "Uber": "uber.com",
        "Google Maps": "maps.google.com", "Notion": "notion.so", "Zoom": "zoom.us", "Teams": "teams.microsoft.com",
        "Outlook": "outlook.com", "Paytm": "paytm.com", "PhonePe": "phonepe.com", "Google Pay": "pay.google.com",
        "Blinkit": "blinkit.com", "Zepto": "zeptonow.com", "Myntra": "myntra.com", "Flipkart": "flipkart.com",
        "Medium": "medium.com", "Duolingo": "duolingo.com", "Cursor": "cursor.com", "Figma": "figma.com", "Arc": "arc.net",
        "Perplexity": "perplexity.ai", "Comet": "perplexity.ai", "Linear": "linear.app", "Obsidian": "obsidian.md",
        "Warp": "warp.dev", "Postman": "postman.com", "Raycast": "raycast.com", "Canva": "canva.com", "Loom": "loom.com",
        "Signal": "signal.org", "Zed": "zed.dev", "Ghostty": "ghostty.org", "Dia": "diabrowser.com",
    ]

    /// kind is "app" or "site".
    func image(kind: String, name: String) -> NSImage? {
        let k = kind + ":" + name
        if let img = images[k] { return img }
        if !tried.contains(k) {
            tried.insert(k)
            queue.append(k)
            pump()
        }
        return nil
    }

    func retry() {
        tried = Set(images.keys)
        images = images
    }

    var loadedCount: Int { images.count }

    private func pump() {
        while running < 4, !queue.isEmpty {
            let k = queue.removeFirst()
            running += 1
            let i = k.firstIndex(of: ":")!
            let kind = String(k[..<i]), name = String(k[k.index(after: i)...])
            let net = allowNetwork
            Task.detached(priority: .utility) {
                let img = Self.load(kind: kind, name: name, network: net)
                await MainActor.run {
                    if let img { self.images[k] = img }
                    self.running -= 1
                    self.pump()
                }
            }
        }
    }

    nonisolated static func cacheURL(kind: String, name: String) -> URL {
        let safe = String(name.map { $0.isLetter || $0.isNumber || "._-".contains($0) ? $0 : "_" })
        return Storage.iconsDir.appendingPathComponent("\(kind)-\(safe).png")
    }

    nonisolated static func load(kind: String, name: String, network: Bool) -> NSImage? {
        let file = cacheURL(kind: kind, name: name)
        if let img = NSImage(contentsOf: file) { return img }
        if kind == "app" {
            if let path = appPath(name) {
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 64, height: 64)
                save(icon, to: file)
                return icon
            }
            if network, let dom = knownDomains[name] { return favicon(dom, to: file) }
            return nil
        }
        return network ? favicon(name, to: file) : nil
    }

    nonisolated static func appPath(_ name: String) -> String? {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }), let url = app.bundleURL {
            return url.path
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for dir in ["/Applications", "/System/Applications", "/System/Applications/Utilities", "/Applications/Utilities",
                    "\(home)/Applications", "/System/Library/CoreServices", "/Applications/Setapp"] {
            let p = "\(dir)/\(name).app"
            if FileManager.default.fileExists(atPath: p) { return p }
        }
        return nil
    }

    nonisolated static func favicon(_ domain: String, to file: URL) -> NSImage? {
        let host = domain.split(separator: ":").first.map(String.init) ?? domain
        guard host.contains("."),
              let q = host.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else { return nil }
        let sources = ["https://www.google.com/s2/favicons?domain=\(q)&sz=128",
                       "https://\(q)/apple-touch-icon.png",
                       "https://icons.duckduckgo.com/ip3/\(q).ico"]
        for src in sources {
            guard let url = URL(string: src) else { continue }
            var req = URLRequest(url: url, timeoutInterval: 8)
            req.setValue("Spent", forHTTPHeaderField: "User-Agent")
            let sem = DispatchSemaphore(value: 0)
            var data: Data?
            URLSession.shared.dataTask(with: req) { d, r, _ in
                if (r as? HTTPURLResponse)?.statusCode == 200 { data = d }
                sem.signal()
            }.resume()
            sem.wait()
            if let data, data.count > 100, let img = NSImage(data: data), img.isValid {
                save(img, to: file)
                return img
            }
        }
        return nil
    }

    nonisolated static func save(_ img: NSImage, to file: URL) {
        guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: file)
    }
}
