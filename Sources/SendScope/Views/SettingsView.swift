import SwiftUI

struct SettingsView: View {
    @Bindable var store: InspectionStore
    var body: some View {
        Form {
            Section("Energy") {
                Toggle("Pause inspection in Low Power Mode", isOn: $store.pauseForLowPower)
                Text("Inspection always stops if macOS reports serious or critical thermal pressure. The engine is off when you stop inspection.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Toggle("Keep activity between launches", isOn: $store.preserveHistory)
                Text("Optional local history contains up to 500 destinations, byte counts, timestamps, and reported filenames. Bodies, credentials, and full URLs are never saved.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Clear activity") { store.clear() }.disabled(store.active)
            }
            Section("Coverage") {
                Text("HTTP and HTTPS request bodies routed through the inspector are counted. This is not a system-wide firewall. Other protocols, WebSocket payloads, and processes outside your selection are not attributed as file uploads.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).frame(width: 510, height: 410)
            .onChange(of: store.preserveHistory) { _, _ in store.settingsChanged() }
            .onChange(of: store.pauseForLowPower) { _, _ in store.settingsChanged() }
    }
}
