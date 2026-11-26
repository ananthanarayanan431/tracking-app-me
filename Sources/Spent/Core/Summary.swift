import Foundation

/// Totals for a day (or a merged period). Field names are short because thousands of these
/// are cached to disk.
struct Summary: Codable {
    var t: Double = 0                          // total seconds
    var a: [String: Double] = [:]              // by app
    var d: [String: Double] = [:]              // by domain
    var p: [String: Double] = [:]              // by "domain\ttitle"
    var c: [String: Double] = [:]              // by category
    var bp: [String: Double] = [:]             // by "app · profile"
    var pd: [String: [String: Double]] = [:]   // profile → domain → seconds
    var y: [String: Double] = ["p": 0, "n": 0, "d": 0] // by kind
    var ah: [String: [Double]] = [:]           // app → 24 hourly buckets
    var h: [Double] = Array(repeating: 0, count: 24)
    var n = 0                                  // sessions
    var L: Double = 0                          // longest stretch
    var La = ""                                // app of longest stretch
    var f: Double = 0                          // first active (epoch)
    var l: Double = 0                          // last active (epoch)
    var sw = 0                                 // app switches

    func kind(_ k: Kind) -> Double { y[k.rawValue] ?? 0 }
    var productive: Double { kind(.p) }
    var neutral: Double { kind(.n) }
    var distracting: Double { kind(.d) }

    /// 0–100: share of productive time (neutral counts half), minus a little for constant switching.
    var score: Int? {
        guard t >= 300 else { return nil }
        let base = (productive + 0.5 * neutral) / t * 100
        let switchesPerHour = Double(sw) / max(t / Fmt.hour, 0.5)
        let penalty = min(15, max(0, (switchesPerHour - 20) * 0.5))
        return max(0, min(100, Int((base - penalty).rounded())))
    }

    var webTotal: Double { d.values.reduce(0, +) }

    mutating func add(_ k: Kind, _ v: Double) { y[k.rawValue, default: 0] += v }
}

enum Summarizer {
    /// Merges adjacent segments of the same app/site/profile into sessions.
    static func sessions(_ segs: [Segment]) -> [Session] {
        var out: [Session] = []
        for g in segs.sorted(by: { $0.s < $1.s }) {
            if var p = out.last, p.app == g.app, p.dom == g.dom, p.prof == g.prof, p.dev == g.dev, g.s - p.e <= 10 {
                p.e = max(p.e, g.e)
                if !g.title.isEmpty, !p.titles.contains(g.title) { p.titles.append(g.title) }
                out[out.count - 1] = p
            } else {
                out.append(Session(s: g.s, e: g.e, app: g.app, dom: g.dom, prof: g.prof, dev: g.dev,
                                   titles: g.title.isEmpty ? [] : [g.title]))
            }
        }
        return out
    }

    static func summarize(_ segs: [Segment], classifier: Classifier) -> Summary {
        var S = Summary()
        guard !segs.isEmpty else { return S }
        let cal = Fmt.calendar
        for g in segs {
            let du = g.e - g.s
            guard du > 0 else { continue }
            S.t += du
            S.a[g.app, default: 0] += du
            if !g.dom.isEmpty {
                S.d[g.dom, default: 0] += du
                if !g.title.isEmpty { S.p[g.dom + "\t" + g.title, default: 0] += du }
            }
            let (cat, kind) = classifier.classify(app: g.app, dom: g.dom, prof: g.prof)
            if !g.prof.isEmpty {
                let bk = g.app + " · " + g.prof
                S.bp[bk, default: 0] += du
                if !g.dom.isEmpty { S.pd[bk, default: [:]][g.dom, default: 0] += du }
            }
            S.c[cat, default: 0] += du
            S.add(kind, du)
            var ah = S.ah[g.app] ?? Array(repeating: 0, count: 24)
            var t = g.s
            while t < g.e {
                let d = Date(timeIntervalSince1970: t)
                let c = cal.dateComponents([.hour, .minute, .second], from: d)
                let next = min(g.e, t - Double(c.minute! * 60 + c.second!) + Fmt.hour)
                S.h[c.hour!] += next - t
                ah[c.hour!] += next - t
                t = next
            }
            S.ah[g.app] = ah
            if S.f == 0 || g.s < S.f { S.f = g.s }
            if g.e > S.l { S.l = g.e }
        }
        // Per-app runs for session count, switches and longest stretch.
        var runs: [(app: String, s: Double, e: Double)] = []
        for g in segs.sorted(by: { $0.s < $1.s }) {
            if let p = runs.last, p.app == g.app, g.s - p.e <= 10 {
                runs[runs.count - 1].e = max(p.e, g.e)
            } else {
                runs.append((g.app, g.s, g.e))
            }
        }
        S.n = runs.count
        S.sw = max(0, runs.count - 1)
        for r in runs where r.e - r.s > S.L {
            S.L = r.e - r.s
            S.La = r.app
        }
        S.p = Dictionary(uniqueKeysWithValues: S.p.sortedDesc.prefix(60).map { ($0.key, $0.value) })
        for k in S.ah.keys { S.ah[k] = S.ah[k]!.map { $0.rounded() } }
        return S
    }

    static func merge(_ list: [Summary]) -> Summary {
        var S = Summary()
        for x in list where x.t > 0 {
            S.t += x.t
            for (k, v) in x.a { S.a[k, default: 0] += v }
            for (k, v) in x.d { S.d[k, default: 0] += v }
            for (k, v) in x.p { S.p[k, default: 0] += v }
            for (k, v) in x.c { S.c[k, default: 0] += v }
            for (k, v) in x.y { S.y[k, default: 0] += v }
            for (k, v) in x.bp { S.bp[k, default: 0] += v }
            for (k, o) in x.pd { for (dd, v) in o { S.pd[k, default: [:]][dd, default: 0] += v } }
            for (k, arr) in x.ah {
                var a = S.ah[k] ?? Array(repeating: 0, count: 24)
                for (i, v) in arr.enumerated() where i < 24 { a[i] += v }
                S.ah[k] = a
            }
            for (i, v) in x.h.enumerated() where i < 24 { S.h[i] += v }
            S.n += x.n
            S.sw += x.sw
            if x.L > S.L { S.L = x.L; S.La = x.La }
            if x.f > 0, S.f == 0 || x.f < S.f { S.f = x.f }
            if x.l > S.l { S.l = x.l }
        }
        return S
    }
}
