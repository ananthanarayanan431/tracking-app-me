import Foundation

/// Turns iPhone bundle ids ("com.google.ios.youtube") into names ("YouTube").
/// Order: built-in table → cached App Store lookup → readable guess from the id.
/// Lookups use Apple's public iTunes Search API (only the bundle id is sent) and are cached
/// in ~/.spent/app-names.json along with the app's icon URL.
enum PhoneApps {
    struct Info: Codable {
        var name: String
        var artwork: String?
    }

    static let builtin: [String: String] = [
        "com.apple.mobilesafari": "Safari", "com.apple.MobileSMS": "Messages", "com.apple.mobilephone": "Phone",
        "com.apple.InCallService": "Phone", "com.apple.Preferences": "Settings", "com.apple.AppStore": "App Store",
        "com.apple.camera": "Camera", "com.apple.mobileslideshow": "Photos", "com.apple.Maps": "Apple Maps",
        "com.apple.Music": "Music", "com.apple.mobilemail": "Mail", "com.apple.mobilecal": "Calendar",
        "com.apple.mobilenotes": "Notes", "com.apple.reminders": "Reminders", "com.apple.MobileStore": "iTunes Store",
        "com.apple.facetime": "FaceTime", "com.apple.Health": "Health", "com.apple.Fitness": "Fitness",
        "com.apple.weather": "Weather", "com.apple.mobiletimer": "Clock", "com.apple.calculator": "Calculator",
        "com.apple.DocumentsApp": "Files", "com.apple.podcasts": "Podcasts", "com.apple.tv": "TV",
        "com.apple.news": "News", "com.apple.shortcuts": "Shortcuts", "com.apple.Passbook": "Wallet",
        "com.apple.iBooks": "Books", "com.apple.findmy": "Find My", "com.apple.Home": "Home",
        "com.apple.VoiceMemos": "Voice Memos", "com.apple.measure": "Measure", "com.apple.journal": "Journal",
        "com.apple.mobileme.fmip1": "Find My", "com.apple.Translate": "Translate", "com.apple.control-center": "Control Center",
        "net.whatsapp.WhatsApp": "WhatsApp", "net.whatsapp.WhatsAppSMB": "WhatsApp Business",
        "com.google.ios.youtube": "YouTube", "com.google.Gmail": "Gmail", "com.google.Dynamite": "Google Chat",
        "com.google.Maps": "Google Maps", "com.google.GoogleMobile": "Google", "com.google.chrome.ios": "Google Chrome",
        "com.google.photos": "Google Photos", "com.google.Drive": "Google Drive", "com.google.calendar": "Google Calendar",
        "com.google.Docs": "Google Docs", "com.google.meetings": "Google Meet", "com.google.ios.youtubemusic": "YouTube Music",
        "com.burbn.instagram": "Instagram", "com.facebook.Facebook": "Facebook", "com.atebits.Tweetie2": "X",
        "com.burbn.barcelona": "Threads", "com.zhiliaoapp.musically": "TikTok", "com.reddit.Reddit": "Reddit",
        "com.linkedin.LinkedIn": "LinkedIn", "com.toyopagroup.picaboo": "Snapchat", "pinterest": "Pinterest",
        "ph.telegra.Telegraph": "Telegram", "org.whispersystems.signal": "Signal", "com.hammerandchisel.discord": "Discord",
        "com.tinyspeck.chatlyio": "Slack", "com.microsoft.skype.teams": "Teams", "us.zoom.videomeetings": "Zoom",
        "com.spotify.client": "Spotify", "com.netflix.Netflix": "Netflix", "com.amazon.aiv.AIVApp": "Prime Video",
        "in.startv.hotstar": "Hotstar", "com.amazon.Amazon": "Amazon", "in.amazon.mShop.android.shopping": "Amazon",
        "com.appflipkart.flipkart": "Flipkart", "in.swiggy.ios": "Swiggy", "com.zomato.zomato": "Zomato",
        "com.grofers.consumer": "Blinkit", "com.openai.chat": "ChatGPT", "com.anthropic.claude": "Claude",
        "ai.perplexity.app": "Perplexity", "notion.id": "Notion", "com.ubercab.UberClient": "Uber",
        "com.phonepe.PhonePeApp": "PhonePe", "com.google.paisa": "Google Pay", "net.one97.paytm": "Paytm",
        "com.indwealth.INDWealth": "INDmoney", "com.duolingo.DuolingoMobile": "Duolingo", "com.medium.reader": "Medium",
    ]

    nonisolated(unsafe) private static var cache: [String: Info] = Storage.read("app-names.json", as: [String: Info].self) ?? [:]
    nonisolated(unsafe) private static var pending: Set<String> = []
    nonisolated(unsafe) private static var failed: Set<String> = []
    private static let lock = NSLock()

    /// Name to show for a bundle id. May queue a lookup; `onLearned` runs on main when names arrive.
    static func name(_ bundle: String, allowNetwork: Bool) -> String {
        if let n = builtin[bundle] { return n }
        lock.lock()
        let hit = cache[bundle]
        let shouldFetch = hit == nil && allowNetwork && !pending.contains(bundle) && !failed.contains(bundle)
        if shouldFetch { pending.insert(bundle) }
        lock.unlock()
        if let hit { return hit.name }
        if shouldFetch { fetch(bundle) }
        return guess(bundle)
    }

    /// App Store icon URL for a display name, if a lookup found one.
    static func artwork(forName name: String) -> URL? {
        lock.lock(); defer { lock.unlock() }
        return cache.values.first { $0.name == name }?.artwork.flatMap(URL.init(string:))
    }

    nonisolated(unsafe) static var onLearned: (() -> Void)?

    /// "com.indwealth.INDWealth" → "INDWealth"; "com.foo.app-name" → "App Name"
    static func guess(_ bundle: String) -> String {
        let parts = bundle.split(separator: ".").map(String.init)
        let skip: Set<String> = ["ios", "app", "iphone", "mobile", "client", "consumer", "ios-app"]
        let last = parts.reversed().first { !skip.contains($0.lowercased()) } ?? bundle
        let spaced = last.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
        return spaced.prefix(1).uppercased() + spaced.dropFirst()
    }

    /// "Gmail - Email by Google" → "Gmail"; "INDmoney: US Stocks, …" → "INDmoney"
    static func clean(_ storeName: String) -> String {
        var n = storeName
        for sep in [" - ", " – ", " — ", ": ", " | "] {
            if let r = n.range(of: sep) { n = String(n[..<r.lowerBound]) }
        }
        n = n.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? storeName : n
    }

    /// Stores a lookup result; synchronous so the lock is never held across an await.
    private static func record(_ bundle: String, _ info: Info?) -> [String: Info] {
        lock.lock(); defer { lock.unlock() }
        pending.remove(bundle)
        if let info { cache[bundle] = info } else { failed.insert(bundle) }
        return cache
    }

    private static func fetch(_ bundle: String) {
        Task.detached(priority: .utility) {
            let region = Locale.current.region?.identifier.lowercased() ?? "us"
            var info: Info?
            for country in Array(Set([region, "us"])) {
                guard let q = bundle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(q)&country=\(country)"),
                      let (data, resp) = try? await URLSession.shared.data(from: url),
                      (resp as? HTTPURLResponse)?.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let first = (json["results"] as? [[String: Any]])?.first,
                      let track = first["trackName"] as? String else { continue }
                info = Info(name: clean(track), artwork: first["artworkUrl100"] as? String)
                break
            }
            let snapshot = record(bundle, info)
            if info != nil {
                Storage.write("app-names.json", snapshot)
                await MainActor.run { onLearned?() }
            }
        }
    }
}
