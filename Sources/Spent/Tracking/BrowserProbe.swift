import Foundation

/// Reads the active tab (URL, title) and browser profile from the frontmost browser via
/// AppleScript. macOS asks once per browser for Automation permission; if it's denied we
/// just record the browser name.
enum BrowserProbe {
    struct Result {
        var domain = ""
        var title = ""
        var profile = ""
    }

    static let chromium: Set<String> = ["Google Chrome", "Google Chrome Canary", "Brave Browser", "Brave Browser Beta",
                                        "Microsoft Edge", "Arc", "Comet", "Chromium", "Vivaldi", "Opera", "Dia"]
    static let safari: Set<String> = ["Safari", "Safari Technology Preview"]
    static let windowTitleOnly: Set<String> = ["Firefox", "Zen"]

    static func supports(_ app: String) -> Bool {
        chromium.contains(app) || safari.contains(app) || windowTitleOnly.contains(app)
    }

    private static let sep = "\u{1F}"

    /// Must be called off the main thread; AppleScript calls can take a moment.
    static func probe(app: String) -> Result? {
        let script: String
        if chromium.contains(app) {
            script = """
            tell application "\(app)"
              if (count of windows) = 0 then return ""
              set w to front window
              set u to ""
              set t to ""
              set n to ""
              set g to ""
              set m to ""
              try
                set u to URL of active tab of w
                set t to title of active tab of w
              end try
              try
                set n to name of w
              end try
              try
                set g to given name of w
              end try
              try
                set m to mode of w
              end try
              set s to character id 31
              return u & s & t & s & n & s & g & s & m
            end tell
            """
        } else if safari.contains(app) {
            script = """
            tell application "\(app)"
              if (count of windows) = 0 then return ""
              return (URL of current tab of front window) & (character id 31) & (name of current tab of front window)
            end tell
            """
        } else if windowTitleOnly.contains(app) {
            script = """
            tell application "System Events" to tell (first process whose frontmost is true) to return "" & (character id 31) & (name of front window)
            """
        } else {
            return nil
        }

        var err: NSDictionary?
        guard let out = NSAppleScript(source: script)?.executeAndReturnError(&err).stringValue, !out.isEmpty else {
            return nil
        }
        let parts = out.components(separatedBy: sep)
        let url = parts.count > 0 ? parts[0] : ""
        let title = parts.count > 1 ? parts[1] : ""
        let windowName = parts.count > 2 ? parts[2] : ""
        let givenName = parts.count > 3 ? parts[3] : ""
        let mode = parts.count > 4 ? parts[4] : ""

        var r = Result(domain: domain(of: url), title: title)
        if !givenName.isEmpty, givenName != "missing value" {
            r.profile = givenName
        } else if !windowName.isEmpty, windowName != title, windowName.hasPrefix(title + " - ") {
            var p = String(windowName.dropFirst(title.count + 3))
            for prefix in ["Brave - ", "Google Chrome - "] where p.hasPrefix(prefix) { p = String(p.dropFirst(prefix.count)) }
            if p.hasSuffix(" - Brave") { p = String(p.dropLast(8)) }
            r.profile = p
        }
        if r.profile.isEmpty { r.profile = ProfileReader.lastUsedProfile(app: app) }
        if mode == "incognito" { r.profile = "Private" }
        return r
    }

    /// "https://www.github.com/foo?x" → "github.com"
    static func domain(of url: String) -> String {
        var s = url
        if let r = s.range(of: #"^[a-zA-Z-]+://"#, options: .regularExpression) { s.removeSubrange(r) }
        if let i = s.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) { s = String(s[..<i]) }
        if s.hasPrefix("www.") { s = String(s.dropFirst(4)) }
        return s
    }
}

/// Falls back to Chromium's "Local State" file to name the profile in use, when the window
/// title doesn't say. Only meaningful when more than one profile exists.
enum ProfileReader {
    private static var cache: [String: (mtime: Date, name: String)] = [:]
    private static let lock = NSLock()

    static func localStatePath(app: String) -> String? {
        let base = FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Application Support/"
        switch app {
        case "Brave Browser": return base + "BraveSoftware/Brave-Browser/Local State"
        case "Brave Browser Beta": return base + "BraveSoftware/Brave-Browser-Beta/Local State"
        case "Google Chrome": return base + "Google/Chrome/Local State"
        case "Microsoft Edge": return base + "Microsoft Edge/Local State"
        case "Vivaldi": return base + "Vivaldi/Local State"
        case "Chromium": return base + "Chromium/Local State"
        default: return nil
        }
    }

    static func lastUsedProfile(app: String) -> String {
        guard let path = localStatePath(app: app),
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let mtime = attrs[.modificationDate] as? Date else { return "" }
        lock.lock(); defer { lock.unlock() }
        if let c = cache[path], c.mtime == mtime { return c.name }
        var name = ""
        if let data = FileManager.default.contents(atPath: path),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let profile = json["profile"] as? [String: Any],
           let info = profile["info_cache"] as? [String: [String: Any]], info.count >= 2 {
            let last = profile["last_used"] as? String ?? "Default"
            if let entry = info[last] {
                let n = entry["name"] as? String ?? last
                if let given = entry["gaia_given_name"] as? String, !given.isEmpty, n == last {
                    name = given
                } else {
                    name = n
                }
            } else {
                name = last
            }
        }
        cache[path] = (mtime, name)
        return name
    }
}
