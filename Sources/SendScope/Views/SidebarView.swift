import SwiftUI

struct SidebarView: View {
    @Bindable var store: InspectionStore
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SendScope").font(.headline)
                    Text("Network inspector").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(.horizontal, 15).padding(.top, 20).padding(.bottom, 20)
            List(selection: $store.section) {
                Section("Inspect") {
                    Label("All requests", systemImage: "waveform.path").tag("activity")
                    Label("Requests with data", systemImage: "arrow.up.doc").tag("uploads")
                }
            }.listStyle(.sidebar)
            VStack(alignment: .leading, spacing: 10) {
                Label("Private by design", systemImage: "lock.shield").font(.caption.weight(.medium))
                Text("Bodies stay in transit. Activity stays on this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Set up inspection") { store.setupShown = true }
                    .buttonStyle(.link).font(.caption)
                HStack {
                    SettingsLink { Label("Settings", systemImage: "gearshape") }
                        .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("0.1").font(.caption2).foregroundStyle(.tertiary)
                }.padding(.top, 8)
            }.padding(18)
        }
    }
}
