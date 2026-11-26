import Foundation
import SQLite3

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
        out.append(contentsOf: knowledgeReport(f))
        let today = Fmt.todayKey
        var by: [String: Double] = [:]
        for g in BiomeReader.sessions(events) where Fmt.key(epoch: g.s) == today {
            by[PhoneApps.name(g.app, allowNetwork: false), default: 0] += g.duration
        }
        out.append("Today (\(today)) iPhone total: \(Fmt.duration(by.values.reduce(0, +)))")
        for (a, v) in by.sorted(by: { $0.value > $1.value }) { out.append("  \(a): \(Fmt.duration(v))") }
        try? (out.joined(separator: "\n") + "\n").write(to: Storage.url("iphone-report.txt"), atomically: true, encoding: .utf8)
    }

    /// The older Screen Time database also receives app usage from other devices on some setups.
    /// Lists the newest /app/usage record per device (local device has no ZDEVICEID).
    static func knowledgeReport(_ f: DateFormatter) -> [String] {
        let path = FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Application Support/Knowledge/knowledgeC.db"
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return ["knowledgeC.db: cannot open (\(String(cString: sqlite3_errmsg(db))))"]
        }
        defer { sqlite3_close(db) }
        let sql = """
        SELECT IFNULL(s.ZDEVICEID, 'this Mac'), COUNT(*), MAX(o.ZENDDATE)
        FROM ZOBJECT o LEFT JOIN ZSOURCE s ON o.ZSOURCE = s.Z_PK
        WHERE o.ZSTREAMNAME = '/app/usage' GROUP BY 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return ["knowledgeC.db: query failed (\(String(cString: sqlite3_errmsg(db))))"]
        }
        defer { sqlite3_finalize(stmt) }
        var lines = ["knowledgeC.db /app/usage by device:"]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let dev = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? "?"
            let n = sqlite3_column_int(stmt, 1)
            let last = sqlite3_column_double(stmt, 2) + BiomeReader.appleEpoch
            lines.append("  \(dev): \(n) records, newest \(f.string(from: Date(timeIntervalSince1970: last)))")
        }
        return lines
    }
}
