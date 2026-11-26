import SwiftUI

/// Overview card listing today's gaps, logged or waiting to be filled in.
struct AwaySection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    var key: String
    var gaps: [Gap]

    var body: some View {
        let done = gaps.compactMap { model.awayEntry(for: $0.s) }.filter { $0.skip != true }
        let todo = gaps.filter { model.awayEntry(for: $0.s) == nil }
        var by: [String: Double] = [:]
        for x in done { by[x.name, default: 0] += x.e - x.s }
        let tot = by.values.reduce(0, +)
        let colorOf = { (n: String) in Color(hex: done.first { $0.name == n }?.color ?? "#8b9bb4") }
        return Card {
            CardHeader(title: "Away from the screen", sub: "\(Fmt.duration(tot)) logged\(todo.isEmpty ? "" : " · \(todo.count) to fill in")")
            if !by.isEmpty {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(by.sortedDesc, id: \.key) { n, v in
                            Rectangle().fill(colorOf(n)).frame(width: max(2, geo.size.width * v / tot - 2)).help("\(n) \(Fmt.duration(v))")
                        }
                    }
                }
                .frame(height: 8).clipShape(Capsule())
                Legend(items: by.sortedDesc.map { ("\($0.key) \(Fmt.duration($0.value))", colorOf($0.key)) })
            }
            VStack(spacing: 0) {
                ForEach(gaps.reversed()) { g in
                    let x = model.awayEntry(for: g.s)
                    HStack(spacing: 10) {
                        Text("\(Fmt.clock(g.s))–\(Fmt.clock(g.e))").monospacedDigit().foregroundStyle(skin.muted).frame(width: 100, alignment: .leading)
                        if let x {
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: x.color)).frame(width: 8, height: 8)
                                Text(x.name).fontWeight(.semibold)
                            }
                        } else {
                            Text("What were you doing?").foregroundStyle(skin.warn)
                        }
                        Text("· \(Fmt.duration(g.e - g.s))").foregroundStyle(skin.muted)
                        Spacer()
                        if x == nil {
                            ForEach(model.activities.prefix(4)) { a in
                                ActivityChip(activity: a, compact: true) { model.logAway(g, activityID: a.id) }
                            }
                        }
                        Button(x == nil ? "More…" : "Change") { model.awayPrompt = g }.spentButton(.ghost, compact: true)
                    }
                    .font(.system(size: 13))
                    .padding(.vertical, 7)
                    Divider().overlay(skin.line)
                }
            }
        }
    }
}

struct ActivityChip: View {
    @Environment(\.skin) private var skin
    var activity: Activity
    var subtitle = ""
    var selected = false
    var compact = false
    var action: () -> Void

    var body: some View {
        let c = Color(hex: activity.color)
        Button(action: action) {
            HStack(spacing: 7) {
                Circle().fill(c).frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 0) {
                    Text(activity.name).font(.system(size: compact ? 12 : 14, weight: .medium))
                    if !subtitle.isEmpty { Text(subtitle).font(.system(size: 10)).foregroundStyle(skin.muted) }
                }
            }
            .padding(.horizontal, compact ? 9 : 12)
            .frame(minHeight: compact ? 26 : 40)
            .background(selected ? c.opacity(0.22) : skin.panel2, in: Capsule())
            .overlay(Capsule().stroke(selected ? c : skin.line2, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// "Welcome back — you were away 42m. What were you doing?"
struct AwaySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    @Environment(\.dismiss) private var dismiss
    var gap: Gap
    @State private var other = ""

    var body: some View {
        let cur = model.awayEntry(for: gap.s)
        VStack(alignment: .leading, spacing: 14) {
            Text(cur == nil ? "Welcome back" : "Change what you were doing").font(.system(size: 13)).foregroundStyle(skin.muted)
            Text("You were away \(Fmt.duration(gap.e - gap.s))").font(.system(size: 26, weight: .bold))
            Text("\(Fmt.clock(gap.s)) – \(Fmt.clock(gap.e)) · \(Fmt.weekdayName(Fmt.key(epoch: gap.s))) \(Fmt.shortDate(Fmt.key(epoch: gap.s)))\(gap.ph > 60 ? " · \(Fmt.duration(gap.ph)) on iPhone" : "")")
                .font(.system(size: 13)).foregroundStyle(skin.muted)
            SectionLabel(text: "What were you doing?")
            FlowRow(spacing: 8) {
                ForEach(model.activities) { a in
                    ActivityChip(activity: a, subtitle: model.habit(a.habit).map { "ticks \($0.name)" } ?? "",
                                 selected: cur?.act == a.id) { model.logAway(gap, activityID: a.id) }
                }
            }
            HStack {
                TextField("Something else…", text: $other).spentField()
                    .onSubmit(logOther)
                Button("Log it", action: logOther).spentButton()
            }
            HStack {
                Button("I was just idle") { model.logAway(gap, activityID: "skip") }.spentButton(.ghost)
                Spacer()
                Button(cur == nil ? "Ask me later" : "Close") { dismiss() }.spentButton(.ghost)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(28)
        .frame(width: 560)
        .background(skin.panel)
        .onAppear { if let c = cur, c.act.isEmpty, c.skip != true { other = c.name } }
    }

    private func logOther() {
        let v = other.trimmingCharacters(in: .whitespaces)
        if !v.isEmpty { model.logAway(gap, activityID: "", custom: v) }
    }
}
