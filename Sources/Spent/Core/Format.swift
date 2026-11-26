import Foundation

/// Time and date helpers shared across the app. Dates are keyed as "YYYY-MM-DD" in local time.
enum Fmt {
    static let hour: Double = 3600
    static let day: Double = 86400
    static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    static let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// "1h 23m", "45m", "12s"
    static func duration(_ seconds: Double) -> String {
        let s = Int((seconds.isFinite ? seconds : 0).rounded())
        if s < 60 { return "\(max(0, s))s" }
        let mt = Int((Double(s) / 60).rounded())
        let h = mt / 60, m = mt % 60
        if h >= 100 { return "\(h.formatted())h" }
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }

    /// "1:05:09" or "25:00"
    static func mmss(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        let h = s / 3600, m = (s % 3600) / 60, x = s % 60
        return h > 0 ? "\(h):\(pad(m)):\(pad(x))" : "\(m):\(pad(x))"
    }

    static func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

    static var calendar: Calendar { Calendar.current }

    static func key(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year!)-\(pad(c.month!))-\(pad(c.day!))"
    }

    static func key(epoch: Double) -> String { key(Date(timeIntervalSince1970: epoch)) }

    static func date(_ key: String) -> Date {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return Date() }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) ?? Date()
    }

    static var todayKey: String { key(Date()) }

    static func startOfDay(_ d: Date) -> Date { calendar.startOfDay(for: d) }

    static func addDays(_ d: Date, _ n: Int) -> Date {
        calendar.date(byAdding: .day, value: n, to: startOfDay(d)) ?? d
    }

    static func addDays(key: String, _ n: Int) -> String { self.key(addDays(date(key), n)) }

    /// "14:05"
    static func clock(_ epoch: Double) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: Date(timeIntervalSince1970: epoch))
        return "\(pad(c.hour!)):\(pad(c.minute!))"
    }

    /// Seconds since midnight → "HH:MM"
    static func timeOfDay(_ sec: Double) -> String {
        let s = Int(sec)
        return "\(pad((s / 3600) % 24)):\(pad((s % 3600) / 60))"
    }

    /// "3 Nov"
    static func shortDate(_ key: String) -> String {
        let d = date(key)
        let c = calendar.dateComponents([.day, .month], from: d)
        return "\(c.day!) \(months[c.month! - 1])"
    }

    static func weekday(_ key: String) -> Int { calendar.component(.weekday, from: date(key)) - 1 }
    static func weekdayName(_ key: String) -> String { weekdays[weekday(key)] }

    static func nowHM() -> String {
        let c = calendar.dateComponents([.hour, .minute], from: Date())
        return "\(pad(c.hour!)):\(pad(c.minute!))"
    }

    /// "07:30" → minutes since midnight
    static func hmToMinutes(_ s: String?) -> Int? {
        guard let s, let r = s.range(of: #"^(\d\d?):(\d\d)"#, options: .regularExpression) else { return nil }
        let parts = s[r].split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 ? parts[0] * 60 + parts[1] : nil
    }

    /// The last `n` day keys ending today (minus `offset` days), oldest first.
    static func lastNKeys(_ n: Int, offset: Int = 0) -> [String] {
        let end = addDays(Date(), -offset)
        return (0..<n).reversed().map { key(addDays(end, -$0)) }
    }

    static func percent(_ v: Double, of total: Double) -> Int {
        total > 0 ? Int((v / total * 100).rounded()) : 0
    }
}

extension Dictionary where Value == Double {
    /// Entries sorted by value, largest first.
    var sortedDesc: [(key: Key, value: Double)] {
        sorted { $0.value > $1.value }
    }
}
