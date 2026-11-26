import Foundation

enum Tab: String, CaseIterable, Identifiable {
    case overview, insights, focus, habits, campaigns, limits, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .insights: return "Insights"
        case .focus: return "Focus"
        case .habits: return "Habits"
        case .campaigns: return "Campaigns"
        case .limits: return "Limits & alerts"
        case .settings: return "Settings"
        }
    }
    var navTitle: String { self == .limits ? "Limits" : title }
    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .focus: return "scope"
        case .habits: return "checkmark.square"
        case .campaigns: return "flag"
        case .limits: return "bell"
        case .settings: return "gearshape"
        }
    }
}

enum PeriodView: String, CaseIterable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum DeviceFilter: String, CaseIterable, Identifiable {
    case all, mac, phone
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .mac: return "Mac"
        case .phone: return "iPhone"
        }
    }
}

/// A span of days. `keys` stops at today; `all` covers the whole period.
struct DayRange {
    var start: Date
    var end: Date
    var keys: [String]
    var all: [String]
    var label: String

    static func period(_ v: PeriodView, anchor a: Date) -> DayRange {
        let cal = Fmt.calendar
        let today = Date()
        var s: Date, e: Date, label: String
        switch v {
        case .day:
            s = Fmt.startOfDay(a)
            e = Fmt.addDays(s, 1)
            let k = Fmt.key(s)
            if k == Fmt.todayKey { label = "Today" }
            else if k == Fmt.key(Fmt.addDays(today, -1)) { label = "Yesterday" }
            else { label = "\(Fmt.weekdayName(k)) \(Fmt.shortDate(k))" }
        case .week:
            let wd = cal.component(.weekday, from: a) - 1
            s = Fmt.addDays(a, -((wd + 6) % 7))
            e = Fmt.addDays(s, 7)
            label = "\(Fmt.shortDate(Fmt.key(s))) – \(Fmt.shortDate(Fmt.key(Fmt.addDays(e, -1))))"
        case .month:
            let c = cal.dateComponents([.year, .month], from: a)
            s = cal.date(from: c)!
            e = cal.date(byAdding: .month, value: 1, to: s)!
            label = "\(Fmt.months[c.month! - 1]) \(c.year!)"
        case .year:
            let y = cal.component(.year, from: a)
            s = cal.date(from: DateComponents(year: y, month: 1, day: 1))!
            e = cal.date(from: DateComponents(year: y + 1, month: 1, day: 1))!
            label = "\(y)"
        }
        var all: [String] = []
        var d = s
        while d < e {
            all.append(Fmt.key(d))
            d = Fmt.addDays(d, 1)
        }
        let tk = Fmt.todayKey
        return DayRange(start: s, end: e, keys: all.filter { $0 <= tk }, all: all, label: label)
    }

    static func lastN(_ n: Int, offset: Int = 0) -> DayRange {
        let keys = Fmt.lastNKeys(n, offset: offset)
        let s = Fmt.date(keys[0])
        return DayRange(start: s, end: Fmt.addDays(Fmt.date(keys.last!), 1), keys: keys, all: keys, label: "Last \(n) days")
    }

    static func shift(_ v: PeriodView, _ a: Date, by n: Int) -> Date {
        let cal = Fmt.calendar
        switch v {
        case .day: return Fmt.addDays(a, n)
        case .week: return Fmt.addDays(a, 7 * n)
        case .month: return cal.date(byAdding: .month, value: n, to: a) ?? a
        case .year: return cal.date(byAdding: .year, value: n, to: a) ?? a
        }
    }
}

struct DayData: Identifiable {
    var k: String
    var mac: Summary
    var ph: Summary
    var id: String { k }

    func pick(_ dev: DeviceFilter) -> Summary {
        switch dev {
        case .mac: return mac
        case .phone: return ph
        case .all: return Summarizer.merge([mac, ph])
        }
    }
}
