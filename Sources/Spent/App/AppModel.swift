import AppKit
import Observation
import SwiftUI

/// The app's single source of truth: persisted state from ~/.spent, the live tracker, and
/// the navigation state the views read. Feature logic lives in AppModel+*.swift.
@MainActor
@Observable
final class AppModel {
    // Navigation
    var tab: Tab = .overview
    var period: PeriodView = .day
    var anchor = Date()
    var dev: DeviceFilter = .all
    var insightsWindow = 30
    var query = ""
    var detail: DetailTarget?
    var habitEntryTarget: HabitEntryTarget?
    var awayPrompt: Gap?
    var campaignFormOpen = false
    var editingCampaign: String?
    var editingHabit: String?
    var toastText: String?

    // Persisted state
    var settings = Settings()
    var focus = FocusState()
    var focusLog: [FocusLog] = []
    var hlog: [String: [String: HabitEntry]] = [:]
    var clog: [String: [String: CampaignMark]] = [:]
    var away: [AwayEntry] = []
    var manual: [ManualPhone] = []
    var aiTexts: [String: String] = [:]
    var phoneCustomPath = ""

    // Live state
    var current: Segment?
    var paused = false
    var daysAvail: Set<String> = []
    var phone = PhoneImport.Result()
    var notificationsAllowed = false
    var shortcutOn = false
    var pendingGap: Gap?
    /// Bumped whenever on-disk tracking data changes so views recompute.
    var revision = 0

    let classifier = Classifier()
    let tracker = Tracker()
    @ObservationIgnored var cache = SummaryCache()
    @ObservationIgnored var limitFired: [String: [String: LimitFire]] = [:]
    @ObservationIgnored var remindersFired: [String: [String: Int]] = [:]
    @ObservationIgnored var awayPrompted: Set<Double> = []
    @ObservationIgnored var lastNudge: Double = 0
    @ObservationIgnored private var timers: [Timer] = []
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var hadCurrent = false
    @ObservationIgnored var todayCache: (key: String, rev: Int, mac: Summary)?

    init() {
        Storage.ensureDirs()
        load()
    }

    // MARK: Lifecycle

    func load() {
        settings = Storage.read("settings.json", as: Settings.self) ?? Settings()
        if settings.acts == nil { settings.acts = Self.defaultActivities(habits: settings.habits) }
        classifier.overrides = settings.overrides
        cache = Storage.read("summary-cache.json", as: SummaryCache.self) ?? SummaryCache()
        if cache.v != SummaryCache.version || cache.h != classifier.overridesHash {
            cache = SummaryCache(h: classifier.overridesHash)
        }
        focusLog = Storage.read("focus.json", as: [FocusLog].self) ?? []
        hlog = Storage.read("habits.json", as: [String: [String: HabitEntry]].self) ?? [:]
        clog = Storage.read("campaigns.json", as: [String: [String: CampaignMark]].self) ?? [:]
        away = Storage.read("away.json", as: [AwayEntry].self) ?? []
        manual = Storage.read("phone-manual.json", as: [ManualPhone].self) ?? []
        aiTexts = Storage.read("ai.json", as: [String: String].self) ?? [:]
        limitFired = Storage.read("alerts.json", as: [String: [String: LimitFire]].self) ?? [:]
        remindersFired = Storage.read("reminders.json", as: [String: [String: Int]].self) ?? [:]
        phoneCustomPath = Storage.readText("phone-path")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let fs = Storage.read("focus-state.json", as: FocusState.self) {
            focus = fs
        }
        if let idle = settings.idleSeconds { Storage.writeText("idle", "\(idle)") }
        loadBase()
    }

    func start() {
        tracker.onSample = { [weak self] seg in
            MainActor.assumeIsolated { self?.handleSample(seg) }
        }
        tracker.start()
        Theme.applyDockIcon(settings: settings)
        if focus.running, Date().timeIntervalSince1970 >= focus.endsAt { focusEnd(done: true) }
        Task { await Notifier.shared.refreshState(); notificationsAllowed = Notifier.shared.allowed }
        if HotKey.shared.isEnabledInSettings { enableShortcut(announce: false) }
        checkAway()

        timers.append(Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.everySecond() }
        })
        timers.append(Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.every15s() }
        })
    }

    func shutdown() {
        tracker.stop()
        saveCache()
    }

    /// Re-reads tracking files from disk: available days, iPhone log, pause flag.
    func loadBase() {
        daysAvail = Storage.availableDays()
        paused = Storage.exists("paused")
        phone = PhoneImport.load(custom: phoneCustomPath)
        revision += 1
    }

    private func handleSample(_ seg: Segment?) {
        current = seg
        paused = tracker.isPaused
        if !hadCurrent, seg != nil {
            // Just came back: give the tracker a moment to close the gap, then ask.
            Task { try? await Task.sleep(for: .seconds(2.5)); checkAway() }
        }
        hadCurrent = seg != nil
        focusNudgeIfNeeded()
    }

    private func everySecond() {
        if focus.running, Date().timeIntervalSince1970 >= focus.endsAt { focusEnd(done: true) }
    }

    private func every15s() {
        loadBase()
        checkLimits()
        checkReminders()
        checkAway()
        saveCache()
    }

    // MARK: Persistence

    func saveSettings() { Storage.write("settings.json", settings) }
    func saveFocusState() { Storage.write("focus-state.json", focus) }

    func saveCache() {
        if cache.dirty {
            cache.dirty = false
            Storage.write("summary-cache.json", cache)
        }
    }

    func overridesChanged() {
        classifier.overrides = settings.overrides
        cache = SummaryCache(h: classifier.overridesHash)
        cache.dirty = true
        todayCache = nil
        saveSettings()
        revision += 1
    }

    // MARK: Toast

    func toast(_ text: String) {
        toastText = text
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            if !Task.isCancelled { toastText = nil }
        }
    }

    // MARK: Notifications

    func notify(_ body: String) {
        if notificationsAllowed {
            Notifier.shared.post(body)
        } else {
            toast(body)
        }
    }

    func enableNotifications() async {
        notificationsAllowed = await Notifier.shared.requestPermission()
        if notificationsAllowed { notify("Notifications are on. Spent will tell you when you near a limit.") }
    }

    // MARK: Tracking controls

    func togglePause() {
        if paused { Storage.remove("paused") } else { Storage.writeText("paused", "1") }
        paused.toggle()
        toast(paused ? "Tracking paused" : "Tracking resumed")
    }

    var idleSeconds: Int {
        get { settings.idleSeconds ?? 180 }
        set {
            settings.idleSeconds = newValue
            Storage.writeText("idle", "\(newValue)")
            saveSettings()
        }
    }
}

/// When a limit alert last fired today.
struct LimitFire: Codable {
    var w: Int?
    var r: Double?
}

/// Per-day summaries for days before yesterday never change, so they're cached on disk.
struct SummaryCache: Codable {
    static let version = 6
    var v = SummaryCache.version
    var h = ""
    var days: [String: Summary] = [:]
    var dirty = false

    enum CodingKeys: String, CodingKey { case v, h, days }

    init(h: String = "") { self.h = h }
}

enum DetailTarget: Hashable, Identifiable {
    case app(String), site(String), cat(String), prof(String)
    var id: String { key }
    var key: String {
        switch self {
        case .app(let n): return "app:" + n
        case .site(let n): return "site:" + n
        case .cat(let n): return "cat:" + n
        case .prof(let n): return "prof:" + n
        }
    }
}

struct HabitEntryTarget: Hashable, Identifiable {
    var habitID: String
    var key: String
    var id: String { habitID + "|" + key }
}
