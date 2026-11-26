import Foundation

enum CampaignState { case upcoming, active, finished }

struct CampaignStats {
    var done = 0
    var elapsed = 0
    var missed = 0
    var cur = 0
    var best = 0
    var dayN = 0
    var left = 0
    var rate = 0
    var state: CampaignState = .active
    var todayDone = false
    var inToday = false
    var end = ""
}

/// Campaigns: a run of N days you commit to, one dot per day.
extension AppModel {
    var campaigns: [Campaign] { settings.campaigns }

    func campaignMarked(_ c: Campaign, _ k: String) -> Bool {
        if clog[c.id]?[k] != nil { return true }
        if !c.habit.isEmpty, let h = habit(c.habit) { return isDone(h, k) }
        return false
    }

    func campaignStats(_ c: Campaign) -> CampaignStats {
        let t = Fmt.todayKey
        let ks = c.dayKeys
        let past = ks.filter { $0 < t }
        let inT = ks.contains(t)
        var s = CampaignStats()
        s.inToday = inT
        s.end = c.end
        s.done = ks.filter { $0 <= t && campaignMarked(c, $0) }.count
        s.elapsed = past.count + (inT && campaignMarked(c, t) ? 1 : 0)
        for k in ks.reversed() where k <= t {
            if campaignMarked(c, k) { s.cur += 1 } else if k == t { continue } else { break }
        }
        var run = 0
        for k in ks {
            if k > t { break }
            if campaignMarked(c, k) { run += 1; s.best = max(s.best, run) } else if k != t { run = 0 }
        }
        s.missed = past.filter { !campaignMarked(c, $0) }.count
        let daysIn = Int((Fmt.date(t).timeIntervalSince(Fmt.date(c.start)) / Fmt.day).rounded()) + 1
        s.dayN = min(c.days, max(0, daysIn))
        s.state = t < c.start ? .upcoming : t > c.end ? .finished : .active
        s.todayDone = inT && campaignMarked(c, t)
        s.left = max(0, ks.filter { $0 > t }.count + (inT && !campaignMarked(c, t) ? 1 : 0))
        s.rate = s.elapsed > 0 ? Int((Double(s.done) / Double(s.elapsed) * 100).rounded()) : 0
        return s
    }

    func toggleCampaign(_ id: String, _ k: String) {
        guard let c = settings.campaigns.first(where: { $0.id == id }), k <= Fmt.todayKey else { return }
        if clog[id]?[k] != nil {
            clog[id]?[k] = nil
        } else {
            clog[id, default: [:]][k] = CampaignMark(at: k == Fmt.todayKey ? Fmt.nowHM() : "")
            toast("\(c.name): day \((c.dayKeys.firstIndex(of: k) ?? 0) + 1) dotted")
        }
        Storage.write("campaigns.json", clog)
    }

    func saveCampaign(_ c: Campaign) {
        if let i = settings.campaigns.firstIndex(where: { $0.id == c.id }) {
            settings.campaigns[i] = c
            toast("Campaign updated")
        } else {
            settings.campaigns.append(c)
            toast("Campaign started: \(c.name)")
        }
        saveSettings()
    }

    func deleteCampaign(_ id: String) {
        settings.campaigns.removeAll { $0.id == id }
        clog[id] = nil
        saveSettings()
        Storage.write("campaigns.json", clog)
        toast("Campaign deleted")
    }

    var campaignsDue: Int {
        campaigns.filter { let s = campaignStats($0); return s.state == .active && !s.todayDone }.count
    }
}
