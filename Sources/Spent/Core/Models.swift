import Foundation

enum Device: String, Codable, CaseIterable {
    case mac, phone
}

/// One continuous stretch of time in one app (and site, page and browser profile).
struct Segment: Codable, Hashable {
    var s: Double
    var e: Double
    var app: String
    var dom: String = ""
    var title: String = ""
    var prof: String = ""
    var dev: Device = .mac

    var duration: Double { max(0, e - s) }
}

/// A run of merged segments, with every page title seen during it.
struct Session: Identifiable, Hashable {
    var id: Double { s }
    var s: Double
    var e: Double
    var app: String
    var dom: String
    var prof: String
    var dev: Device
    var titles: [String]
}

/// Productive / neutral / distracting.
enum Kind: String, Codable, CaseIterable, Identifiable {
    case p, n, d
    var id: String { rawValue }
    var label: String {
        switch self {
        case .p: return "Productive"
        case .n: return "Neutral"
        case .d: return "Distracting"
        }
    }
}

struct Override: Codable, Hashable {
    var cat: String?
    var type: Kind?
}

enum LimitKind: String, Codable, CaseIterable {
    case app, site, cat
    var label: String {
        switch self {
        case .app: return "App"
        case .site: return "Website"
        case .cat: return "Category"
        }
    }
}

struct Limit: Codable, Hashable, Identifiable {
    var kind: LimitKind
    var name: String
    var min: Double
    var id: String { "\(kind.rawValue):\(name)" }
}

struct Goals: Codable, Hashable {
    var cap: Double = 0
    var dis: Double = 0
    var prod: Double = 0
    var any: Bool { cap > 0 || dis > 0 || prod > 0 }
}

enum HabitKind: String, Codable {
    case check, number
}

struct Habit: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var kind: HabitKind = .check
    var unit: String = ""
    var target: Double = 0
    var days: [Int] = [0, 1, 2, 3, 4, 5, 6]
    var remind: String = ""
    var color: String

    func scheduled(_ key: String) -> Bool {
        days.isEmpty || days.count == 7 || days.contains(Fmt.weekday(key))
    }

    var daysText: String {
        if days.isEmpty || days.count == 7 { return "Every day" }
        return [1, 2, 3, 4, 5, 6, 0].filter { days.contains($0) }.map { Fmt.weekdays[$0] }.joined(separator: ", ")
    }
}

struct HabitEntry: Codable, Hashable {
    var done: Bool?
    var v: Double?
    var at: String?
    var note: String?
}

struct Campaign: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var goal: String = ""
    var start: String
    var days: Int
    var color: String
    var habit: String = ""

    var dayKeys: [String] { (0..<days).map { Fmt.addDays(key: start, $0) } }
    var end: String { Fmt.addDays(key: start, max(0, days - 1)) }
}

struct CampaignMark: Codable, Hashable {
    var at: String = ""
}

struct Activity: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var color: String
    var habit: String = ""
}

struct AwayEntry: Codable, Hashable {
    var s: Double
    var e: Double
    var act: String
    var name: String
    var color: String
    var skip: Bool?
}

/// A gap in Mac activity long enough to ask about.
struct Gap: Hashable, Identifiable {
    var s: Double
    var e: Double
    var ph: Double = 0
    var id: Double { s }
}

struct FocusLog: Codable, Hashable {
    var s: Double
    var e: Double
    var planned: Double
    var label: String
    var done: Bool
    var dist: Int
}

struct FocusState: Codable, Hashable {
    var running = false
    var endsAt: Double = 0
    var remaining: Double = 1500
    var planned: Double = 1500
    var label = ""
    var startedAt: Double = 0
    var dist = 0
}

struct ManualPhone: Codable, Hashable {
    var date: String
    var app: String
    var min: Double
}

struct Privacy: Codable, Hashable {
    var ai = true
    var logos = true
}

struct Settings: Codable {
    var overrides: [String: Override] = [:]
    var limits: [Limit] = []
    var goals = Goals()
    var habits: [Habit] = []
    var campaigns: [Campaign] = []
    var acts: [Activity]?
    var theme: String?
    var accent: String?
    var awayOn: Bool?
    var awayPop: Bool?
    var awayMin: Int?
    var privacy = Privacy()
    var idleSeconds: Int?
    var aiModel: String?

    init() {}

    // Lenient decoding: every field is optional on disk so older or hand-edited files still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        overrides = (try? c.decode([String: Override].self, forKey: .overrides)) ?? [:]
        limits = (try? c.decode([Limit].self, forKey: .limits)) ?? []
        goals = (try? c.decode(Goals.self, forKey: .goals)) ?? Goals()
        habits = (try? c.decode([Habit].self, forKey: .habits)) ?? []
        campaigns = (try? c.decode([Campaign].self, forKey: .campaigns)) ?? []
        acts = try? c.decode([Activity].self, forKey: .acts)
        theme = try? c.decode(String.self, forKey: .theme)
        accent = try? c.decode(String.self, forKey: .accent)
        awayOn = try? c.decode(Bool.self, forKey: .awayOn)
        awayPop = try? c.decode(Bool.self, forKey: .awayPop)
        awayMin = try? c.decode(Int.self, forKey: .awayMin)
        privacy = (try? c.decode(Privacy.self, forKey: .privacy)) ?? Privacy()
        idleSeconds = try? c.decode(Int.self, forKey: .idleSeconds)
        aiModel = try? c.decode(String.self, forKey: .aiModel)
    }
}
