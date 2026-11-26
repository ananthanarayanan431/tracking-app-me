import Foundation

/// Reads iPhone app usage that macOS syncs from your iPhone when Screen Time's
/// "Share Across Devices" is on. Each synced device has a folder of Apple "SEGB" files under
/// ~/Library/Biome/streams/restricted/App.InFocus/remote/<device-id>/.
///
/// SEGB v2 layout (undocumented, worked out from the files):
///   bytes 0..<4   "SEGB"
///   bytes 4..<8   record count (UInt32 LE)
///   bytes 32...   records, each 4-byte aligned: CRC (4) + unknown (4) + protobuf payload
///   file end      index of `count` 16-byte entries, read backwards from the last byte:
///                 end offset relative to byte 32 (UInt32), state (UInt32, 1 = written),
///                 timestamp (Double, seconds since 2001-01-01)
///
/// Payload fields used: 2 = kind (1 app, 3 system overlay), 3 = 1 came to front / 0 left,
/// 4 = timestamp (Double, 2001 epoch), 6 = bundle id.
/// Reading requires Full Disk Access; nothing is ever written there.
enum BiomeReader {
    static let streamDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Biome/streams/restricted/App.InFocus")
    static let appleEpoch: Double = 978_307_200

    struct Event: Equatable {
        var t: Double          // unix seconds
        var bundle: String
        var front: Bool        // true = came to front, false = left
        var isApp: Bool        // false for overlays (Control Center, folders)
    }

    enum Status: Equatable {
        case noAccess          // Full Disk Access not granted
        case noDevices         // readable, but nothing synced from an iPhone
        case ok(devices: Int, events: Int, last: Double?)
        case unreadable(String)
    }

    // MARK: SEGB parsing

    static func records(_ d: Data) -> [(t: Double, payload: Data)] {
        guard d.count >= 32, d.prefix(4) == Data("SEGB".utf8) else { return [] }
        let count = Int(d.u32(4))
        guard count > 0, count * 16 < d.count else { return [] }
        var out: [(Double, Data)] = []
        out.reserveCapacity(count)
        var start = 0
        for j in 0..<count {
            let at = d.count - 16 * (j + 1)
            let end = Int(d.u32(at)), state = d.u32(at + 4), t = d.f64(at + 8)
            defer { start = (end + 3) & ~3 }
            guard state == 1, end > start, 32 + end <= d.count, end - start > 8 else { continue }
            out.append((t + appleEpoch, d.subdata(in: (32 + start + 8)..<(32 + end))))
        }
        return out
    }

    /// Minimal protobuf decode: returns the fields this reader needs.
    static func event(_ p: Data) -> Event? {
        var i = p.startIndex
        var kind = 0, front = 0
        var t: Double?
        var bundle: String?
        func varint() -> UInt64? {
            var r: UInt64 = 0, s: UInt64 = 0
            while i < p.endIndex {
                let b = p[i]; i += 1
                r |= UInt64(b & 0x7f) << s
                if b < 0x80 { return r }
                s += 7
                if s > 63 { return nil }
            }
            return nil
        }
        while i < p.endIndex {
            guard let key = varint() else { break }
            let field = key >> 3, wire = key & 7
            switch wire {
            case 0:
                guard let v = varint() else { return nil }
                if field == 2 { kind = Int(v) }
                if field == 3 { front = Int(v) }
            case 1:
                guard i + 8 <= p.endIndex else { return nil }
                if field == 4 { t = p.f64(i - p.startIndex) }
                i += 8
            case 2:
                guard let n = varint(), i + Int(n) <= p.endIndex else { return nil }
                if field == 6 { bundle = String(data: p[i..<(i + Int(n))], encoding: .utf8) }
                i += Int(n)
            case 5:
                i += 4
            default:
                return nil
            }
        }
        guard let t, let bundle, !bundle.isEmpty else { return nil }
        return Event(t: t + appleEpoch, bundle: bundle, front: front == 1, isApp: kind == 1)
    }

    static func events(in data: Data) -> [Event] {
        records(data).compactMap { event($0.payload) }
    }

    // MARK: Sessions

    /// System processes that flash in front for a moment and aren't "using an app".
    static let ignored: Set<String> = [
        "com.apple.ScreenshotServicesService", "com.apple.CoreServicesUIAgent", "com.apple.LocalAuthenticationUIService",
        "com.apple.springboard", "com.apple.SpringBoard", "com.apple.PassbookUIService", "com.apple.siri",
        "com.apple.AuthKitUIService", "com.apple.SharingViewService", "com.apple.AccountAuthenticationDialog",
    ]

    /// Pairs "came to front" with "left". Another app coming to front also ends the current one.
    static func sessions(_ events: [Event], now: Double = Date().timeIntervalSince1970) -> [Segment] {
        var out: [Segment] = []
        var open: (bundle: String, s: Double)?
        func close(_ t: Double) {
            if let o = open {
                let e = min(t, o.s + 2 * Fmt.hour)
                if e > o.s, !ignored.contains(o.bundle) {
                    out.append(Segment(s: o.s, e: e, app: o.bundle, dev: .phone))
                }
                open = nil
            }
        }
        for x in events.sorted(by: { $0.t < $1.t }) where x.isApp {
            if x.front {
                close(x.t)
                open = (x.bundle, x.t)
            } else if open?.bundle == x.bundle {
                close(x.t)
            }
        }
        if let o = open { close(min(now, o.s + 15 * 60)) }
        return out
    }

    // MARK: Loading (cached by file size + modification date)

    private struct Cached { var stamp: String; var events: [Event] }
    nonisolated(unsafe) private static var cache: [String: Cached] = [:]
    private static let lock = NSLock()

    /// Bundle ids only a Mac runs: a remote "device" that has these is another Mac, not an iPhone.
    static let macOnly: Set<String> = ["com.apple.finder", "com.apple.Terminal", "com.apple.systempreferences"]

    static func load() -> (status: Status, events: [Event]) {
        let fm = FileManager.default
        let remote = streamDir.appendingPathComponent("remote")
        guard (try? fm.contentsOfDirectory(atPath: streamDir.path)) != nil else { return (.noAccess, []) }
        let devices = (try? fm.contentsOfDirectory(atPath: remote.path))?.filter { !$0.hasPrefix(".") } ?? []
        var all: [Event] = []
        var phoneDevices = 0
        for dev in devices {
            let dir = remote.appendingPathComponent(dev)
            let files = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.allSatisfy(\.isNumber) }
            var evs: [Event] = []
            for f in files {
                let url = dir.appendingPathComponent(f)
                guard let a = try? fm.attributesOfItem(atPath: url.path) else { continue }
                let stamp = "\(a[.size] ?? 0)|\((a[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)"
                lock.lock()
                let hit = cache[url.path]
                lock.unlock()
                if let hit, hit.stamp == stamp {
                    evs += hit.events
                    continue
                }
                guard let data = try? Data(contentsOf: url) else { continue }
                let e = events(in: data)
                lock.lock()
                cache[url.path] = Cached(stamp: stamp, events: e)
                lock.unlock()
                evs += e
            }
            if evs.contains(where: { macOnly.contains($0.bundle) }) { continue }
            if !evs.isEmpty { phoneDevices += 1 }
            all += evs
        }
        if phoneDevices == 0 { return (.noDevices, []) }
        return (.ok(devices: phoneDevices, events: all.count, last: all.map(\.t).max()), all)
    }
}

extension Data {
    func u32(_ at: Int) -> UInt32 {
        var v: UInt32 = 0
        Swift.withUnsafeMutableBytes(of: &v) { $0.copyBytes(from: self[(startIndex + at)..<(startIndex + at + 4)]) }
        return UInt32(littleEndian: v)
    }

    func f64(_ at: Int) -> Double {
        var v: UInt64 = 0
        Swift.withUnsafeMutableBytes(of: &v) { $0.copyBytes(from: self[(startIndex + at)..<(startIndex + at + 8)]) }
        return Double(bitPattern: UInt64(littleEndian: v))
    }
}
