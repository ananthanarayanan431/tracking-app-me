import AppKit
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
    }
}

/// Keeps Spent running (and tracking) after the window closes; flushes data on quit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor lazy var model = AppModel()

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
