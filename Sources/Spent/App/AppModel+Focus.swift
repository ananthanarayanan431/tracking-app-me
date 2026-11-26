import Foundation

/// Focus timer, daily goals and the goal streak.
extension AppModel {
    var focusRemaining: Double {
        focus.running ? max(0, focus.endsAt - Date().timeIntervalSince1970) : focus.remaining
    }

    var focusState: String {
        focus.running ? "run" : focus.remaining < focus.planned ? "pause" : "idle"
    }

    func setFocusPreset(minutes: Int) {
        guard !focus.running else { return }
        focus.planned = Double(minutes * 60)
        focus.remaining = focus.planned
        saveFocusState()
    }

    func focusStart() {
        guard !focus.running else { return }
        let now = Date().timeIntervalSince1970
        if focus.remaining >= focus.planned {
            focus.startedAt = now
            focus.dist = 0
        }
        focus.endsAt = now + focus.remaining
        focus.running = true
        if !notificationsAllowed { Task { await enableNotifications() } }
        saveFocusState()
    }

    func focusPause() {
        guard focus.running else { return }
        focus.remaining = max(0, focus.endsAt - Date().timeIntervalSince1970)
        focus.running = false
        saveFocusState()
    }

    func focusToggle() { focus.running ? focusPause() : focusStart() }

    func focusEnd(done: Bool) {
        let now = Date().timeIntervalSince1970
        let used = focus.running ? focus.planned - (focus.endsAt - now) : focus.planned - focus.remaining
        if used >= 60 {
            let s = focus.startedAt > 0 ? focus.startedAt : now - used
            focusLog.append(FocusLog(s: s, e: s + min(used, focus.planned), planned: focus.planned,
                                     label: focus.label, done: done, dist: focus.dist))
            Storage.write("focus.json", focusLog)
        }
        if done {
            notify("Focus session done: \(Fmt.duration(focus.planned))\(focus.label.isEmpty ? "" : " on " + focus.label). Take a short break.")
        }
        focus.running = false
        focus.remaining = focus.planned
        focus.dist = 0
        saveFocusState()
    }

    /// While focusing, nudge (at most every 5 minutes) when something distracting is in front.
    func focusNudgeIfNeeded() {
        guard focus.running, let c = current, classifier.classify(app: c.app, dom: c.dom).kind == .d else { return }
        let now = Date().timeIntervalSince1970
        guard now - lastNudge > 300 else { return }
        lastNudge = now
        focus.dist += 1
        saveFocusState()
        notify("You’re in a focus session: \(c.dom.isEmpty ? c.app : c.dom) is on your distracting list.")
    }

    func enableShortcut(announce: Bool = true) {
        HotKey.shared.action = { [weak self] in
            MainActor.assumeIsolated { self?.focusToggle() }
        }
        shortcutOn = HotKey.shared.register()
        if announce { toast(shortcutOn ? "⌥⇧F now starts or pauses focus" : "Shortcut unavailable") }
    }

    func disableShortcut() {
        HotKey.shared.unregister()
        shortcutOn = false
    }

    // MARK: Goals

    /// true = met, false = missed, nil = no goals or no data (or too early to tell today).
    func goalMet(_ s: Summary, partial: Bool = false) -> Bool? {
        let g = settings.goals
        guard g.any, s.t > 0 else { return nil }
        if g.cap > 0, s.t > g.cap * Fmt.hour { return false }
        if g.dis > 0, s.distracting > g.dis * Fmt.hour { return false }
        if g.prod > 0, s.productive < g.prod * Fmt.hour { return partial ? nil : false }
        return true
    }

    func focusLogs(on key: String) -> [FocusLog] {
        focusLog.filter { Fmt.key(epoch: $0.s) == key }
    }
}
