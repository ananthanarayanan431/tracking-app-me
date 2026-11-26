import Foundation

/// Daily limits on apps, sites or categories (Mac + iPhone), with alerts at 80%, at the
/// limit, and every 15 minutes of continued use past it.
extension AppModel {
    func usage(_ L: Limit, in S: Summary) -> Double {
        switch L.kind {
        case .app: return S.a[L.name] ?? 0
        case .site: return S.d[L.name] ?? 0
        case .cat: return S.c[L.name] ?? 0
        }
    }

    var limitsOver: Int {
        let S = todayAll()
        return settings.limits.filter { usage($0, in: S) >= $0.min * 60 }.count
    }

    func setLimit(kind: LimitKind, name: String, minutes: Double) {
        guard !name.isEmpty, minutes > 0 else { return }
        settings.limits.removeAll { $0.kind == kind && $0.name == name }
        settings.limits.append(Limit(kind: kind, name: name, min: minutes))
        saveSettings()
        if !notificationsAllowed { Task { await enableNotifications() } }
        toast("Limit set: \(name), \(Int(minutes)) min a day")
    }

    /// Accepts "youtube.com", "https://www.youtube.com/x" or an app name.
    func addLimit(custom raw: String, minutes: Double) {
        let v = raw.trimmingCharacters(in: .whitespaces)
        let isSite = v.range(of: #"\.[a-z]{2,}(/.*)?$"#, options: [.regularExpression, .caseInsensitive]) != nil
        if isSite {
            setLimit(kind: .site, name: BrowserProbe.domain(of: v), minutes: minutes)
        } else {
            setLimit(kind: .app, name: v, minutes: minutes)
        }
    }

    func removeLimit(_ id: String) {
        settings.limits.removeAll { $0.id == id }
        saveSettings()
    }

    func updateLimit(_ id: String, minutes: Double) {
        guard minutes > 0, let i = settings.limits.firstIndex(where: { $0.id == id }) else { return }
        settings.limits[i].min = minutes
        saveSettings()
    }

    func checkLimits() {
        guard !settings.limits.isEmpty else { return }
        let S = todayAll()
        let k = Fmt.todayKey
        let now = Date().timeIntervalSince1970
        var fired = limitFired[k] ?? [:]
        for L in settings.limits {
            let u = usage(L, in: S), lim = L.min * 60
            var f = fired[L.id] ?? LimitFire()
            if u >= lim * 0.8, u < lim, f.w == nil {
                f.w = 1
                notify("Heads up: \(Fmt.duration(u)) of your \(Fmt.duration(lim)) \(L.name) limit used today.")
            } else if u >= lim, f.r == nil {
                f.r = now
                f.w = 1
                notify("Limit reached: \(L.name), \(Fmt.duration(u)) today (limit \(Fmt.duration(lim))).")
            } else if u >= lim, let r = f.r, now - r >= 900, let c = current {
                let hit: Bool
                switch L.kind {
                case .app: hit = c.app == L.name
                case .site: hit = c.dom == L.name
                case .cat: hit = classifier.classify(app: c.app, dom: c.dom).cat == L.name
                }
                if hit {
                    f.r = now
                    notify("Still on \(L.name): \(Fmt.duration(u - lim)) over today’s limit.")
                }
            }
            fired[L.id] = f
        }
        limitFired = [k: fired]
        Storage.write("alerts.json", limitFired)
    }
}
