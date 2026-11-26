import Foundation

/// iPhone time comes from a text file that iOS Shortcuts automations append to in iCloud
/// Drive. Each line is "ISO-date|App" with an optional "|open" or "|close".
enum PhoneImport {
    struct Result {
        var byDay: [String: [Segment]] = [:]
        var events = 0
        var last: Double?
        var path = ""
    }

    static func candidatePaths(custom: String) -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            custom,
            "\(home)/Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents/Spent/phone.txt",
            "\(home)/Library/Mobile Documents/com~apple~CloudDocs/Shortcuts/Spent/phone.txt",
            "\(home)/Library/Mobile Documents/com~apple~CloudDocs/Spent/phone.txt",
        ].filter { !$0.isEmpty }
    }

    static func load(custom: String) -> Result {
        for p in candidatePaths(custom: custom) {
            if let text = try? String(contentsOfFile: p, encoding: .utf8) {
                var r = parse(text)
                r.path = p
                return r
            }
        }
        return Result()
    }

    static func parseDate(_ raw: String) -> Double? {
        let s = raw.replacingOccurrences(of: " at ", with: " ")
        let iso = ISO8601DateFormatter()
        for opts: ISO8601DateFormatter.Options in [[.withInternetDateTime], [.withInternetDateTime, .withFractionalSeconds],
                                                    [.withFullDate, .withTime, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime]] {
            iso.formatOptions = opts
            if let d = iso.date(from: s) { return d.timeIntervalSince1970 }
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "d MMM yyyy HH:mm", "MMM d, yyyy h:mm a", "d MMM yyyy h:mm a"] {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d.timeIntervalSince1970 }
        }
        return nil
    }

    static func parse(_ text: String, now: Double = Date().timeIntervalSince1970) -> Result {
        struct Ev { var t: Double; var app: String; var kind: String }
        var ev: [Ev] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let p = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            guard p.count >= 2, !p[1].isEmpty, let t = parseDate(p[0]) else { continue }
            ev.append(Ev(t: t, app: p[1], kind: p.count > 2 ? p[2].lowercased() : ""))
        }
        ev.sort { $0.t < $1.t }

        var segs: [Segment] = []
        var open: (s: Double, app: String)?
        func close(_ t: Double) {
            if let o = open {
                let e = min(t, o.s + 2 * Fmt.hour)
                if e > o.s { segs.append(Segment(s: o.s, e: e, app: o.app, dev: .phone)) }
                open = nil
            }
        }
        for x in ev {
            if x.kind == "close" {
                if open?.app == x.app { close(x.t) }
                continue
            }
            if x.kind == "open" {
                close(x.t)
                open = (x.t, x.app)
                continue
            }
            // No open/close marker: the same app again closes it, another app switches.
            if open?.app == x.app { close(x.t) } else { close(x.t); open = (x.t, x.app) }
        }
        if let o = open { close(min(now, o.s + 15 * 60)) }

        var r = Result()
        for s in segs { r.byDay[Fmt.key(epoch: s.s), default: []].append(s) }
        r.events = ev.count
        r.last = ev.last?.t
        return r
    }
}
