//
//  b0urseApp.swift
//  b0urse
//
//  Created by Yann on 15/08/2026.
//

import AppKit
import SwiftUI

@main
struct b0urseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 520, minHeight: 640)
        }
        .defaultSize(width: 580, height: 720)
        .windowResizability(.contentMinSize)
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
