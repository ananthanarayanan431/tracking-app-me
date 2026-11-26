import SwiftUI

/// Drill-down for one app, site, category or browser profile: totals, day by day,
/// time of day, related sites/pages, its label and a quick daily limit.
struct DetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skin) private var skin
    @Environment(\.dismiss) private var dismiss
    var target: DetailTarget
    @State private var limitMinutes = ""

    private var kind: String {
        switch target {
        case .app: return "app"
        case .site: return "site"
        case .cat: return "cat"
        case .prof: return "prof"
        }
    }

    private var name: String {
        switch target {
        case .app(let n), .site(let n), .cat(let n), .prof(let n): return n
        }
    }

    private func value(_ s: Summary) -> Double {
        switch target {
        case .app(let n): return s.a[n] ?? 0
        case .site(let n): return s.d[n] ?? 0
        case .cat(let n): return s.c[n] ?? 0
        case .prof(let n): return s.bp[n] ?? 0
        }
    }

    var body: some View {
        let R = model.tab == .overview && model.period != .day ? model.currentRange : DayRange.lastN(30)
        let days = model.periodData(R)
        let S = Summarizer.merge(days.map { $0.pick(model.dev) })
        let ds = days.map { (k: $0.k, v: value($0.pick(model.dev))) }
        let tot = ds.reduce(0) { $0 + $1.v }
        let active = max(1, ds.filter { $0.v > 0 }.count)
        let col = Color(hex: kind == "cat" ? (Classifier.categoryColors[name] ?? "#5f6878") : Palette.shared.color(name))
        let split = name.range(of: " · ")
        let pApp = kind == "prof" && split != nil ? String(name[..<split!.lowerBound]) : ""
        let pName = kind == "prof" && split != nil ? String(name[split!.upperBound...]) : name

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    IconView(kind: kind == "prof" ? "app" : kind, name: kind == "prof" ? pApp : name, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pName).font(.system(size: 22, weight: .bold)).lineLimit(1)
                        Text("\(R.label) · \(kind == "prof" ? "\(pApp) profile" : ["app": "App", "site": "Website", "cat": "Category"][kind] ?? "")")
                            .font(.system(size: 12)).foregroundStyle(skin.muted)
                    }
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark") }.spentButton(.ghost, compact: true)
                        .keyboardShortcut(.cancelAction)
                }
                StatGrid(items: [(Fmt.duration(tot), "Total"), (Fmt.duration(tot / Double(active)), "Per active day"),
                                 ("\(Fmt.percent(tot, of: S.t))%", "Of screen time")], columns: 3)
                SectionLabel(text: "Day by day")
                Columns(bars: ds.enumerated().map { ColumnBar(id: $0, total: $1.v, parts: [(col, $1.v)], tip: "\(Fmt.shortDate($1.k)) · \(Fmt.duration($1.v))") },
                        labels: ds.enumerated().map { i, x in
                            ds.count > 10 ? (i % 5 == 0 ? "\(Fmt.calendar.component(.day, from: Fmt.date(x.k)))" : "") : Fmt.weekdayName(x.k)
                        }, height: 120)
                extra(S: S, tot: tot, col: col)
                labelSection
                if kind != "prof" { limitSection(tot: tot, active: active) }
            }
            .padding(26)
        }
        .frame(width: 600, height: 720)
        .background(skin.panel)
    }

    @ViewBuilder
    private func extra(S: Summary, tot: Double, col: Color) -> some View {
        let open: (String, String) -> Void = { k, n in
            switch k {
            case "app": model.detail = .app(n)
            case "site": model.detail = .site(n)
            case "prof": model.detail = .prof(n)
            default: model.detail = .cat(n)
            }
        }
        switch target {
        case .app(let n):
            if let hh = S.ah[n] {
                let pk = hh.firstIndex(of: hh.max() ?? 0) ?? 0
                SectionLabel(text: "Time of day · peak \(Fmt.pad(pk)):00")
                Columns(bars: hh.enumerated().map { ColumnBar(id: $0, total: $1, parts: [(col, $1)], tip: "\(Fmt.pad($0)):00 · \(Fmt.duration($1))") },
                        labels: (0..<24).map { $0 % 6 == 0 ? Fmt.pad($0) : "" }, height: 100)
            }
            if Classifier.browsers.contains(n), !S.d.isEmpty {
                SectionLabel(text: "Sites in browsers")
                RankList(entries: Array(S.d.sortedDesc.prefix(8)), total: S.webTotal, kind: "site") { open("site", $0) }
            }
            let profs = S.bp.sortedDesc.filter { $0.key.hasPrefix(n + " · ") }
            if !profs.isEmpty {
                SectionLabel(text: "Accounts / profiles")
                RankList(entries: profs, total: tot, kind: "prof") { open("prof", $0) }
            }
        case .prof(let n):
            if let pd = S.pd[n], !pd.isEmpty {
                SectionLabel(text: "Sites in this profile")
                RankList(entries: Array(pd.sortedDesc.prefix(10)), total: tot, kind: "site") { open("site", $0) }
            }
        case .site(let n):
            let pages = S.p.sortedDesc.filter { $0.key.hasPrefix(n + "\t") }.prefix(12)
            if !pages.isEmpty {
                SectionLabel(text: "Top pages")
                ForEach(Array(pages), id: \.key) { k, v in
                    HStack {
                        Text(k.components(separatedBy: "\t").dropFirst().joined()).lineLimit(1)
                        Spacer()
                        Text(Fmt.duration(v)).monospacedDigit().foregroundStyle(skin.muted)
                    }
                    .font(.system(size: 13))
                }
            }
        case .cat(let n):
            let apps = S.a.filter { model.classifier.classify(app: $0.key).cat == n }.sortedDesc.prefix(8)
            let sites = S.d.filter { model.classifier.classify(app: "", dom: $0.key).cat == n }.sortedDesc.prefix(8)
            if !apps.isEmpty {
                SectionLabel(text: "Apps")
                RankList(entries: Array(apps), total: tot, kind: "app") { open("app", $0) }
            }
            if !sites.isEmpty {
                SectionLabel(text: "Websites")
                RankList(entries: Array(sites), total: tot, kind: "site") { open("site", $0) }
            }
        }
    }

    @ViewBuilder private var labelSection: some View {
        if kind == "cat" {
            let t = Classifier.defaultKind[name] ?? .n
            HStack(spacing: 6) {
                Text("Counts as")
                Tag(text: t.label, kind: t)
                Text(". Move individual apps between categories from their own page or Settings › Labels.")
            }
            .font(.system(size: 13)).foregroundStyle(skin.muted)
        } else {
            SectionLabel(text: "Label")
            LabelRow(kind: kind, name: name, value: nil)
        }
    }

    @ViewBuilder
    private func limitSection(tot: Double, active: Int) -> some View {
        SectionLabel(text: "Daily limit")
        if let L = model.settings.limits.first(where: { $0.kind.rawValue == kind && $0.name == name }) {
            Note("Limit set: \(Fmt.duration(L.min * 60)) a day. Change it on the Limits page.")
        } else {
            HStack {
                TextField("30", text: $limitMinutes).spentField().frame(width: 80)
                Button("Set daily limit (min)") {
                    if let k = LimitKind(rawValue: kind), let m = Double(limitMinutes), m > 0 {
                        model.setLimit(kind: k, name: name, minutes: m)
                        model.checkLimits()
                    }
                }
                .spentButton(.primary)
            }
            .onAppear {
                let perDay = tot / Double(active) / 60
                limitMinutes = "\(max(15, Int((perDay / 15).rounded()) * 15))"
            }
        }
    }
}
