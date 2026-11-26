import SwiftUI

/// Menu bar title: today's total, or the focus countdown while focusing.
struct MenuBarLabel: View {
    var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // No TimelineView here: inside a MenuBarExtra label it makes SwiftUI re-render in a
        // tight loop. The label refreshes whenever the model changes (every few seconds).
        HStack(spacing: 4) {
            Image(systemName: model.focus.running ? "scope" : "clock")
            Text(title)
        }
        .onAppear {
            // Lets the Dock icon and menu reopen the window after it was closed.
            MainWindow.open = { openWindow(id: "main") }
        }
    }

    private var title: String {
        if model.focus.running { return "Focus \(Int(ceil(model.focusRemaining / 60)))m" }
        _ = model.revision
        _ = model.current
        return Fmt.duration(model.todayAll().t)
    }
}

@MainActor
enum MainWindow {
    static var open: (() -> Void)?

    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" && $0.isVisible }) {
            w.makeKeyAndOrderFront(nil)
        } else {
            open?()
        }
    }
}

struct MenuBarContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let k = Fmt.todayKey
        let S = model.todayAll()
        Text("Today: \(Fmt.duration(S.t)) · score \(S.score.map(String.init) ?? "–")")
        Divider()
        Button(model.focus.running ? "Pause focus" : "Start focus") { model.focusToggle() }

        if let g = model.pendingGap {
            Menu("Away \(Fmt.duration(g.e - g.s)) (\(Fmt.clock(g.s))–\(Fmt.clock(g.e))): what were you doing?") {
                ForEach(model.activities) { a in
                    Button(a.name) { model.logAway(g, activityID: a.id) }
                }
                Divider()
                Button("I was just idle") { model.logAway(g, activityID: "skip") }
            }
            Divider()
        }

        let active = model.campaigns.filter { model.campaignStats($0).state == .active }
        ForEach(active) { c in
            let st = model.campaignStats(c)
            Toggle("Campaign: \(c.name) (day \(st.dayN)/\(c.days))", isOn: Binding(
                get: { st.todayDone }, set: { _ in model.toggleCampaign(c.id, k) }))
        }

        let todays = model.habits.filter { $0.scheduled(k) }
        ForEach(todays) { h in
            if h.kind == .number {
                Button("\(h.name): \(Self.num(model.entry(h.id, k)?.v ?? 0))/\(h.target > 0 ? Self.num(h.target) : "–") \(h.unit)") {
                    MainWindow.show()
                    model.tab = .habits
                    model.habitEntryTarget = HabitEntryTarget(habitID: h.id, key: k)
                }
            } else {
                Toggle(h.name, isOn: Binding(get: { model.isDone(h, k) }, set: { _ in model.toggleHabit(h.id, k) }))
            }
        }
        if !active.isEmpty || !todays.isEmpty { Divider() }

        Button("Open Spent") { MainWindow.show() }
        Button(model.paused ? "Resume tracking" : "Pause tracking") { model.togglePause() }
        Divider()
        Button("Quit Spent") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }

    static func num(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}
