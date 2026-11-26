import Foundation

struct HabitStats {
    var cur = 0
    var best = 0
    var rate = 0
    var doneN = 0
    var schedN = 0
    var total: Double = 0
    var avgAt: Double?
}

/// Habits: tick-box or amount, with schedules, reminders and streaks.
extension AppModel {
    static let habitColors = ["#3ddc97", "#6ea8ff", "#ffc46b", "#b794ff", "#ff8a65", "#4dd4e8", "#f78fc3", "#9be15d"]

    static let quickHabits: [(name: String, kind: HabitKind, unit: String, target: Double)] = [
        ("Went for a run", .check, "", 0), ("Run distance", .number, "km", 5), ("Gym", .check, "", 0),
        ("Read", .number, "pages", 20), ("Meditate", .check, "", 0), ("Drink water", .number, "glasses", 8),
        ("Walk", .number, "steps", 8000), ("Sleep by 23:00", .check, "", 0),
    ]

    var habits: [Habit] { settings.habits }

    func habit(_ id: String) -> Habit? { settings.habits.first { $0.id == id } }

    func entry(_ id: String, _ key: String) -> HabitEntry? { hlog[key]?[id] }

    func isDone(_ h: Habit, _ e: HabitEntry?) -> Bool {
        guard let e else { return false }
        if h.kind == .number {
            let v = e.v ?? 0
            return h.target > 0 ? v >= h.target : v > 0
        }
        return e.done == true
    }

    func isDone(_ h: Habit, _ key: String) -> Bool { isDone(h, entry(h.id, key)) }

    func habitStats(_ h: Habit) -> HabitStats {
        var st = HabitStats()
        let today = Date()
        for i in 0..<400 {
            let k = Fmt.key(Fmt.addDays(today, -i))
            guard h.scheduled(k) else { continue }
            if isDone(h, k) { st.cur += 1 } else if i == 0 { continue } else { break }
        }
        var run = 0
        for i in stride(from: 364, through: 0, by: -1) {
            let k = Fmt.key(Fmt.addDays(today, -i))
            guard h.scheduled(k) else { continue }
            if isDone(h, k) { run += 1; st.best = max(st.best, run) } else if i > 0 { run = 0 }
        }
        let K = Fmt.lastNKeys(30)
        let tk = Fmt.todayKey
        let ks = K.filter { h.scheduled($0) && ($0 != tk || isDone(h, $0)) }
        let done = ks.filter { isDone(h, $0) }
        st.doneN = done.count
        st.schedN = ks.count
        st.rate = ks.isEmpty ? 0 : Int((Double(done.count) / Double(ks.count) * 100).rounded())
        st.total = K.reduce(0) { $0 + (entry(h.id, $1)?.v ?? 0) }
        let times = Fmt.lastNKeys(60).compactMap { Fmt.hmToMinutes(entry(h.id, $0)?.at) }
        if !times.isEmpty { st.avgAt = Double(times.reduce(0, +)) / Double(times.count) }
        return st
    }

    func setEntry(_ id: String, _ key: String, _ e: HabitEntry?) {
        guard Fmt.isEditable(key) else { return lockedToast(key) }
        if let e {
            hlog[key, default: [:]][id] = e
        } else {
            hlog[key]?[id] = nil
            if hlog[key]?.isEmpty == true { hlog[key] = nil }
        }
        Storage.write("habits.json", hlog)
    }

    func toggleHabit(_ id: String, _ key: String) {
        guard let h = habit(id) else { return }
        guard Fmt.isEditable(key) else { return lockedToast(key) }
        if h.kind == .number {
            habitEntryTarget = HabitEntryTarget(habitID: id, key: key)
            return
        }
        if isDone(h, key) {
            setEntry(id, key, nil)
        } else {
            let today = key == Fmt.todayKey
            setEntry(id, key, HabitEntry(done: true, at: today ? Fmt.nowHM() : ""))
            toast("\(h.name): done\(today ? " at " + Fmt.nowHM() : "")")
        }
    }

    /// Days older than `Fmt.editableDaysBack` (and future days) can't be logged or changed.
    func lockedToast(_ key: String) {
        toast(key > Fmt.todayKey ? "You can't log a day that hasn't happened yet"
              : "\(Fmt.shortDate(key)) is locked. You can only log today and the last \(Fmt.editableDaysBack) days")
    }

    @discardableResult
    func addHabit(name: String, kind: HabitKind, unit: String = "", target: Double = 0,
                  days: [Int] = [0, 1, 2, 3, 4, 5, 6], remind: String = "", color: String? = nil) -> Habit {
        let h = Habit(id: "h" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36) + String(Int.random(in: 0..<10000)),
                      name: name, kind: kind, unit: unit, target: target, days: days, remind: remind,
                      color: color ?? Self.habitColors[settings.habits.count % Self.habitColors.count])
        settings.habits.append(h)
        saveSettings()
        return h
    }

    func updateHabit(_ h: Habit) {
        if let i = settings.habits.firstIndex(where: { $0.id == h.id }) {
            settings.habits[i] = h
            saveSettings()
        }
    }

    func deleteHabit(_ id: String) {
        settings.habits.removeAll { $0.id == id }
        saveSettings()
        toast("Habit deleted")
    }

    /// Notifies once a day for each scheduled habit not done by its reminder time.
    func checkReminders() {
        let k = Fmt.todayKey
        let c = Fmt.calendar.dateComponents([.hour, .minute], from: Date())
        let m = c.hour! * 60 + c.minute!
        var fired = remindersFired[k] ?? [:]
        var any = false
        for h in habits {
            guard let r = Fmt.hmToMinutes(h.remind), h.scheduled(k), !isDone(h, k), fired[h.id] == nil, m >= r else { continue }
            fired[h.id] = 1
            any = true
            notify("Reminder: \(h.name). Tick it off in Spent or from the menu bar when it’s done.")
        }
        remindersFired = [k: fired]
        if any { Storage.write("reminders.json", remindersFired) }
    }
}
