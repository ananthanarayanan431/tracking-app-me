import AppKit

/// Reading tracked time: raw segments, per-day summaries (cached), periods.
extension AppModel {
    func macSegments(_ key: String) -> [Segment] {
        var segs: [Segment] = []
        if daysAvail.contains(key) || key == Fmt.todayKey { segs = Storage.readDay(key) }
        if let c = current, Fmt.key(epoch: c.s) == key, c.e > c.s { segs.append(c) }
        return segs
    }

    func phoneSegments(_ key: String) -> [Segment] { phone.byDay[key] ?? [] }

    func macSummary(_ key: String) -> Summary {
        let old = key < Fmt.key(Fmt.addDays(Date(), -1))
        if old, let s = cache.days[key] { return s }
        if !daysAvail.contains(key), key != Fmt.todayKey { return Summary() }
        let S = Summarizer.summarize(macSegments(key), classifier: classifier)
        if old {
            cache.days[key] = S
            cache.dirty = true
        }
        return S
    }

    func manualFor(_ key: String) -> [ManualPhone] { manual.filter { $0.date == key } }

    func phoneSummary(_ key: String) -> Summary {
        var S = Summarizer.summarize(phoneSegments(key), classifier: classifier)
        for m in manualFor(key) {
            let du = m.min * 60
            let (c, kind) = classifier.classify(app: m.app)
            S.t += du
            S.a[m.app, default: 0] += du
            S.c[c, default: 0] += du
            S.add(kind, du)
        }
        return S
    }

    func dayData(_ key: String) -> DayData {
        DayData(k: key, mac: macSummary(key), ph: phoneSummary(key))
    }

    func periodData(_ r: DayRange) -> [DayData] { r.keys.map(dayData) }

    var currentRange: DayRange { DayRange.period(period, anchor: anchor) }

    func todayAll() -> Summary {
        let k = Fmt.todayKey
        return Summarizer.merge([macSummary(k), phoneSummary(k)])
    }

    // MARK: Gaps (time away from the Mac)

    var awayThreshold: Double { Double(settings.awayMin ?? 20) * 60 }

    func gaps(mac: [Segment], phone ph: [Segment]) -> [Gap] {
        let s = mac.filter { $0.dev == .mac }.sorted { $0.s < $1.s }
        guard var me = s.first?.e else { return [] }
        var out: [Gap] = []
        for g in s.dropFirst() {
            let gap = g.s - me
            if gap >= awayThreshold, gap <= 12 * Fmt.hour {
                let onPhone = ph.reduce(0.0) { $0 + max(0, min($1.e, g.s) - max($1.s, me)) }
                if onPhone < gap * 0.6 { out.append(Gap(s: me.rounded(), e: g.s.rounded(), ph: onPhone)) }
            }
            me = max(me, g.e)
        }
        return out
    }

    func awayEntry(for s: Double) -> AwayEntry? { away.first { abs($0.s - s) < 90 } }

    // MARK: Export

    func exportCSV() {
        var csv = "date,device,app,site,page,category,type,start,end,seconds\n"
        func q(_ v: String) -> String { "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let iso = ISO8601DateFormatter()
        for k in DayRange.lastN(30).keys {
            for g in macSegments(k) + phoneSegments(k) {
                let (c, t) = classifier.classify(app: g.app, dom: g.dom)
                csv += [k, g.dev.rawValue, q(g.app), q(g.dom), q(g.title), q(c), t.label,
                        iso.string(from: Date(timeIntervalSince1970: g.s)), iso.string(from: Date(timeIntervalSince1970: g.e)),
                        String(Int(g.duration.rounded()))].joined(separator: ",") + "\n"
            }
            for m in manualFor(k) { csv += [k, "phone-manual", q(m.app), "", "", "", "", "", "", String(Int(m.min * 60))].joined(separator: ",") + "\n" }
        }
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/spent-last-30-days-\(Fmt.todayKey).csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            toast("Saved to Downloads")
        } catch {
            toast("Couldn’t save the CSV: \(error.localizedDescription)")
        }
    }
}
