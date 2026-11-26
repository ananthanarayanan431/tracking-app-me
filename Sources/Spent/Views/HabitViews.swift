import SwiftUI

/// The round tick button used for habits and campaign dots.
struct CheckButton: View {
    @Environment(\.skin) private var skin
    var color: Color
    var done: Bool
    var label: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(done ? color : skin.panel2)
                Circle().stroke(done ? color : skin.line2, lineWidth: 1.5)
                if let label, !done {
                    Text(label).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
                } else {
                    Icon(.check, size: 18)
                        .foregroundStyle(done ? Color.black.opacity(0.75) : skin.dim)
                }
            }
            .frame(width: 42, height: 42)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct HabitCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    var habit: Habit
    var compact = false

    var body: some View {
        let h = habit
        let k = Fmt.todayKey
        let e = model.entry(h.id, k)
        let d = model.isDone(h, e)
        let st = model.habitStats(h)
        let num = h.kind == .number
        let v = e?.v ?? 0
        let c = Color(hex: h.color)
        var sub = d ? (e?.at?.isEmpty == false ? "Done at \(e!.at!)" : "Done")
            : (h.scheduled(k) ? (num && v > 0 ? "\(MenuBarContent.num(v)) of \(h.target > 0 ? MenuBarContent.num(h.target) : "–") \(h.unit)" : "Not yet today") : "Rest day")
        if num, d { sub += " · \(MenuBarContent.num(v)) \(h.unit)" }
        if st.cur > 1 { sub += " · \(st.cur)-day streak" }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                CheckButton(color: c, done: d, label: num ? (v > 0 ? MenuBarContent.num(v) : "+") : nil) { model.toggleHabit(h.id, k) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(h.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(sub).font(.system(size: 12)).foregroundStyle(skin.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            if num, h.target > 0 { Meter(fraction: v / h.target, color: c, height: 5) }
            if !compact {
                HStack(spacing: 4) {
                    ForEach(Fmt.lastNKeys(7), id: \.self) { x in
                        let dd = model.isDone(h, x)
                        let ed = Fmt.isEditable(x)
                        Button { model.toggleHabit(h.id, x) } label: {
                            Text(String(Fmt.weekdayName(x).prefix(1)))
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 24, height: 24)
                                .foregroundStyle(dd ? Color.black.opacity(0.75) : skin.muted)
                                .background(dd ? c : skin.panel2, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(x == k ? skin.ink.opacity(0.5) : .clear, lineWidth: 1))
                                .opacity(!h.scheduled(x) && !dd ? 0.4 : 1)
                                .opacity(ed ? 1 : 0.55)
                        }
                        .buttonStyle(.plain)
                        .disabled(!ed)
                        .help("\(Fmt.shortDate(x))\(dd ? " · done" : "")\(ed ? "" : " · locked")")
                    }
                    Spacer()
                    Button(num ? "Log amount" : "Details") {
                        model.habitEntryTarget = HabitEntryTarget(habitID: h.id, key: k)
                    }
                    .spentButton(.ghost, compact: true)
                }
            }
        }
        .padding(14)
        .background(d ? c.opacity(0.08) : skin.panel2, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(d ? c.opacity(0.4) : skin.line, lineWidth: 1))
    }
}

/// On Overview (today only): scheduled habits and active campaigns.
struct TodayHabitsAndCampaigns: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        let k = Fmt.todayKey
        let hs = model.habits.filter { $0.scheduled(k) }
        let cs = model.campaigns.filter { model.campaignStats($0).state == .active }
        if !hs.isEmpty {
            Card {
                CardHeader(title: "Habits today") {
                    Button("All habits ›") { model.tab = .habits }.spentButton(.ghost, compact: true)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    ForEach(hs) { HabitCard(habit: $0, compact: true) }
                }
            }
        }
        if !cs.isEmpty {
            Card {
                CardHeader(title: "Campaigns") {
                    Button("All campaigns ›") { model.tab = .campaigns }.spentButton(.ghost, compact: true)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    ForEach(cs) { c in
                        let st = model.campaignStats(c)
                        let col = Color(hex: c.color)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                CheckButton(color: col, done: st.todayDone, label: nil) { model.toggleCampaign(c.id, k) }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                                    Text("Day \(st.dayN) of \(c.days) · \(st.rate)% consistent\(st.cur > 1 ? " · \(st.cur)-day streak" : "")")
                                        .font(.system(size: 12)).foregroundStyle(skin.muted)
                                }
                            }
                            Meter(fraction: Double(st.dayN) / Double(max(1, c.days)), color: col, height: 5)
                        }
                        .padding(14)
                        .background(skin.panel2, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }
}

/// Tick a day, log an amount, the time and a note.
struct HabitEntrySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    @Environment(\.dismiss) private var dismiss
    var target: HabitEntryTarget
    @State private var value = ""
    @State private var done = true
    @State private var at = ""
    @State private var note = ""

    var body: some View {
        if let h = model.habit(target.habitID) {
            let k = target.key
            let existing = model.entry(h.id, k)
            let editable = Fmt.isEditable(k)
            let c = Color(hex: h.color)
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Circle().fill(c).frame(width: 14, height: 14)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(h.name).font(.system(size: 20, weight: .bold))
                        Text("\(Fmt.weekdayName(k)) \(Fmt.shortDate(k))\(k == Fmt.todayKey ? " · today" : "")").font(.system(size: 12)).foregroundStyle(skin.muted)
                    }
                }
                if !editable {
                    Note("This day is locked. You can only log or change today and the last \(Fmt.editableDaysBack) days.")
                }
                Group {
                if h.kind == .number {
                    Labeled(label: "How much?\(h.target > 0 ? " (target \(MenuBarContent.num(h.target)) \(h.unit))" : "")") {
                        TextField("0", text: $value).spentField().font(.system(size: 20))
                    }
                } else {
                    Toggle("I did it", isOn: $done).toggleStyle(.checkbox)
                }
                Labeled(label: "When did you do it? (HH:MM)") { TextField("07:30", text: $at).spentField() }
                Labeled(label: "Note (optional)") {
                    TextField(h.kind == .number ? "e.g. easy pace, felt great" : "e.g. 30 min, park loop", text: $note).spentField()
                }
                }
                .disabled(!editable)
                HStack {
                    if editable {
                        Button("Save") { save(h, k) }.spentButton(.primary).keyboardShortcut(.defaultAction)
                    }
                    if editable, existing != nil {
                        Button("Clear this day") { model.setEntry(h.id, k, nil); dismiss() }.spentButton(.ghost)
                    }
                    Spacer()
                    Button(editable ? "Cancel" : "Close") { dismiss() }.spentButton(.ghost).keyboardShortcut(.cancelAction)
                }
                SectionLabel(text: "Last 30 days")
                HStack(spacing: 4) {
                    ForEach(Fmt.lastNKeys(30), id: \.self) { x in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(model.isDone(h, x) ? c : skin.track)
                            .frame(width: 12, height: 12)
                            .opacity(h.scheduled(x) || model.isDone(h, x) ? 1 : 0.3)
                            .help(Fmt.shortDate(x))
                    }
                }
            }
            .padding(26)
            .frame(width: 520)
            .background(skin.panel)
            .onAppear {
                value = existing?.v.map { MenuBarContent.num($0) } ?? ""
                done = existing == nil ? true : model.isDone(h, existing)
                at = existing?.at ?? (k == Fmt.todayKey && existing == nil ? Fmt.nowHM() : "")
                note = existing?.note ?? ""
            }
        }
    }

    private func save(_ h: Habit, _ k: String) {
        let t = at.trimmingCharacters(in: .whitespaces)
        let n = note.trimmingCharacters(in: .whitespaces)
        var e: HabitEntry?
        if h.kind == .number {
            let v = Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0
            e = v > 0 || !n.isEmpty || !t.isEmpty ? HabitEntry(v: v, at: t, note: n) : nil
        } else {
            e = done || !n.isEmpty ? HabitEntry(done: done, at: done ? t : "", note: n) : nil
        }
        model.setEntry(h.id, k, e)
        model.toast("\(h.name) saved for \(Fmt.shortDate(k))")
        dismiss()
    }
}
