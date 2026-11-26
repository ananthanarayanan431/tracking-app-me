import AppKit

/// "You were away 42m — what were you doing?" Gaps in Mac activity (not explained by
/// iPhone use) are logged as activities, which can tick habits.
extension AppModel {
    static func defaultActivities(habits: [Habit]) -> [Activity] {
        let defs: [(String, String, String)] = [
            ("Run", "#3ddc97", "run"), ("Gym", "#ff8a65", "gym|workout"), ("Walk", "#9be15d", "walk"),
            ("Meal", "#ffc46b", ""), ("Meeting", "#6ea8ff", ""), ("Phone call", "#4dd4e8", ""), ("Break", "#b794ff", ""),
            ("Commute", "#e9a66b", ""), ("Nap", "#8c9bff", ""), ("Chores", "#f78fc3", ""),
        ]
        return defs.enumerated().map { i, d in
            let linked = d.2.isEmpty ? "" : habits.first { $0.name.range(of: d.2, options: [.regularExpression, .caseInsensitive]) != nil }?.id ?? ""
            return Activity(id: "a\(i)", name: d.0, color: d.1, habit: linked)
        }
    }

    var activities: [Activity] { settings.acts ?? [] }

    var awayOn: Bool { settings.awayOn != false }

    func logAway(_ g: Gap, activityID: String, custom: String = "") {
        let skip = activityID == "skip"
        let a = activities.first { $0.id == activityID }
        let name = skip ? "Idle" : a?.name ?? (custom.isEmpty ? "Other" : custom)
        away.removeAll { abs($0.s - g.s) < 90 }
        away.append(AwayEntry(s: g.s, e: g.e, act: a?.id ?? "", name: name,
                              color: skip ? "#3a414d" : a?.color ?? "#8b9bb4", skip: skip ? true : nil))
        Storage.write("away.json", away)
        if let p = pendingGap, abs(p.s - g.s) < 90 { pendingGap = nil }
        awayPrompt = nil
        revision += 1

        if let hid = a?.habit, !hid.isEmpty, let h = habit(hid) {
            let k = Fmt.key(epoch: g.s)
            var e0 = entry(h.id, k) ?? HabitEntry()
            if h.kind == .number, h.unit.lowercased().hasPrefix("min") {
                e0.v = (e0.v ?? 0) + ((g.e - g.s) / 60).rounded()
                e0.at = e0.at?.isEmpty == false ? e0.at : Fmt.clock(g.s)
                setEntry(h.id, k, e0)
            } else if h.kind == .number {
                habitEntryTarget = HabitEntryTarget(habitID: h.id, key: k)
                toast("\(name) logged. How much \(h.unit)?")
                return
            } else {
                e0.done = true
                e0.at = Fmt.clock(g.s)
                setEntry(h.id, k, e0)
            }
            toast("\(name) logged · \(h.name) ticked")
        } else {
            toast(skip ? "Marked as idle" : "\(name) logged")
        }
    }

    /// Finds the latest unlogged gap today and, if it just ended, asks about it.
    func checkAway() {
        guard !paused, awayOn else { return }
        let k = Fmt.todayKey
        let gs = gaps(mac: macSegments(k), phone: phoneSegments(k)).filter { awayEntry(for: $0.s) == nil }
        guard let g = gs.last else { pendingGap = nil; return }
        let now = Date().timeIntervalSince1970
        pendingGap = now - g.e < 3 * Fmt.hour ? g : nil
        guard now - g.e <= 15 * 60, !awayPrompted.contains(g.s) else { return }
        awayPrompted.insert(g.s)
        notify("Welcome back. You were away \(Fmt.duration(g.e - g.s)) (\(Fmt.clock(g.s))–\(Fmt.clock(g.e))). What were you doing?")
        if settings.awayPop != false {
            NSApp.activate(ignoringOtherApps: true)
            for w in NSApp.windows where w.canBecomeMain { w.makeKeyAndOrderFront(nil) }
        }
        awayPrompt = g
    }

    func addActivity(name: String, color: String, habit: String) {
        var acts = activities
        acts.append(Activity(id: "a" + String(Int(Date().timeIntervalSince1970), radix: 36), name: name, color: color, habit: habit))
        settings.acts = acts
        saveSettings()
        toast("Added \(name)")
    }

    func removeActivity(_ id: String) {
        settings.acts = activities.filter { $0.id != id }
        saveSettings()
    }

    func linkActivity(_ id: String, habit: String) {
        guard var acts = settings.acts, let i = acts.firstIndex(where: { $0.id == id }) else { return }
        acts[i].habit = habit
        settings.acts = acts
        saveSettings()
        toast("Saved")
    }
}
