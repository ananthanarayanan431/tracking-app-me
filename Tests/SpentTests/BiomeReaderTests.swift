import Foundation
import Testing
@testable import Spent

struct BiomeReaderTests {
    /// Builds a protobuf payload like the ones in App.InFocus.
    static func payload(bundle: String, t: Double, front: Bool, kind: Int = 1) -> Data {
        var d = Data()
        d += [0x10, UInt8(kind), 0x18, front ? 1 : 0, 0x21]
        withUnsafeBytes(of: (t - BiomeReader.appleEpoch).bitPattern.littleEndian) { d += $0 }
        d += [0x32, UInt8(bundle.utf8.count)]
        d += Data(bundle.utf8)
        d += [0x68, 0x01]
        return d
    }

    /// Builds a SEGB v2 file from payloads.
    static func segb(_ payloads: [(Data, Double)]) -> Data {
        var body = Data()
        var index: [(UInt32, Double)] = []
        for (p, t) in payloads {
            while body.count % 4 != 0 { body.append(0) }
            body += [0xAA, 0xBB, 0xCC, 0xDD, 0x0A, 0, 0, 0]
            body += p
            index.append((UInt32(body.count), t - BiomeReader.appleEpoch))
        }
        var file = Data("SEGB".utf8)
        withUnsafeBytes(of: UInt32(payloads.count).littleEndian) { file += $0 }
        file += Data(count: 24)
        file += body
        file += Data(count: 64)
        // Index entries are read backwards from the end: first record's entry is last.
        for (end, t) in index.reversed() {
            withUnsafeBytes(of: end.littleEndian) { file += $0 }
            withUnsafeBytes(of: UInt32(1).littleEndian) { file += $0 }
            withUnsafeBytes(of: t.bitPattern.littleEndian) { file += $0 }
        }
        return file
    }

    @Test func parsesRecordsAndBuildsSessions() {
        let t0 = 1_795_000_000.0
        let evs: [(String, Double, Bool, Int)] = [
            ("net.whatsapp.WhatsApp", t0, true, 1),
            ("com.apple.control-center", t0 + 30, true, 3),   // overlay: ignored
            ("net.whatsapp.WhatsApp", t0 + 120, false, 1),
            ("com.google.ios.youtube", t0 + 200, true, 1),
            ("com.google.Gmail", t0 + 500, true, 1),          // switching ends YouTube
            ("com.google.Gmail", t0 + 560, false, 1),
        ]
        let data = Self.segb(evs.map { (Self.payload(bundle: $0.0, t: $0.1, front: $0.2, kind: $0.3), $0.1) })
        let parsed = BiomeReader.events(in: data)
        #expect(parsed.count == 6)
        #expect(parsed[0].bundle == "net.whatsapp.WhatsApp")
        #expect(abs(parsed[0].t - t0) < 0.001)
        let s = BiomeReader.sessions(parsed, now: t0 + 10_000)
        #expect(s.map(\.app) == ["net.whatsapp.WhatsApp", "com.google.ios.youtube", "com.google.Gmail"])
        #expect(s.map { Int($0.duration) } == [120, 300, 60])
        #expect(s.allSatisfy { $0.dev == .phone })
    }

    @Test func rejectsGarbage() {
        #expect(BiomeReader.events(in: Data("nope".utf8)).isEmpty)
        #expect(BiomeReader.events(in: Data("SEGB".utf8) + Data(count: 10)).isEmpty)
    }

    /// Optional check against a real file: SPENT_SEGB_SAMPLE=/path/to/segb scripts/test.sh
    @Test func readsRealSampleIfProvided() throws {
        guard let path = ProcessInfo.processInfo.environment["SPENT_SEGB_SAMPLE"] else { return }
        let evs = BiomeReader.events(in: try Data(contentsOf: URL(fileURLWithPath: path)))
        #expect(evs.count > 100)
        let s = BiomeReader.sessions(evs)
        var by: [String: Double] = [:]
        for g in s { by[g.app, default: 0] += g.duration }
        print("REAL:", evs.count, "events,", s.count, "sessions")
        for (a, v) in by.sorted(by: { $0.value > $1.value }).prefix(6) { print("REAL:", a, Int(v / 60), "min") }
    }
}
