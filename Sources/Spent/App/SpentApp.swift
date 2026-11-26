import AadatKit
import AppKit
import DeskBreakKit
import SwiftUI

@main
struct SpentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("Spent", id: "main") {
            RootView()
                .environment(delegate.model)
                .environment(\.skin, Skin.from(settings: delegate.model.settings))
                .preferredColorScheme(Skin.from(settings: delegate.model.settings).light ? .light : .dark)
                .frame(minWidth: 860, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1320, height: 920)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Tracking") {
                Button(delegate.model.paused ? "Resume tracking" : "Pause tracking") { delegate.model.togglePause() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Button(delegate.model.focus.running ? "Pause focus" : "Start focus") { delegate.model.focusToggle() }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                Divider()
                Button("Refresh") { delegate.model.loadBase() }.keyboardShortcut("r")
            }
        }

        MenuBarExtra {
            MenuBarContent()
                .environment(delegate.model)
        } label: {
            MenuBarLabel(model: delegate.model)
        }

        // DeskBreak and Aadat keep their own menu bar icons and panels while they run inside Spent.
        MenuBarExtra(isInserted: .constant(delegate.model.companions.deskbreak != nil)) {
            if let c = delegate.model.companions.deskbreak {
                DeskBreakKit.MenuContentView(controller: c, hostedInSpent: true)
            }
        } label: {
            if let c = delegate.model.companions.deskbreak {
                DeskBreakMenuIcon(controller: c)
            } else {
                Icon(.deskbreak, size: 16)
            }
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra(isInserted: .constant(delegate.model.companions.aadat != nil)) {
            if let c = delegate.model.companions.aadat {
                AadatKit.MenuContentView(controller: c, hostedInSpent: true)
            }
        } label: {
            if let c = delegate.model.companions.aadat {
                AadatMenuIcon(controller: c)
            } else {
                Icon(.aadat, size: 16)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Keeps Spent running (and tracking) after the window closes; flushes data on quit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor lazy var model = AppModel()

    /// Command-line switches for setup without the UI:
    ///   Spent --enable-login-item / --disable-login-item   (prints the result and exits)
    func applicationWillFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        guard let flag = args.first(where: { $0 == "--enable-login-item" || $0 == "--disable-login-item" }) else { return }
        let on = flag == "--enable-login-item"
        let err = LoginItem.set(on)
        print(err ?? "Start at login: \(LoginItem.enabled ? "on" : "off")")
        exit(err == nil ? 0 : 1)
    }

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        Notifier.shared.setUp()
        model.start()
        IconProvider.shared.allowNetwork = model.settings.privacy.logos
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @MainActor
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { MainWindow.show() }
        return true
    }

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
    }
}

/// DeskBreak's menu bar icon, drawn with Spent's Icons8 set but keeping DeskBreak's meaning:
/// a blue filled drop while counting, a moon while away or locked, pause while paused.
struct DeskBreakMenuIcon: View {
    @ObservedObject var controller: DeskBreakKit.AppController

    var body: some View {
        Group {
            if controller.isPaused {
                Icon(.pause, size: 16)
            } else if controller.activity != .active {
                Icon(.moon, size: 16)
            } else if let blue = AppIcon.deskbreak.tinted(.systemBlue, filled: true, points: 16) {
                Image(nsImage: blue)
            } else {
                Icon(.deskbreak, filled: true, size: 16)
            }
        }
        .accessibilityLabel(controller.isPaused ? "DeskBreak, paused" : controller.activity == .active ? "DeskBreak" : "DeskBreak, away")
    }
}

/// Aadat's menu bar item: the to-do icon (a check once everything is done) and "done/total".
struct AadatMenuIcon: View {
    @ObservedObject var controller: AadatKit.BoardController

    var body: some View {
        let b = controller.board
        let allDone = b.totalCount > 0 && b.doneCount == b.totalCount
        HStack(spacing: 3) {
            Icon(allDone ? .check : .aadat, size: 16)
            if b.totalCount > 0 { Text("\(b.doneCount)/\(b.totalCount)").monospacedDigit() }
        }
        .accessibilityLabel("Aadat, \(b.doneCount) of \(b.totalCount) tasks done today")
    }
}
