import Foundation

/// Everything Spent keeps lives in ~/.spent:
///   data/YYYY-MM-DD.tsv   one line per segment: start, end, app, domain, title, profile
///   current.tsv           the segment being recorded right now
///   *.json                settings, habits, campaigns, focus log, away log, caches
enum Storage {
    static let root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".spent")
    static let dataDir = root.appendingPathComponent("data")
    static let iconsDir = root.appendingPathComponent("icons")

    static func ensureDirs() {
        for d in [root, dataDir, iconsDir] {
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
    }

    static func url(_ name: String) -> URL { root.appendingPathComponent(name) }
    static func dayFile(_ key: String) -> URL { dataDir.appendingPathComponent("\(key).tsv") }

    // MARK: JSON

    static func read<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func write<T: Encodable>(_ name: String, _ value: T) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        guard let data = try? enc.encode(value) else { return }
        try? data.write(to: url(name), options: .atomic)
    }

    static func readText(_ name: String) -> String? {
        try? String(contentsOf: url(name), encoding: .utf8)
    }

    static func writeText(_ name: String, _ text: String) {
        try? text.write(to: url(name), atomically: true, encoding: .utf8)
    }

    static func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(name).path)
    }

    static func remove(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
    }

    // MARK: Day files

    static func availableDays() -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dataDir.path)) ?? []
        return Set(names.filter { $0.hasSuffix(".tsv") }.map { String($0.prefix(10)) })
    }

    static func parseTSV(_ text: String, device: Device = .mac) -> [Segment] {
        text.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            let a = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard a.count >= 3, !a[2].isEmpty, let s = Double(a[0]), let e = Double(a[1]), e > s else { return nil }
            return Segment(s: s, e: e, app: a[2],
                           dom: a.count > 3 ? a[3] : "",
                           title: a.count > 4 ? a[4] : "",
                           prof: a.count > 5 ? a[5] : "",
                           dev: device)
        }
    }

    static func readDay(_ key: String) -> [Segment] {
        guard let text = try? String(contentsOf: dayFile(key), encoding: .utf8) else { return [] }
        return parseTSV(text)
    }

    static func clean(_ s: String) -> String {
        String(s.map { $0 == "\t" || $0 == "\n" || $0 == "\r" ? " " : $0 }.prefix(240))
    }

    static func line(_ g: Segment) -> String {
        "\(Int(g.s))\t\(Int(g.e))\t\(clean(g.app))\t\(clean(g.dom))\t\(clean(g.title))\t\(clean(g.prof))\n"
    }

    /// Appends a finished segment to the file of the day it started on.
    static func append(_ g: Segment) {
        guard g.e > g.s else { return }
        let file = dayFile(Fmt.key(epoch: g.s))
        let data = Data(line(g).utf8)
        if let h = try? FileHandle(forWritingTo: file) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: data)
        } else {
            try? data.write(to: file)
        }
    }
}
