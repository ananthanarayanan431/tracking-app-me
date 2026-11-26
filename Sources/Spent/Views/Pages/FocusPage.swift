import SwiftUI

struct FocusPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        _ = model.revision
        let gd = DayRange.lastN(30).keys.map { (k: $0, s: model.dayData($0).pick(.all)) }
        let today = gd.last!.s
        let tk = Fmt.todayKey
        var streak = 0
        for x in gd.dropLast().reversed() { if model.goalMet(x.s) == true { streak += 1 } else { break } }
        if model.goalMet(today, partial: true) == true { streak += 1 }
        let fToday = model.focusLogs(on: tk)
        let fMin = fToday.reduce(0) { $0 + $1.e - $1.s }
        let g = model.settings.goals

        return VStack(spacing: 16) {
            SpanRow(spans: [1, 1]) {
                TimerCard()
                Card {
                    CardHeader(title: "Today", sub: "Mac + iPhone")
                    HStack(spacing: 20) {
                        ScoreRing(value: today.score, size: 124, stroke: 10)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Fmt.duration(today.t)).font(.system(size: 44, weight: .bold))
                            Text("screen time · \(Fmt.duration(fMin)) in \(fToday.count) focus session\(fToday.count == 1 ? "" : "s")")
                                .font(.system(size: 13)).foregroundStyle(skin.muted)
                        }
                    }
                    KindBar(summary: today)
                    Note("Focus score = share of time on productive apps (neutral counts half), minus a little for constant app switching. Relabel any app in Settings › Labels.")
                }
            }
            SpanRow(spans: [1, 1]) {
                GoalsCard(today: today)
                Card {
                    CardHeader(title: "Streak", sub: "Days in a row meeting every goal")
                    HStack(spacing: 14) {
                        Text(g.any ? "\(streak)" : "–").font(.system(size: 56, weight: .bold)).foregroundStyle(skin.acc)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(streak == 1 ? "day" : "days").font(.system(size: 16, weight: .semibold))
                            Text(g.any ? "Last 30 days below" : "Set a goal to start a streak").font(.system(size: 12)).foregroundStyle(skin.muted)
                        }
                    }
                    HStack(spacing: 4) {
                        ForEach(gd, id: \.k) { x in
                            let m = model.goalMet(x.s, partial: x.k == tk)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(m == true ? skin.good : m == false ? skin.bad.opacity(0.7) : skin.track)
                                .frame(width: 12, height: 12)
                                .help("\(Fmt.shortDate(x.k)): \(m == true ? "met" : m == false ? "missed" : "no goal or no data")")
                        }
                    }
                    SectionLabel(text: "Focus minutes, last 7 days")
                    let keys = Fmt.lastNKeys(7)
                    Columns(bars: keys.enumerated().map { i, k in
                        let t = model.focusLogs(on: k).reduce(0) { $0 + $1.e - $1.s }
                        return ColumnBar(id: i, total: t, parts: [(skin.good, t)], tip: "\(Fmt.shortDate(k)) · \(Fmt.duration(t))")
                    }, labels: keys.map(Fmt.weekdayName), height: 110)
                }
            }
            Card {
                CardHeader(title: "Focus sessions", sub: "\(model.focusLog.count) logged")
                if model.focusLog.isEmpty {
                    EmptyNote("No focus sessions yet. Pick a length and press Start.")
                } else {
                    HStack {
                        Text("When").frame(width: 120, alignment: .leading)
                        Text("Focus").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Planned").frame(width: 70, alignment: .trailing)
                        Text("Done").frame(width: 70, alignment: .trailing)
                        Text("Nudges").frame(width: 60, alignment: .trailing)
                    }
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(skin.dim)
                    ForEach(Array(model.focusLog.suffix(30).reversed().enumerated()), id: \.offset) { _, f in
                        HStack {
                            Text("\(Fmt.shortDate(Fmt.key(epoch: f.s))) \(Fmt.clock(f.s))").foregroundStyle(skin.muted).frame(width: 120, alignment: .leading)
                            HStack(spacing: 6) {
                                Text(f.label.isEmpty ? "Focus" : f.label).lineLimit(1)
                                f.done ? Tag(text: "Completed", kind: .p) : Tag(text: "Stopped early")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Fmt.duration(f.planned)).frame(width: 70, alignment: .trailing)
                            Text(Fmt.duration(f.e - f.s)).frame(width: 70, alignment: .trailing)
                            Text("\(f.dist)").frame(width: 60, alignment: .trailing)
                        }
                        .font(.system(size: 13)).monospacedDigit().padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

private struct TimerCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        @Bindable var model = model
        Card {
            CardHeader(title: "Focus timer") {
                if model.shortcutOn {
                    Text("⌥⇧F starts or pauses").font(.system(size: 12)).foregroundStyle(skin.muted)
                } else {
                    Button("Enable ⌥⇧F shortcut") { model.enableShortcut() }.spentButton(.ghost, compact: true)
                }
            }
            VStack(spacing: 16) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let rem = model.focusRemaining
                    let p = 1 - rem / max(1, model.focus.planned)
                    ZStack {
                        Circle().stroke(skin.track, lineWidth: 10)
                        Circle().trim(from: 0, to: max(0, min(1, p)))
                            .stroke(skin.good, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text(Fmt.mmss(rem)).font(.system(size: 44, weight: .bold)).monospacedDigit()
                            Text(model.focus.running ? (model.focus.label.isEmpty ? "Focusing" : model.focus.label)
                                 : model.focusState == "pause" ? "Paused" : "Ready")
                                .font(.system(size: 13)).foregroundStyle(skin.muted)
                        }
                    }
                    .frame(width: 210, height: 210)
                }
                TextField("What are you focusing on?", text: $model.focus.label).spentField().frame(maxWidth: 340)
                HStack(spacing: 8) {
                    ForEach([15, 25, 50, 90], id: \.self) { m in
                        Button("\(m) min") { model.setFocusPreset(minutes: m) }
                            .spentButton(model.focus.planned == Double(m * 60) ? .primary : .normal, compact: true)
                            .disabled(model.focus.running)
                    }
                }
                HStack(spacing: 8) {
                    switch model.focusState {
                    case "run":
                        Button("Pause") { model.focusPause() }.spentButton(.primary)
                        Button("Stop") { model.focusEnd(done: false) }.spentButton()
                    case "pause":
                        Button("Resume") { model.focusStart() }.spentButton(.primary)
                        Button("Stop") { model.focusEnd(done: false) }.spentButton()
                    default:
                        Button("Start focus") { model.focusStart() }.spentButton(.accent)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            Note("During a session Spent nudges you if you open something labelled distracting.")
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }
}

private struct GoalsCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    var today: Summary
    @State private var cap = ""
    @State private var dis = ""
    @State private var prod = ""

    var body: some View {
        let g = model.settings.goals
        Card {
            CardHeader(title: "Daily goals", sub: "Leave at 0 to switch off")
            if g.cap > 0 { bar("Screen time cap", today.t, g.cap * 3600, good: false) }
            if g.dis > 0 { bar("Distracting time cap", today.distracting, g.dis * 3600, good: false) }
            if g.prod > 0 { bar("Productive target", today.productive, g.prod * 3600, good: true) }
            HStack(alignment: .bottom, spacing: 10) {
                Labeled(label: "Screen-time cap (h)") { TextField("0", text: $cap).spentField() }
                Labeled(label: "Distracting cap (h)") { TextField("0", text: $dis).spentField() }
                Labeled(label: "Productive target (h)") { TextField("0", text: $prod).spentField() }
                Button("Save goals") {
                    let v = { (s: String) in max(0, Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0) }
                    model.settings.goals = Goals(cap: v(cap), dis: v(dis), prod: v(prod))
                    model.saveSettings()
                    model.toast("Goals saved")
                }
                .spentButton(.primary)
            }
        }
        .onAppear {
            cap = MenuBarContent.num(g.cap)
            dis = MenuBarContent.num(g.dis)
            prod = MenuBarContent.num(g.prod)
        }
    }

    private func bar(_ label: String, _ used: Double, _ lim: Double, good: Bool) -> some View {
        let p = lim > 0 ? min(1, used / lim) : 0
        let col: Color = good ? (p >= 1 ? skin.good : skin.blue) : (p >= 1 ? skin.bad : p >= 0.8 ? skin.warn : skin.good)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 13))
                Spacer()
                Text(Fmt.duration(used)).font(.system(size: 13, weight: .semibold))
                Text("/ \(Fmt.duration(lim))").font(.system(size: 12)).foregroundStyle(skin.muted)
            }
            Meter(fraction: p, color: col, height: 8)
        }
    }
}
