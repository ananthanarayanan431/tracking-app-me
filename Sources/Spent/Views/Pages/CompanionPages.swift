import AadatCore
import AadatKit
import DeskBreakCore
import DeskBreakKit
import SwiftUI

/// Shown until a companion app runs inside Spent.
private struct TakeOverCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    var kind: Companions.Kind
    var blurb: String

    var body: some View {
        let c = model.companions
        let standalone = c.standaloneApp(kind) != nil
        Card(padding: 24) {
            CardHeader(title: "Run \(kind.name) inside Spent")
            Note(blurb)
            Group {
                if standalone {
                    Text("● \(kind.name) is running as its own app right now").foregroundStyle(skin.warn)
                } else if c.isInstalled(kind) {
                    Text("\(kind.name) isn’t running").foregroundStyle(skin.muted)
                } else {
                    Text("\(kind.name) isn’t installed; Spent will start with its saved data, if any").foregroundStyle(skin.muted)
                }
            }
            .font(.system(size: 13, weight: .medium))
            Note("Spent uses \(kind.name)’s own code and data, so everything you have carries over. Only one copy can run at a time, so this quits the separate \(kind.name) app first.")
            HStack {
                Button(c.switching.contains(kind) ? "Switching…" : "Run inside Spent") {
                    Task { await c.takeOver(kind) }
                }
                .spentButton(.accent)
                .disabled(c.switching.contains(kind))
            }
        }
    }
}

/// Footer line for a companion running inside Spent.
private struct HandBackRow: View {
    @Environment(AppModel.self) private var model
    var kind: Companions.Kind

    var body: some View {
        HStack {
            Note("\(kind.name) runs inside Spent. Its separate app stays closed while this is on.")
            Spacer()
            Button("Use the separate app instead") { model.companions.handBack(kind) }.spentButton(.ghost, compact: true)
        }
    }
}

// MARK: DeskBreak

struct DeskBreakPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let c = model.companions.deskbreak {
            DeskBreakDashboard(controller: c)
        } else {
            TakeOverCard(kind: .deskbreak, blurb: "Water every hour and a walk every two hours of active Mac time, with a small reminder panel you answer with I did, Not doing or Remind me later.")
        }
    }
}

private struct DeskBreakDashboard: View {
    @ObservedObject var controller: DeskBreakKit.AppController
    @Environment(\.skin) private var skin

    var body: some View {
        let today = controller.todaySummary()
        VStack(spacing: 16) {
            SpanRow(spans: [5, 7]) {
                Card {
                    CardHeader(title: "Right now")
                    DeskBreakKit.MenuContentView(controller: controller, embedded: true)
                }
                Card {
                    CardHeader(title: "Today", sub: "Done out of reminders fired")
                    HStack(spacing: 28) {
                        ring(.water, today.water)
                        ring(.walk, today.walk)
                        Spacer(minLength: 0)
                    }
                    Note("A reminder counts on the day it fired. Each one is done, skipped, or missed if nobody answers in time.")
                }
            }
            HistoryCard(records: controller.log.records)
            RecentCard(records: controller.log.records)
            HandBackRow(kind: .deskbreak)
        }
    }

    private func ring(_ kind: ReminderKind, _ c: DailySummary.Count) -> some View {
        HStack(spacing: 14) {
            ScoreRing(value: c.fired > 0 ? Int((Double(c.done) / Double(c.fired) * 100).rounded()) : nil, size: 96,
                      label: kind == .water ? "water" : "walk", color: kind == .water ? skin.blue : skin.good)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(c.done)/\(c.fired)").font(.system(size: 28, weight: .bold)).monospacedDigit()
                Text(kind == .water ? "glasses of water" : "walks").font(.system(size: 12)).foregroundStyle(skin.muted)
            }
        }
    }
}

private struct HistoryCard: View {
    @Environment(\.skin) private var skin
    var records: [ReminderRecord]
    @State private var days = 30

    var body: some View {
        let keys = Fmt.lastNKeys(days)
        Card {
            CardHeader(title: "History", sub: "Per day") {
                Seg(options: [(14, "14 days"), (30, "30 days"), (60, "60 days")], selection: $days)
            }
            ForEach(ReminderKind.allCases, id: \.self) { kind in
                let byDay = Dictionary(grouping: records.filter { $0.kind == kind }) { Fmt.key($0.firedAt) }
                let all = records.filter { $0.kind == kind && keys.contains(Fmt.key($0.firedAt)) }
                let done = all.filter { $0.status == .done }.count
                let skipped = all.filter { $0.status == .skipped }.count
                let missed = all.filter { $0.status == .missed }.count
                HStack {
                    HStack(spacing: 6) {
                        Icon(kind == .water ? .deskbreak : .walk, filled: kind == .water, size: 16)
                        Text(kind == .water ? "Water" : "Walk")
                    }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(kind == .water ? skin.blue : skin.good)
                    Spacer()
                    Text("\(done) done · \(skipped) skipped · \(missed) missed · \(all.isEmpty ? 0 : Int(Double(done) / Double(all.count) * 100))% done")
                        .font(.system(size: 12)).foregroundStyle(skin.muted)
                }
                Columns(bars: keys.enumerated().map { i, k in
                    let r = byDay[k] ?? []
                    let d = Double(r.filter { $0.status == .done }.count)
                    let s = Double(r.filter { $0.status == .skipped }.count)
                    let m = Double(r.filter { $0.status == .missed }.count)
                    return ColumnBar(id: i, total: d + s + m,
                                     parts: [(kind == .water ? skin.blue : skin.good, d), (skin.warn, s), (skin.dim.opacity(0.6), m)],
                                     tip: "\(Fmt.shortDate(k)) · \(Int(d)) done, \(Int(s)) skipped, \(Int(m)) missed")
                }, labels: keys.enumerated().map { i, k in
                    i % max(1, days / 10) == 0 ? "\(Fmt.calendar.component(.day, from: Fmt.date(k)))" : ""
                }, height: 110)
            }
            Legend(items: [("Done", skin.good), ("Skipped", skin.warn), ("Missed", skin.dim.opacity(0.6))])
        }
    }
}

private struct RecentCard: View {
    @Environment(\.skin) private var skin
    var records: [ReminderRecord]

    var body: some View {
        Card {
            CardHeader(title: "Recent reminders", sub: "\(records.count) kept (60 days)")
            ForEach(records.sorted { $0.firedAt > $1.firedAt }.prefix(15)) { r in
                HStack(spacing: 10) {
                    Icon(r.kind == .water ? .deskbreak : .walk, filled: r.kind == .water, size: 16)
                        .foregroundStyle(r.kind == .water ? skin.blue : skin.good).frame(width: 18)
                    Text(r.kind == .water ? "Water" : "Walk").frame(width: 60, alignment: .leading)
                    Text("\(Fmt.shortDate(Fmt.key(r.firedAt))) \(Fmt.clock(r.firedAt.timeIntervalSince1970))")
                        .foregroundStyle(skin.muted).monospacedDigit()
                    if r.snoozeCount > 0 { Tag(text: "snoozed \(r.snoozeCount)×") }
                    Spacer()
                    Tag(text: r.status.rawValue.capitalized,
                        kind: r.status == .done ? .p : r.status == .skipped ? .n : r.status == .missed ? .d : nil)
                }
                .font(.system(size: 13))
            }
        }
    }
}

// MARK: Aadat

struct AadatPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let c = model.companions.aadat {
            AadatDashboard(controller: c)
        } else {
            TakeOverCard(kind: .aadat, blurb: "Your to-do list for today and tomorrow: unfinished tasks carry over at midnight, tomorrow’s tasks join today, and deleted tasks are kept for 24 hours.")
        }
    }
}

private struct AadatDashboard: View {
    @ObservedObject var controller: AadatKit.BoardController
    @Environment(\.skin) private var skin

    var body: some View {
        let b = controller.board
        VStack(spacing: 16) {
            SpanRow(spans: [7, 5]) {
                Card(padding: 22) {
                    AadatKit.MenuContentView(controller: controller, embedded: true)
                }
                Card {
                    CardHeader(title: "Summary")
                    HStack(spacing: 18) {
                        ScoreRing(value: b.totalCount > 0 ? Int(Double(b.doneCount) / Double(b.totalCount) * 100) : nil,
                                  size: 104, label: "done today", color: skin.acc)
                        VStack(alignment: .leading, spacing: 6) {
                            stat("\(b.doneCount)/\(b.totalCount)", "tasks done today")
                            stat("\(b.tomorrow.count)", "waiting for tomorrow")
                            stat("\(b.deleted.count)", "recently deleted")
                        }
                    }
                    Note("At midnight done tasks clear, unfinished ones carry over and tomorrow’s join today, even if the Mac was asleep.")
                }
            }
            HandBackRow(kind: .aadat)
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(v).font(.system(size: 18, weight: .bold)).monospacedDigit()
            Text(l).font(.system(size: 12)).foregroundStyle(skin.muted)
        }
    }
}
