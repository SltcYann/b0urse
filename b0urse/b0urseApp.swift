import AppKit
import SwiftUI

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidUpdate(_ notification: Notification) {
        NSApp.windows.forEach(configureWindow)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        true
    }

    private func configureWindow(_ window: NSWindow) {
        guard let zoomButton = window.standardWindowButton(.zoomButton) else { return }

        if !zoomButton.isHidden {
            zoomButton.isHidden = true
        }

        if window.styleMask.contains(.resizable) {
            window.styleMask.remove(.resizable)
        }
    }
}

@main
struct b0urseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 700, height: 818)
        }
        .defaultSize(width: 700, height: 818)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
