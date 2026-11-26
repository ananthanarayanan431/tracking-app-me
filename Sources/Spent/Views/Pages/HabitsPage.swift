import SwiftUI

struct HabitsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        let HB = model.habits
        let t = Fmt.todayKey
        let sched = HB.filter { $0.scheduled(t) }
        let doneT = sched.filter { model.isDone($0, t) }.count
        VStack(spacing: 16) {
            Card {
                CardHeader(title: "Today", sub: HB.isEmpty ? "" : "\(doneT) of \(sched.count) done")
                if HB.isEmpty {
                    Note("Track anything that matters to you beside screen time: tick it off and log when you did it. Start with one of these, or make your own below.")
                    FlowRow(spacing: 8) {
                        ForEach(AppModel.quickHabits, id: \.name) { q in
                            Button("+ \(q.name)") { quickAdd(q) }.spentButton(compact: true)
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                        ForEach(HB) { HabitCard(habit: $0) }
                    }
                }
            }
            if !HB.isEmpty {
                Card {
                    CardHeader(title: "Last 30 days", sub: "Tap any day to tick it, add the time, amount or a note")
                    HabitGrid()
                }
                SpanRow(spans: [1, 1]) {
                    Card {
                        CardHeader(title: "Streaks", sub: "Rest days don’t break a streak")
                        ForEach(HB) { h in StreakRow(habit: h) }
                    }
                    HabitsVsScreenTime()
                }
            }
            SpanRow(spans: [8, 4]) {
                HabitForm()
                Card {
                    CardHeader(title: "Your habits")
                    if HB.isEmpty { EmptyNote("None yet.") }
                    ForEach(HB) { h in
                        HStack(spacing: 10) {
                            Circle().fill(Color(hex: h.color)).frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(h.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                Text("\(h.kind == .number ? "\(h.target > 0 ? MenuBarContent.num(h.target) : "Any") \(h.unit) · " : "")\(h.daysText)\(h.remind.isEmpty ? "" : " · reminder \(h.remind)")")
                                    .font(.system(size: 12)).foregroundStyle(skin.muted).lineLimit(1)
                            }
                            Spacer()
                            Button("Edit") { model.editingHabit = h.id }.spentButton(.ghost, compact: true)
                            ConfirmDeleteButton { model.deleteHabit(h.id) }
                        }
                        .padding(.vertical, 4)
                    }
                    let quick = AppModel.quickHabits.filter { q in !HB.contains { $0.name == q.name } }.prefix(4)
                    if !HB.isEmpty, !quick.isEmpty {
                        SectionLabel(text: "Quick add")
                        FlowRow(spacing: 6) {
                            ForEach(Array(quick), id: \.name) { q in
                                Button("+ \(q.name)") { quickAdd(q) }.spentButton(compact: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private func quickAdd(_ q: (name: String, kind: HabitKind, unit: String, target: Double)) {
        model.addHabit(name: q.name, kind: q.kind, unit: q.unit, target: q.target)
        model.toast("Added \(q.name)")
    }
}

/// "Delete" that turns into "Confirm delete" on the first click.
struct ConfirmDeleteButton: View {
    @Environment(\.skin) private var skin
    var action: () -> Void
    @State private var armed = false

    var body: some View {
        Button(armed ? "Confirm delete" : "Delete") {
            if armed { action() } else { armed = true }
        }
        .spentButton(armed ? .danger : .ghost, compact: true)
    }
}

private struct HabitGrid: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        let ks = Fmt.lastNKeys(30)
        let t = Fmt.todayKey
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Text("").frame(width: 150)
                ForEach(Array(ks.enumerated()), id: \.offset) { i, k in
                    Text(i % 5 == 0 || i == ks.count - 1 ? "\(Fmt.calendar.component(.day, from: Fmt.date(k)))" : "")
                        .font(.system(size: 10)).foregroundStyle(skin.dim).frame(maxWidth: .infinity)
                }
            }
            ForEach(model.habits) { h in
                let c = Color(hex: h.color)
                HStack(spacing: 3) {
                    HStack(spacing: 6) {
                        Circle().fill(c).frame(width: 8, height: 8)
                        Text(h.name).font(.system(size: 12)).lineLimit(1)
                    }
                    .frame(width: 150, alignment: .leading)
                    ForEach(ks, id: \.self) { k in
                        let e = model.entry(h.id, k)
                        let d = model.isDone(h, e)
                        let s = h.scheduled(k)
                        Button { model.habitEntryTarget = HabitEntryTarget(habitID: h.id, key: k) } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(d ? c : skin.panel2)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(k == t ? skin.ink.opacity(0.5) : skin.line, lineWidth: 1))
                                .opacity(!s && !d ? 0.35 : 1)
                                .frame(maxWidth: .infinity).frame(height: 20)
                        }
                        .buttonStyle(.plain)
                        .help(tip(h, k, e, d, s))
                    }
                }
            }
        }
    }

    private func tip(_ h: Habit, _ k: String, _ e: HabitEntry?, _ d: Bool, _ s: Bool) -> String {
        var t = "\(Fmt.shortDate(k)): \(d ? "done" : s ? "not done" : "rest day")"
        if let at = e?.at, !at.isEmpty { t += " at \(at)" }
        if h.kind == .number, let v = e?.v, v > 0 { t += " · \(MenuBarContent.num(v)) \(h.unit)" }
        if let n = e?.note, !n.isEmpty { t += " · \(n)" }
        return t
    }
}

private struct StreakRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    var habit: Habit

    var body: some View {
        let s = model.habitStats(habit)
        HStack(spacing: 10) {
            Circle().fill(Color(hex: habit.color)).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text("\(s.doneN) of \(s.schedN) days · \(s.avgAt.map { "usually around " + Fmt.timeOfDay($0 * 60) } ?? "no times logged")\(habit.kind == .number ? " · \(MenuBarContent.num((s.total * 10).rounded() / 10)) \(habit.unit) in 30 days" : "")")
                    .font(.system(size: 12)).foregroundStyle(skin.muted).lineLimit(2)
            }
            Spacer()
            ForEach([("\(s.cur)", "streak"), ("\(s.best)", "best"), ("\(s.rate)%", "30 days")], id: \.1) { v, l in
                VStack(spacing: 0) {
                    Text(v).font(.system(size: 16, weight: .bold))
                    Text(l).font(.system(size: 10)).foregroundStyle(skin.muted)
                }
                .frame(width: 52)
            }
        }
        .padding(.vertical, 5)
    }
}

/// Average day with the habit vs scheduled days without it.
private struct HabitsVsScreenTime: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        let _ = model.revision
        let t = Fmt.todayKey
        let sd = Fmt.lastNKeys(60).filter { $0 != t }.map { (k: $0, s: model.dayData($0).pick(.all)) }.filter { $0.s.t > 0 }
        Card {
            CardHeader(title: "Habits vs screen time", sub: "Last 60 days, Mac + iPhone")
            Note("Average day when you did the habit, compared with scheduled days you didn’t. Green means better.")
            HStack {
                Text("Habit").frame(maxWidth: .infinity, alignment: .leading)
                Text("Screen time").frame(width: 90, alignment: .trailing)
                Text("Distracting").frame(width: 90, alignment: .trailing)
                Text("Score").frame(width: 60, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(skin.dim)
            ForEach(model.habits) { h in
                let a = sd.filter { model.isDone(h, $0.k) }
                let b = sd.filter { h.scheduled($0.k) && !model.isDone(h, $0.k) }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: h.color)).frame(width: 8, height: 8)
                            Text(h.name).fontWeight(.semibold).lineLimit(1)
                        }
                        Text("\(a.count) days with · \(b.count) without").font(.system(size: 11)).foregroundStyle(skin.dim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if a.count < 2 || b.count < 2 {
                        Text("Needs a few more days with and without it.").font(.system(size: 12)).foregroundStyle(skin.muted)
                    } else {
                        cmp(avg(a) { $0.t }, avg(b) { $0.t }, lowerBetter: true, fmt: Fmt.duration).frame(width: 90, alignment: .trailing)
                        cmp(avg(a) { $0.distracting }, avg(b) { $0.distracting }, lowerBetter: true, fmt: Fmt.duration).frame(width: 90, alignment: .trailing)
                        let sa = scoreAvg(a), sb = scoreAvg(b)
                        cmp(sa ?? 0, sb ?? 0, lowerBetter: false, fmt: { "\(Int($0))" }).frame(width: 60, alignment: .trailing)
                    }
                }
                .font(.system(size: 13))
                .padding(.vertical, 4)
            }
        }
    }

    private func avg(_ arr: [(k: String, s: Summary)], _ f: (Summary) -> Double) -> Double {
        arr.reduce(0) { $0 + f($1.s) } / Double(max(arr.count, 1))
    }

    private func scoreAvg(_ arr: [(k: String, s: Summary)]) -> Double? {
        let v = arr.compactMap { $0.s.score }
        return v.isEmpty ? nil : Double(v.reduce(0, +)) / Double(v.count)
    }

    private func cmp(_ a: Double, _ b: Double, lowerBetter: Bool, fmt: @escaping (Double) -> String) -> some View {
        let diff = a - b
        let better = lowerBetter ? diff < 0 : diff > 0
        return VStack(alignment: .trailing, spacing: 1) {
            HStack(spacing: 3) {
                Text(fmt(a))
                if abs(diff) > 0.5 { Text(diff > 0 ? "▲" : "▼").foregroundStyle(better ? skin.good : skin.bad) }
            }
            Text("vs \(fmt(b))").font(.system(size: 11)).foregroundStyle(skin.dim)
        }
    }
}

private struct HabitForm: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    @State private var name = ""
    @State private var kind: HabitKind = .check
    @State private var unit = ""
    @State private var target = ""
    @State private var remind = ""
    @State private var days: Set<Int> = Set(0...6)
    @State private var color = AppModel.habitColors[0]
    @State private var loadedFor: String? = "–"

    var body: some View {
        let editing = model.editingHabit.flatMap { model.habit($0) }
        Card {
            CardHeader(title: editing == nil ? "New habit" : "Edit habit")
            HStack(alignment: .bottom, spacing: 10) {
                Labeled(label: "Name") { TextField("Went for a run", text: $name).spentField() }
                Labeled(label: "Type") {
                    Picker("", selection: $kind) {
                        Text("Tick box (yes / no)").tag(HabitKind.check)
                        Text("Amount (km, pages, glasses…)").tag(HabitKind.number)
                    }
                    .labelsHidden()
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                Labeled(label: "Unit (for amounts)") { TextField("km", text: $unit).spentField() }
                Labeled(label: "Daily target (for amounts)") { TextField("5", text: $target).spentField() }
                Labeled(label: "Reminder if not done by (HH:MM)") { TextField("07:30", text: $remind).spentField() }
            }
            HStack(alignment: .bottom, spacing: 24) {
                Labeled(label: "Which days") {
                    HStack(spacing: 4) {
                        ForEach([1, 2, 3, 4, 5, 6, 0], id: \.self) { d in
                            let on = days.contains(d)
                            Button(String(Fmt.weekdays[d].prefix(2))) {
                                if on { days.remove(d) } else { days.insert(d) }
                            }
                            .spentButton(on ? .primary : .normal, compact: true)
                        }
                    }
                }
                Labeled(label: "Colour") { SwatchPicker(colors: AppModel.habitColors, selection: $color) }
            }
            HStack {
                Button(editing == nil ? "Add habit" : "Save changes") { save(editing) }
                    .spentButton(.primary)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                if editing != nil {
                    Button("Cancel") { model.editingHabit = nil }.spentButton()
                }
            }
        }
        .onAppear { load(editing) }
        .onChange(of: model.editingHabit) { load(model.editingHabit.flatMap { model.habit($0) }) }
    }

    private func load(_ h: Habit?) {
        guard loadedFor != h?.id else { return }
        loadedFor = h?.id
        name = h?.name ?? ""
        kind = h?.kind ?? .check
        unit = h?.unit ?? ""
        target = h.map { $0.target > 0 ? MenuBarContent.num($0.target) : "" } ?? ""
        remind = h?.remind ?? ""
        days = Set(h?.days.isEmpty == false ? h!.days : Array(0...6))
        color = h?.color ?? AppModel.habitColors[model.habits.count % AppModel.habitColors.count]
    }

    private func save(_ editing: Habit?) {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        let r = Fmt.hmToMinutes(remind) != nil ? remind.trimmingCharacters(in: .whitespaces) : ""
        let tg = Double(target.replacingOccurrences(of: ",", with: ".")) ?? 0
        let ds = days.isEmpty ? Array(0...6) : days.sorted()
        if var h = editing {
            h.name = n; h.kind = kind; h.unit = unit; h.target = tg; h.remind = r; h.days = ds; h.color = color
            model.updateHabit(h)
            model.editingHabit = nil
            model.toast("Habit updated")
        } else {
            model.addHabit(name: n, kind: kind, unit: unit, target: tg, days: ds, remind: r, color: color)
            model.toast("Added \(n)")
        }
        loadedFor = "–"
        load(nil)
    }
}
