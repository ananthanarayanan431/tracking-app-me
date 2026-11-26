import Foundation

/// `Spent --iphone-report`: writes what Spent can see of the iPhone data to
/// ~/.spent/iphone-report.txt (sync status, newest record per file, today's per-app totals).
/// Launch it through `open` so it runs with Spent's own Full Disk Access.
enum IPhoneReport {
    static func write() {
        var out: [String] = []
        let fm = FileManager.default
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        out.append("Report made: \(f.string(from: Date()))")
        let (status, events) = BiomeReader.load()
        out.append("Status: \(status)")
        if let last = events.map(\.t).max() {
            out.append("Newest iPhone record: \(f.string(from: Date(timeIntervalSince1970: last)))")
        }
        let remote = BiomeReader.streamDir.appendingPathComponent("remote")
        for dev in (try? fm.contentsOfDirectory(atPath: remote.path)) ?? [] {
            let dir = remote.appendingPathComponent(dev)
            for file in ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).sorted() {
                let url = dir.appendingPathComponent(file)
                let attrs = try? fm.attributesOfItem(atPath: url.path)
                let m = (attrs?[.modificationDate] as? Date).map(f.string(from:)) ?? "?"
                let evs = (try? Data(contentsOf: url)).map(BiomeReader.events(in:)) ?? []
                let newest = evs.map(\.t).max().map { f.string(from: Date(timeIntervalSince1970: $0)) } ?? "-"
                out.append("File \(dev.prefix(8))/\(file): modified \(m), \(evs.count) records, newest \(newest)")
            }
        }
        let today = Fmt.todayKey
        var by: [String: Double] = [:]
        for g in BiomeReader.sessions(events) where Fmt.key(epoch: g.s) == today {
            by[PhoneApps.name(g.app, allowNetwork: false), default: 0] += g.duration
        }
        out.append("Today (\(today)) iPhone total: \(Fmt.duration(by.values.reduce(0, +)))")
        for (a, v) in by.sorted(by: { $0.value > $1.value }) { out.append("  \(a): \(Fmt.duration(v))") }
        try? (out.joined(separator: "\n") + "\n").write(to: Storage.url("iphone-report.txt"), atomically: true, encoding: .utf8)
    }
}
