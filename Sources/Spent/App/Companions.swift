import AadatKit
import AppKit
import DeskBreakKit
import Observation

/// Runs DeskBreak (water / walk reminders) and Aadat (today / tomorrow tasks) inside Spent.
///
/// Their own code does the work, on their own data files, so history carries over. Only one copy
/// of each may run at a time (two copies would remind twice and overwrite each other's files),
/// so Spent starts its copy only after the standalone app has quit, and quits the standalone app
/// again if it is relaunched later (for example by its own login item).
@MainActor
@Observable
final class Companions {
    enum Kind: String, CaseIterable, Identifiable {
        case deskbreak, aadat
        var id: String { rawValue }
        var name: String { self == .deskbreak ? "DeskBreak" : "Aadat" }
        var bundleID: String {
            self == .deskbreak ? "io.github.ananthanarayanan431.deskbreak" : "io.github.ananthanarayanan431.aadat"
        }
        var enabledKey: String { "companion.\(rawValue).enabled" }
    }

    private(set) var deskbreak: DeskBreakKit.AppController?
    private(set) var aadat: AadatKit.BoardController?
    /// Kinds currently waiting for the standalone app to quit.
    private(set) var switching: Set<Kind> = []
    var onMessage: ((String) -> Void)?

    @ObservationIgnored private var launchObserver: NSObjectProtocol?

    func isEnabled(_ k: Kind) -> Bool { UserDefaults.standard.bool(forKey: k.enabledKey) }
    func isRunningHere(_ k: Kind) -> Bool { k == .deskbreak ? deskbreak != nil : aadat != nil }

    func standaloneApp(_ k: Kind) -> NSRunningApplication? {
        let me = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: k.bundleID)
            .first { $0.processIdentifier != me && !$0.isTerminated }
    }

    func isInstalled(_ k: Kind) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: k.bundleID) != nil
    }

    /// Called at launch: resumes whatever was switched on before.
    func start() {
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.standaloneLaunched(app) }
        }
        for k in Kind.allCases where isEnabled(k) { Task { await takeOver(k, announce: false) } }
    }

    func shutdown() {
        deskbreak?.shutdown()
        if let launchObserver { NSWorkspace.shared.notificationCenter.removeObserver(launchObserver) }
    }

    /// Quits the standalone app (it saves its state on quit), then runs it inside Spent.
    func takeOver(_ k: Kind, announce: Bool = true) async {
        guard !isRunningHere(k), !switching.contains(k) else { return }
        UserDefaults.standard.set(true, forKey: k.enabledKey)
        switching.insert(k)
        defer { switching.remove(k) }
        if let app = standaloneApp(k) {
            app.terminate()
            for _ in 0..<50 where !app.isTerminated { try? await Task.sleep(for: .milliseconds(100)) }
            if !app.isTerminated {
                UserDefaults.standard.set(false, forKey: k.enabledKey)
                onMessage?("\(k.name) didn’t quit. Quit it from its menu bar icon, then try again.")
                return
            }
        }
        switch k {
        case .deskbreak:
            let c = DeskBreakKit.AppController()
            c.start()
            deskbreak = c
        case .aadat:
            let c = AadatKit.BoardController()
            c.start()
            aadat = c
        }
        if announce { onMessage?("\(k.name) now runs inside Spent") }
    }

    /// Stops Spent's copy so the standalone app can be used again.
    func handBack(_ k: Kind) {
        UserDefaults.standard.set(false, forKey: k.enabledKey)
        switch k {
        case .deskbreak:
            deskbreak?.shutdown()
            deskbreak = nil
        case .aadat:
            aadat = nil
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: k.bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        onMessage?("\(k.name) runs on its own again")
    }

    private func standaloneLaunched(_ app: NSRunningApplication?) {
        guard let app, let id = app.bundleIdentifier,
              let k = Kind.allCases.first(where: { $0.bundleID == id }), isRunningHere(k) else { return }
        app.terminate()
        onMessage?("\(k.name) is already running inside Spent, so its separate app was closed")
    }
}
