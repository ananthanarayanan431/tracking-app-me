import Charts
import SwiftUI

struct InsightsData {
    var win: Int
    var days: [(k: String, s: Summary)]
    var S: Summary
    var Sp: Summary
    var prevCount: Int
    var wdAvg: [(String, Double)]
    var weekHour: [[Double]]
    var late: Double
    var changes: [(app: String, now: Double, before: Double, diff: Double)]
    var chips: [(String, String, String)]

    @MainActor
    init(model m: AppModel) {
        _ = m.revision
        win = m.insightsWindow
        let cur = m.periodData(DayRange.lastN(win))
        let prev = m.periodData(DayRange.lastN(win, offset: win))
        days = cur.map { ($0.k, $0.pick(m.dev)) }
        S = Summarizer.merge(days.map(\.s))
        Sp = Summarizer.merge(prev.map { $0.pick(m.dev) })
        prevCount = max(prev.count, 1)
        let n = Double(max(days.count, 1))

        var wdT = Array(repeating: 0.0, count: 7), wdN = Array(repeating: 0.0, count: 7)
        var wh = Array(repeating: Array(repeating: 0.0, count: 24), count: 7)
        for x in days {
            let w = Fmt.weekday(x.k)
            wdN[w] += 1
            wdT[w] += x.s.t
            for (i, v) in x.s.h.enumerated() { wh[w][i] += v }
        }
        let order = [1, 2, 3, 4, 5, 6, 0]
        wdAvg = order.map { (Fmt.weekdays[$0], wdN[$0] > 0 ? wdT[$0] / wdN[$0] : 0) }
        weekHour = (0..<7).map { w in wh[w].map { wdN[w] > 0 ? $0 / wdN[w] : 0 } }
        late = days.reduce(0) { $0 + $1.s.h[23] + $1.s.h[0] + $1.s.h[1] + $1.s.h[2] } / n

        let prevN = Double(prevCount)
        let names = Set(S.a.keys).union(Sp.a.keys)
        let S0 = S, Sp0 = Sp
        changes = names.map { a in
            let nw = (S0.a[a] ?? 0) / n, bf = (Sp0.a[a] ?? 0) / prevN
            return (a, nw, bf, nw - bf)
        }
        .filter { abs($0.diff) >= 60 }
        .sorted { abs($0.diff) > abs($1.diff) }
        .prefix(10).map { $0 }

        let active = days.filter { $0.s.t > 0 }
        let scores = active.compactMap { $0.s.score }
        let starts = active.filter { $0.s.f > 0 }.map { secOfDay($0.s.f) }
        let ends = active.filter { $0.s.l > 0 }.map { e -> Double in let v = secOfDay(e.s.l); return v < 4 * Fmt.hour ? v + Fmt.day : v }
        let avg = { (a: [Double]) in a.isEmpty ? 0 : a.reduce(0, +) / Double(a.count) }
        let pk = S.h.firstIndex(of: S.h.max() ?? 0) ?? 0
        let dChange = S.t / n - Sp.t / prevN
        let best = wdAvg.max { $0.1 < $1.1 }
        chips = [
            (Fmt.duration(S.t / n), "Average per day", Sp.t > 0 && dChange != 0 ? "\(dChange > 0 ? "▲" : "▼") \(Fmt.duration(abs(dChange))) vs previous \(win) days" : ""),
            (scores.isEmpty ? "–" : "\(Int(avg(scores.map(Double.init)).rounded()))", "Average focus score", ""),
            (best.map { $0.1 > 0 ? "\($0.0) · \(Fmt.duration($0.1))" : "–" } ?? "–", "Heaviest weekday", ""),
            (S.t > 0 ? "\(Fmt.pad(pk)):00–\(Fmt.pad((pk + 1) % 24)):00" : "–", "Peak hour", ""),
            (starts.isEmpty ? "–" : Fmt.timeOfDay(avg(starts)), "Typical first use", ""),
            (ends.isEmpty ? "–" : Fmt.timeOfDay(avg(ends)), "Typical last use", ""),
            (Fmt.duration(late), "Late night (23:00–03:00) per day", ""),
            (Fmt.duration(S.distracting / n), "Distracting per day", ""),
        ]

        func secOfDay(_ t: Double) -> Double {
            let c = Fmt.calendar.dateComponents([.hour, .minute], from: Date(timeIntervalSince1970: t))
            return Double(c.hour! * 3600 + c.minute! * 60)
        }
    }
}

struct InsightsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        let d = InsightsData(model: model)
        let n = Double(max(d.days.count, 1))
        VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                ForEach(d.chips.indices, id: \.self) { i in
                    let c = d.chips[i]
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.0).font(.system(size: 22, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
                        Text(c.1).font(.system(size: 12)).foregroundStyle(skin.muted)
                        if !c.2.isEmpty {
                            Text(c.2).font(.system(size: 11, weight: .medium)).foregroundStyle(c.2.hasPrefix("▲") ? skin.bad : skin.good)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                    .background(skin.panel, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(skin.line, lineWidth: 1))
                }
            }
            TrendCard(days: d.days)
            SpanRow(spans: [8, 4]) {
                Card {
                    CardHeader(title: "When you use screens", sub: "Average by weekday and hour")
                    WeekHourHeatmap(grid: d.weekHour)
                }
                Card {
                    CardHeader(title: "By weekday", sub: "Average per day")
                    let mx = max(d.wdAvg.map(\.1).max() ?? 1, 1)
                    ForEach(d.wdAvg, id: \.0) { w, v in
                        HStack(spacing: 10) {
                            Text(w).font(.system(size: 12)).foregroundStyle(skin.muted).frame(width: 32, alignment: .leading)
                            Meter(fraction: v / mx, color: skin.acc, height: 10)
                            Text(Fmt.duration(v)).font(.system(size: 12)).monospacedDigit().frame(width: 60, alignment: .trailing)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            SpanRow(spans: [7, 5]) {
                Card {
                    CardHeader(title: "Biggest changes", sub: "Per day, vs the previous \(d.win) days")
                    if d.changes.isEmpty {
                        EmptyNote("Not enough history yet to compare.")
                    } else {
                        HStack {
                            Text("App").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Now").frame(width: 70, alignment: .trailing)
                            Text("Before").frame(width: 70, alignment: .trailing)
                            Text("Change").frame(width: 90, alignment: .trailing)
                        }
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(skin.dim)
                        ForEach(d.changes, id: \.app) { c in
                            HStack {
                                HStack(spacing: 8) {
                                    IconView(kind: "app", name: c.app, size: 20)
                                    Text(c.app).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(Fmt.duration(c.now)).frame(width: 70, alignment: .trailing)
                                Text(Fmt.duration(c.before)).foregroundStyle(skin.muted).frame(width: 70, alignment: .trailing)
                                Text("\(c.diff > 0 ? "▲" : "▼") \(Fmt.duration(abs(c.diff)))")
                                    .foregroundStyle(c.diff > 0 ? skin.bad : skin.good).frame(width: 90, alignment: .trailing)
                            }
                            .font(.system(size: 13)).monospacedDigit()
                            .padding(.vertical, 4)
                        }
                    }
                }
                Card {
                    CardHeader(title: "Where the time goes")
                    KindBar(summary: d.S)
                    RankList(entries: d.S.c.sortedDesc, total: d.S.t, kind: "cat") { model.detail = .cat($0) }
                }
            }
            AISummaryCard(title: "AI coach", key: "i|\(d.win)|\(model.dev.rawValue)|\(Fmt.todayKey)", button: "Analyse my habits",
                          placeholder: "Claude looks at your last \(d.win) days: trends, habits by weekday and hour, what grew or shrank, and gives you a short plan.") {
                let I = d
                let changes = I.changes.map { "\($0.app) \(Int($0.before / 60))→\(Int($0.now / 60)) min" }.joined(separator: "; ")
                return """
                You are a thoughtful habit coach reading someone's own screen-time data for the last \(I.win) days (\(model.deviceText)). Average \(Int(I.S.t / n / 60)) min/day; previous \(I.win) days averaged \(Int(I.Sp.t / Double(I.prevCount) / 60)) min/day.
                \(model.aiBase(I.S, keys: I.days.map(\.k)))
                Average by weekday: \(I.wdAvg.map { "\($0.0) \(Int($0.1 / 60))m" }.joined(separator: ", ")). Late night (23-03) \(Int(I.late / 60)) min/day.
                Biggest per-day changes: \(changes.isEmpty ? "none" : changes).
                Write: 2 sentences on the overall trend, 4 lines starting with "• " on habits (weekday, time of day, what grew/shrank, focus), then a 3-step plan for next week as lines starting with "→ ", each concrete (a limit, a goal, a focus block). Use real numbers. Plain text, under 220 words.
                """
            }
        }
    }
}

/// Daily totals as bars, with the 7-day average and productive time as lines.
private struct TrendCard: View {
    @Environment(\.skin) private var skin
    var days: [(k: String, s: Summary)]

    var body: some View {
        let pts = days.enumerated().map { i, d -> (Date, Double, Double, Double) in
            let w = days[max(0, i - 6)...i]
            return (Fmt.date(d.k), d.s.t / 3600, d.s.productive / 3600, w.reduce(0) { $0 + $1.s.t } / Double(w.count) / 3600)
        }
        Card {
            CardHeader(title: "Trend") {
                Legend(items: [("Daily total", skin.blue.opacity(0.55)), ("7-day average", skin.acc), ("Productive", skin.good)])
            }
            Chart {
                ForEach(pts, id: \.0) { p in
                    BarMark(x: .value("Day", p.0, unit: .day), y: .value("Hours", p.1))
                        .foregroundStyle(skin.blue.opacity(0.38))
                        .cornerRadius(2)
                }
                ForEach(pts, id: \.0) { p in
                    LineMark(x: .value("Day", p.0, unit: .day), y: .value("Hours", p.2), series: .value("Series", "Productive"))
                        .foregroundStyle(skin.good)
                        .lineStyle(StrokeStyle(lineWidth: 1.6))
                }
                ForEach(pts, id: \.0) { p in
                    LineMark(x: .value("Day", p.0, unit: .day), y: .value("Hours", p.3), series: .value("Series", "Average"))
                        .foregroundStyle(skin.acc)
                        .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        .interpolationMethod(.monotone)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    AxisGridLine().foregroundStyle(skin.line)
                    AxisValueLabel { if let h = v.as(Double.self) { Text("\(Int(h))h").foregroundStyle(skin.dim) } }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 7)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(skin.dim)
                }
            }
            .frame(height: 240)
        }
    }
}
