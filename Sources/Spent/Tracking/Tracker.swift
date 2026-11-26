import AppKit
import CoreGraphics

/// Samples the frontmost app (and browser tab) every 5 seconds and writes segments to
/// ~/.spent/data/YYYY-MM-DD.tsv. A segment is closed when the app/site changes, after 60 s
/// (so a crash never loses much), or when there's a gap (sleep, idle, pause).
final class Tracker {
    static let interval: TimeInterval = 5

    /// Called on the main thread after every sample with the segment being recorded (nil when idle/paused).
    var onSample: ((Segment?) -> Void)?

    private let queue = DispatchQueue(label: "spent.tracker", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var curKey = ""
    private var cur: Segment?
    private var segStart: Double = 0
    private var last: Double = 0
    private(set) var ownsLock = false

    var isPaused: Bool { Storage.exists("paused") }

    var idleLimit: Double {
        Double(Storage.readText("idle")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 180
    }

    func start() {
        Storage.ensureDirs()
        ownsLock = acquireLock()
        observeFrontmost()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 1, repeating: Self.interval, leeway: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    /// Flushes the open segment. Call on quit.
    func stop() {
        queue.sync {
            emit(until: last)
            curKey = ""
            cur = nil
            if ownsLock {
                Storage.remove("tracker.pid")
                Storage.writeText("current.tsv", "")
            }
        }
        timer?.cancel()
        timer = nil
    }

    /// Another tracker (e.g. an older script install) may already be recording; never double-count.
    private func acquireLock() -> Bool {
        let me = ProcessInfo.processInfo.processIdentifier
        if let txt = Storage.readText("tracker.pid"), let pid = Int32(txt.trimmingCharacters(in: .whitespacesAndNewlines)),
           pid != me, kill(pid, 0) == 0 {
            return false
        }
        Storage.writeText("tracker.pid", "\(me)")
        return true
    }

    static func idleSeconds() -> Double {
        let any = CGEventType(rawValue: ~0)!
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: any)
    }

    // The frontmost app is tracked from workspace notifications on the main thread, so the
    // sampling queue never has to block on main (which would deadlock with stop()).
    private let frontLock = NSLock()
    private var frontName: String?
    private var activationObserver: NSObjectProtocol?

    private func observeFrontmost() {
        setFront(NSWorkspace.shared.frontmostApplication?.localizedName)
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.setFront(app?.localizedName)
        }
    }

    private func setFront(_ name: String?) {
        frontLock.lock(); frontName = name; frontLock.unlock()
    }

    private func frontApp() -> String? {
        frontLock.lock(); let name = frontName; frontLock.unlock()
        guard let n = name, !n.isEmpty, n != "loginwindow", n != "ScreenSaverEngine" else { return nil }
        return n
    }

    private func tick() {
        if !ownsLock {
            // Someone else records; just surface what they're writing.
            ownsLock = acquireLock()
            if !ownsLock {
                let seg = Self.readCurrentFile()
                DispatchQueue.main.async { self.onSample?(seg) }
                return
            }
        }

        let now = Date().timeIntervalSince1970.rounded()
        var seg: Segment?
        if !isPaused, Self.idleSeconds() < idleLimit, let app = frontApp() {
            var g = Segment(s: now, e: now, app: app)
            if BrowserProbe.supports(app), let r = BrowserProbe.probe(app: app) {
                g.dom = r.domain
                g.title = r.title
                g.prof = r.profile
            }
            seg = g
        }
        let key = seg.map { Storage.line(Segment(s: 0, e: 0, app: $0.app, dom: $0.dom, title: $0.title, prof: $0.prof)) } ?? ""

        if key != curKey || now - segStart >= 60 || now - last > 30 {
            emit(until: now - last > 30 ? last + Self.interval : now)
            curKey = key
            cur = seg
            segStart = now
        }
        last = now

        var live: Segment?
        if var c = cur {
            c.s = segStart
            c.e = now
            live = c
            Storage.writeText("current.tsv", Storage.line(c))
        } else {
            Storage.writeText("current.tsv", "")
        }
        DispatchQueue.main.async { self.onSample?(live) }
    }

    private func emit(until end: Double) {
        guard var c = cur, !curKey.isEmpty, end > segStart else { return }
        c.s = segStart
        c.e = end
        Storage.append(c)
    }

    /// Reads the live segment written by whichever tracker holds the lock.
    static func readCurrentFile() -> Segment? {
        let url = Storage.url("current.tsv")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let mtime = attrs[.modificationDate] as? Date, Date().timeIntervalSince(mtime) < 20,
              let text = Storage.readText("current.tsv"), var g = Storage.parseTSV(text).first ?? Self.parseOpen(text)
        else { return nil }
        g.e += 2
        return g
    }

    /// current.tsv may hold a zero-length segment right after a switch.
    private static func parseOpen(_ text: String) -> Segment? {
        let a = text.trimmingCharacters(in: .newlines).split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard a.count >= 3, !a[2].isEmpty, let s = Double(a[0]), let e = Double(a[1]) else { return nil }
        return Segment(s: s, e: e, app: a[2], dom: a.count > 3 ? a[3] : "", title: a.count > 4 ? a[4] : "", prof: a.count > 5 ? a[5] : "")
    }
}
