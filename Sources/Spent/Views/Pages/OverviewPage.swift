import SwiftUI

/// Everything the Overview page shows, computed once per render.
struct OverviewData {
    var range: DayRange
    var days: [DayData]
    var S: Summary
    var Smac: Summary
    var Sph: Summary
    var Sprev: Summary
    var daySegs: [Segment] = []
    var gaps: [Gap] = []

    @MainActor
    init(model m: AppModel) {
        _ = m.revision
        range = m.currentRange
        days = m.periodData(range)
        S = Summarizer.merge(days.map { $0.pick(m.dev) })
        Smac = Summarizer.merge(days.map(\.mac))
        Sph = Summarizer.merge(days.map(\.ph))
        let prev = DayRange.period(m.period, anchor: DayRange.shift(m.period, m.anchor, by: -1))
        Sprev = Summarizer.merge(m.periodData(prev).map { $0.pick(m.dev) })
        if m.period == .day, let k = range.keys.first {
            let mac = m.macSegments(k), ph = m.phoneSegments(k)
            daySegs = (m.dev != .phone ? mac : []) + (m.dev != .mac ? ph : [])
            gaps = m.awayOn ? m.gaps(mac: mac, phone: ph) : []
        }
        // Assign palette colours biggest-first so the top app gets the first colour.
        for (a, _) in S.a.sortedDesc { _ = Palette.shared.color(a) }
    }
}

struct OverviewPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin

    var body: some View {
        let d = OverviewData(model: model)
        VStack(spacing: 16) {
            SpanRow(spans: [5, 7]) {
                HeroCard(d: d)
                ChartCard(d: d)
            }
            SpanRow(spans: [1, 1, 1]) {
                Card {
                    CardHeader(title: "Apps", sub: "\(d.S.a.count) used")
                    RankList(entries: d.S.a.sortedDesc, total: d.S.t, kind: "app") { model.detail = .app($0) }
                }
                Card {
                    CardHeader(title: "Websites", sub: "\(Fmt.duration(d.S.webTotal)) in browsers")
                    RankList(entries: d.S.d.sortedDesc, total: d.S.webTotal, kind: "site",
                             empty: "No browser tabs yet. Chrome, Safari, Arc, Brave, Edge and Comet tabs show up here.") { model.detail = .site($0) }
                }
                Card {
                    CardHeader(title: "Categories", sub: "Tap to relabel")
                    RankList(entries: d.S.c.sortedDesc, total: d.S.t, kind: "cat") { model.detail = .cat($0) }
                }
            }
            if !d.S.bp.isEmpty { BrowserAccountsCard(S: d.S) }
            if model.period == .day, let k = d.range.keys.first, !d.gaps.isEmpty {
                AwaySection(key: k, gaps: d.gaps)
            }
            if d.range.label == "Today" { TodayHabitsAndCampaigns() }
            StatsCard(d: d)
            AISummaryCard(title: "AI summary", key: "o|\(model.period.rawValue)|\(Fmt.key(d.range.start))|\(model.dev.rawValue)",
                          button: "Write summary",
                          placeholder: "Claude reads this period’s numbers and tells you what stands out, plus two practical suggestions.") {
                model.overviewPrompt(d)
            }
            SessionLog(d: d)
        }
    }
}

// MARK: Hero

private struct HeroCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    var d: OverviewData

    var body: some View {
        let S = d.S
        let noun: String = {
            switch model.period {
            case .day: return d.range.label == "Today" ? "today" : "on this day"
            case .week: return "this week"
            case .month: return "this month"
            case .year: return "this year"
            }
        }()
        let prevName: String = {
            switch model.period {
            case .day: return "the day before"
            case .week: return "last week"
            case .month: return "last month"
            case .year: return "last year"
            }
        }()
        let df = S.t - d.Sprev.t
        Card(padding: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Screen time \(noun)").font(.system(size: 13, weight: .medium)).foregroundStyle(skin.muted)
                    Text(Fmt.duration(S.t)).font(.system(size: 54, weight: .bold)).minimumScaleFactor(0.5).lineLimit(1)
                    Text(d.Sprev.t > 0 ? "\(df >= 0 ? "▲" : "▼") \(Fmt.duration(abs(df))) vs \(prevName)" : "Nothing recorded \(prevName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(d.Sprev.t == 0 ? skin.muted : df > 0 ? skin.bad : skin.good)
                }
                Spacer()
                ScoreRing(value: S.score, size: 112)
            }
            HStack(spacing: 10) {
                deviceTile("laptopcomputer", Fmt.duration(d.Smac.t), "Mac")
                deviceTile("iphone", Fmt.duration(d.Sph.t), "iPhone")
            }
            KindBar(summary: S)
            HStack(spacing: 10) { ForEach(minis.indices, id: \.self) { i in mini(minis[i]) } }
        }
    }

    private var minis: [(String, String, String?)] {
        let S = d.S
        let topApp = S.a.sortedDesc.first?.key ?? "–"
        if model.period == .day {
            return [(S.f > 0 ? Fmt.clock(S.f) : "–", "First active", nil), (S.l > 0 ? Fmt.clock(S.l) : "–", "Last active", nil),
                    (topApp, "Top app", "app")]
        }
        let active = max(1, d.days.filter { $0.pick(model.dev).t > 0 }.count)
        return [(Fmt.duration(S.t / Double(active)), "Daily average", nil), (topApp, "Top app", "app"),
                (S.d.sortedDesc.first?.key ?? "–", "Top site", "site")]
    }

    private func deviceTile(_ symbol: String, _ value: String, _ label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(skin.muted).frame(width: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.system(size: 16, weight: .semibold))
                Text(label).font(.system(size: 11)).foregroundStyle(skin.muted)
            }
            Spacer()
        }
        .padding(10)
        .background(skin.panel2, in: RoundedRectangle(cornerRadius: 12))
    }

    private func mini(_ m: (String, String, String?)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if let k = m.2, m.0 != "–" { IconView(kind: k, name: m.0, size: 16) }
                Text(m.0).font(.system(size: 14, weight: .semibold)).lineLimit(1).truncationMode(.middle)
            }
            Text(m.1).font(.system(size: 11)).foregroundStyle(skin.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Chart

private struct ChartCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    var d: OverviewData

    var body: some View {
        let topApps = d.S.a.sortedDesc.prefix(7).map(\.key)
        let title: String = {
            switch model.period {
            case .day: return "Your day on tape"
            case .week: return "Day by day"
            case .month: return "Every day this month"
            case .year: return "Every day of the year"
            }
        }()
        Card {
            CardHeader(title: title, sub: d.range.label)
            switch model.period {
            case .day:
                DayTape(dayStart: d.range.start.timeIntervalSince1970, sessions: Summarizer.sessions(d.daySegs),
                        showMac: model.dev != .phone, showPhone: model.dev != .mac, gaps: d.gaps,
                        awayFor: { model.awayEntry(for: $0) })
                SectionLabel(text: "Hour by hour")
                hourColumns(topApps)
            case .year:
                let vals = Dictionary(uniqueKeysWithValues: d.days.map { ($0.k, $0.pick(model.dev).t) })
                YearHeatmap(keys: d.range.all, values: vals)
                SectionLabel(text: "Month by month")
                let months = (1...12).map { m in
                    d.range.all.filter { Int($0.dropFirst(5).prefix(2)) == m }.reduce(0.0) { $0 + (vals[$1] ?? 0) }
                }
                Columns(bars: months.enumerated().map { ColumnBar(id: $0, total: $1, parts: [(skin.blue, $1)], tip: "\(Fmt.months[$0]) · \(Fmt.duration($1))") },
                        labels: Fmt.months, height: 120)
            case .week, .month:
                dayColumns(topApps)
            }
            if model.period == .year {
                Note("Brighter = more screen time")
            } else {
                Legend(items: (topApps + ["Other"]).map { ($0, Color(hex: Palette.shared.color($0))) })
            }
        }
    }

    private func hourColumns(_ topApps: [String]) -> some View {
        let S = d.S
        let pk = S.h.firstIndex(of: S.h.max() ?? 0) ?? 0
        let bars = (0..<24).map { i -> ColumnBar in
            var parts = topApps.map { (Color(hex: Palette.shared.color($0)), S.ah[$0]?[i] ?? 0) }
            parts.append((Color(hex: "#5f6878"), max(0, S.h[i] - parts.reduce(0) { $0 + $1.1 })))
            return ColumnBar(id: i, total: S.h[i], parts: parts, tip: "\(Fmt.pad(i)):00 · \(Fmt.duration(S.h[i]))",
                             highlight: i == pk && S.h[i] > 0)
        }
        return Columns(bars: bars, labels: (0..<24).map { $0 % 3 == 0 ? Fmt.pad($0) : "" }, height: 140)
    }

    private func dayColumns(_ topApps: [String]) -> some View {
        let byKey = Dictionary(uniqueKeysWithValues: d.days.map { ($0.k, $0) })
        let narrow = d.range.all.count > 12
        let bars = d.range.all.enumerated().map { i, k -> ColumnBar in
            let s = byKey[k]?.pick(model.dev) ?? Summary()
            var parts = topApps.map { (Color(hex: Palette.shared.color($0)), s.a[$0] ?? 0) }
            parts.append((Color(hex: "#5f6878"), max(0, s.t - parts.reduce(0) { $0 + $1.1 })))
            return ColumnBar(id: i, total: s.t, parts: parts, tip: "\(Fmt.shortDate(k)) · \(Fmt.duration(s.t))")
        }
        let labels = d.range.all.map { k -> String in
            let day = Fmt.calendar.component(.day, from: Fmt.date(k))
            return narrow ? (day == 1 || day % 5 == 0 ? "\(day)" : "") : "\(Fmt.weekdayName(k)) \(day)"
        }
        return Columns(bars: bars, labels: labels, height: 190)
    }
}

// MARK: Browser accounts

private struct BrowserAccountsCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    var S: Summary

    var body: some View {
        let total = S.bp.values.reduce(0, +)
        Card {
            CardHeader(title: "Browser accounts", sub: "Time in each profile or named window · tap one to label it")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                ForEach(S.bp.sortedDesc, id: \.key) { bk, v in
                    let r = bk.range(of: " · ")!
                    let app = String(bk[..<r.lowerBound]), prof = String(bk[r.upperBound...])
                    let kind = model.classifier.classify(app: app, prof: prof).kind
                    Button { model.detail = .prof(bk) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                IconView(kind: "app", name: app, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(prof).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                    HStack(spacing: 5) {
                                        Text(app).font(.system(size: 12)).foregroundStyle(skin.muted)
                                        Tag(text: kind.label, kind: kind)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text(Fmt.duration(v)).font(.system(size: 15, weight: .semibold))
                                    Text("\(Fmt.percent(v, of: total))%").font(.system(size: 11)).foregroundStyle(skin.dim)
                                }
                            }
                            let sites = (S.pd[bk] ?? [:]).sortedDesc.prefix(4)
                            if sites.isEmpty {
                                Note("No sites yet")
                            } else {
                                ForEach(Array(sites), id: \.key) { dom, sv in
                                    HStack(spacing: 6) {
                                        IconView(kind: "site", name: dom, size: 14)
                                        Text(dom).font(.system(size: 12)).lineLimit(1)
                                        Spacer()
                                        Text(Fmt.duration(sv)).font(.system(size: 12)).foregroundStyle(skin.muted)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(skin.panel2, in: RoundedRectangle(cornerRadius: 14))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: Stats

private struct StatsCard: View {
    @Environment(AppModel.self) private var model
    var d: OverviewData

    var body: some View {
        let S = d.S
        let pk = S.h.firstIndex(of: S.h.max() ?? 0) ?? 0
        let best = d.days.map { ($0.k, $0.pick(model.dev).t) }.max { $0.1 < $1.1 }
        let last: (String, String) = model.period == .day
            ? (S.f > 0 ? Fmt.duration(S.l - S.f) : "–", "First to last activity")
            : (best.map { $0.1 > 0 ? "\(Fmt.shortDate($0.0)) · \(Fmt.duration($0.1))" : "–" } ?? "–", "Heaviest day")
        Card {
            CardHeader(title: "Statistics")
            StatGrid(items: [
                (Fmt.duration(S.L), "Longest stretch\(S.La.isEmpty ? "" : " · " + S.La)"),
                ("\(S.n)", "Sessions"),
                ("\(S.sw)", "App switches"),
                (S.n > 0 ? Fmt.duration(S.t / Double(S.n)) : "–", "Average session"),
                (S.t > 0 ? "\(Fmt.pad(pk)):00" : "–", "Busiest hour"),
                ("\(S.a.count)", "Apps used"),
                ("\(S.d.count)", "Websites visited"),
                last,
            ])
        }
    }
}

// MARK: Session log

private struct SessionLog: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    var d: OverviewData

    var body: some View {
        @Bindable var model = model
        let f = model.query.lowercased()
        let match = { (t: String) in f.isEmpty || t.lowercased().contains(f) }
        Card {
            if model.period == .day {
                let ss = Array(Summarizer.sessions(d.daySegs).reversed())
                let rows = ss.filter { match("\($0.app) \($0.dom) \($0.titles.joined(separator: " "))") }
                header("Every session · \(ss.count)")
                if rows.isEmpty {
                    EmptyNote("No sessions match.")
                } else {
                    tableHead(["Time", "App", "Site · page", "Device", "Duration"])
                    LazyVStack(spacing: 0) {
                        ForEach(rows.prefix(400)) { x in sessionRow(x) }
                    }
                }
            } else {
                header("Day by day, and your top pages")
                let dr = d.days.filter { $0.pick(model.dev).t > 0 }.reversed()
                    .filter { match("\($0.k) \($0.pick(model.dev).a.keys.joined(separator: " "))") }
                tableHead(["Date", "Total", "Mac", "iPhone", "Score", "Top apps"])
                if dr.isEmpty { EmptyNote("Nothing tracked.") }
                LazyVStack(spacing: 0) {
                    ForEach(Array(dr), id: \.k) { day in dayRow(day) }
                }
                SectionLabel(text: "Top pages")
                let pages = d.S.p.sortedDesc.filter { match($0.key) }.prefix(150)
                if pages.isEmpty { EmptyNote("No pages yet.") }
                LazyVStack(spacing: 0) {
                    ForEach(Array(pages), id: \.key) { k, v in
                        let parts = k.components(separatedBy: "\t")
                        HStack(spacing: 8) {
                            IconView(kind: "site", name: parts[0], size: 16)
                            Text(parts[0]).fontWeight(.semibold).frame(width: 180, alignment: .leading).lineLimit(1)
                            Text(parts.count > 1 ? parts[1] : "").foregroundStyle(skin.muted).lineLimit(1)
                            Spacer()
                            Text(Fmt.duration(v)).monospacedDigit()
                        }
                        .font(.system(size: 13)).padding(.vertical, 7)
                        Divider().overlay(skin.line)
                    }
                }
            }
        }
    }

    private func header(_ title: String) -> some View {
        @Bindable var model = model
        return HStack {
            Text(title).font(.system(size: 17, weight: .semibold))
            Spacer()
            TextField("Filter by app, site or page", text: $model.query).spentField().frame(maxWidth: 320)
        }
    }

    private func tableHead(_ cols: [String]) -> some View {
        HStack {
            ForEach(cols, id: \.self) { c in
                Text(c).font(.system(size: 11, weight: .semibold)).foregroundStyle(skin.dim).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }

    private func sessionRow(_ x: Session) -> some View {
        let kind = model.classifier.classify(app: x.app, dom: x.dom, prof: x.prof).kind
        return VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text("\(Fmt.clock(x.s))–\(Fmt.clock(x.e))").monospacedDigit().foregroundStyle(skin.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    IconView(kind: "app", name: x.app, size: 18)
                    Text(x.app).lineLimit(1)
                    if !x.prof.isEmpty { Tag(text: x.prof) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    if !x.dom.isEmpty {
                        HStack(spacing: 5) {
                            IconView(kind: "site", name: x.dom, size: 14)
                            Text(x.dom).fontWeight(.semibold).lineLimit(1)
                        }
                    }
                    if !x.titles.isEmpty {
                        Text(x.titles.suffix(3).joined(separator: " · ") + (x.titles.count > 3 ? " +\(x.titles.count - 3) more" : ""))
                            .font(.system(size: 11)).foregroundStyle(skin.muted).lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    Tag(text: x.dev == .mac ? "Mac" : "iPhone")
                    Tag(text: kind.label, kind: kind)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(Fmt.duration(x.e - x.s)).monospacedDigit().frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 13))
            .padding(.vertical, 8)
            Divider().overlay(skin.line)
        }
    }

    private func dayRow(_ day: DayData) -> some View {
        let s = day.pick(model.dev)
        return VStack(spacing: 0) {
            HStack {
                Text("\(Fmt.weekdayName(day.k)) \(Fmt.shortDate(day.k))").foregroundStyle(skin.muted).frame(maxWidth: .infinity, alignment: .leading)
                Text(Fmt.duration(s.t)).fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                Text(Fmt.duration(day.mac.t)).frame(maxWidth: .infinity, alignment: .leading)
                Text(Fmt.duration(day.ph.t)).frame(maxWidth: .infinity, alignment: .leading)
                Text(s.score.map(String.init) ?? "–").foregroundStyle(skin.scoreColor(s.score)).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 10) {
                    ForEach(s.a.sortedDesc.prefix(3), id: \.key) { a, v in
                        HStack(spacing: 4) {
                            IconView(kind: "app", name: a, size: 14)
                            Text(a).lineLimit(1)
                            Text(Fmt.duration(v)).foregroundStyle(skin.dim)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 13))
            .padding(.vertical, 8)
            Divider().overlay(skin.line)
        }
    }
}
