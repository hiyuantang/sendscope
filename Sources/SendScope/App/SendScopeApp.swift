import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        InspectionStore.shared.shutdown()
        return .terminateNow
    }
}

@main struct SendScopeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = InspectionStore.shared
    var body: some Scene {
        WindowGroup("SendScope", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 650)
                .tint(.blue)
        }
        .defaultSize(width: 1180, height: 780)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(after: .newItem) {
                Button(store.active ? "Stop Inspection" : "Start Inspection") {
                    if store.active { store.stop() } else { store.start() }
                }.keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }
        Settings { SettingsView(store: store) }
        MenuBarExtra("SendScope", systemImage: store.running ? "arrow.up.right.circle.fill" : "viewfinder") {
            Text(store.phase)
            Button("Open SendScope") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
            }
            if store.active { Button("Stop Inspection") { store.stop() } }
            Divider()
            Button("Quit SendScope") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
    }
}
