import SwiftUI
import SendScopeCore

struct CaptureControls: View {
    @Bindable var store: InspectionStore
    @State private var apps: [NSRunningApplication] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: "scope").foregroundStyle(.blue)
                Text("Inspection scope").font(.callout.weight(.semibold))
                Spacer()
                if !store.certificateTrusted {
                    Button("HTTPS setup") { store.setupShown = true }.buttonStyle(.link).font(.caption)
                } else {
                    Label("HTTPS ready", systemImage: "checkmark.seal").font(.caption).foregroundStyle(.secondary)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    modePicker
                    targetControls
                    inspectionButton
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        modePicker
                        Spacer()
                        inspectionButton
                    }
                    targetControls
                }
            }.controlSize(.large)
            Text(store.mode == .process
                 ? "Only the named process is selected. Helpers and existing connections may need a new session."
                 : "Point a compatible app at this HTTP/HTTPS proxy. System proxy settings are not changed.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(18)
            .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.075), lineWidth: 1))
        .onAppear { loadApps() }
    }
    private var modePicker: some View {
        Picker("Capture", selection: $store.mode) {
            ForEach(CaptureMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.labelsHidden().frame(width: 150).disabled(store.active)
    }
    @ViewBuilder private var targetControls: some View {
        if store.mode == .process {
            HStack(spacing: 10) {
                TextField("App or process name", text: $store.target)
                    .textFieldStyle(.roundedBorder).frame(minWidth: 180).disabled(store.active)
                Menu {
                    ForEach(apps, id: \.processIdentifier) { app in
                        Button("\(app.localizedName ?? "App") · \(app.processIdentifier)") { store.target = String(app.processIdentifier) }
                    }
                    Divider()
                    Button("Refresh apps") { loadApps() }
                } label: { Label("Apps", systemImage: "app") }
                .frame(width: 95).disabled(store.active)
                .help("Choose a running app process. Helper processes may require a separate capture.")
            }
        } else {
            Text("127.0.0.1:8877").font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
                .fixedSize().frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var inspectionButton: some View {
        Button {
            if store.active { store.stop() }
            else if store.mode == .process && !store.certificateTrusted { store.setupShown = true }
            else { store.start() }
        } label: {
            Label(store.active ? "Stop" : "Inspect", systemImage: store.active ? "stop.fill" : "play.fill")
                .frame(minWidth: 110)
        }.buttonStyle(.borderedProminent).tint(store.active ? .secondary : .blue)
            .disabled(store.phase == "Stopping")
    }
    private func loadApps() {
        apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}
