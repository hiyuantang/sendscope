import SwiftUI

struct ContentView: View {
    @Bindable var store: InspectionStore
    @State private var showInspector = false
    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 250)
        } detail: {
            VStack(spacing: 0) {
                header
                CaptureControls(store: store)
                    .padding(.horizontal, 28).padding(.bottom, 24)
                if let message = store.message { banner(message, symbol: "exclamationmark.circle", color: .orange) }
                if let coverage = store.coverage { banner(coverage, symbol: "eye.slash", color: .orange) }
                Divider()
                ActivityView(store: store)
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "leaf").foregroundStyle(.green)
                    Text(store.active ? "Streaming inspection · updates once a second" : "Engine off · no background capture")
                    Spacer()
                    Text("On this Mac only").foregroundStyle(.tertiary)
                }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.vertical, 11)
            }
            .inspector(isPresented: $showInspector) {
                TransferDetailView(transfer: store.selected)
                    .inspectorColumnWidth(min: 240, ideal: 280, max: 340)
            }
        }
        .navigationTitle("SendScope")
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { store.setupShown = true } label: { Label("Inspection Setup", systemImage: "slider.horizontal.3") }
                Button { showInspector.toggle() } label: { Label("Show Details", systemImage: "sidebar.right") }
            }
        }
        .sheet(isPresented: $store.setupShown) { SetupView(store: store) }
        .onChange(of: store.selection) { _, value in if value != nil { showInspector = true } }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 25) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Activity").font(.system(size: 30, weight: .semibold))
                    Text("See what your apps send. Keep the evidence local.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(store.running ? Color.green : Color.secondary.opacity(0.5)).frame(width: 7, height: 7)
                    Text(store.active ? store.phase : "Inspection off").font(.caption.weight(.medium))
                }.padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.quaternary.opacity(0.5), in: Capsule())
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    metric("Outgoing data", value: Format.bytes(store.totalBytes), symbol: "arrow.up.right", caption: "Observed request bodies")
                    metric("Requests with data", value: "\(store.bodyCount)", symbol: "doc.text", caption: "Uploads and API requests")
                    metric("Destinations", value: "\(store.hosts)", symbol: "globe", caption: "Unique observed hosts")
                }
                HStack(spacing: 12) {
                    compactMetric("Outgoing", value: Format.bytes(store.totalBytes), help: "Observed request body bytes")
                    compactMetric("With data", value: "\(store.bodyCount)", help: "Requests with outgoing bodies")
                    compactMetric("Destinations", value: "\(store.hosts)", help: "Unique observed hosts")
                }
            }
        }.padding(28)
    }
    private func metric(_ label: String, value: String, symbol: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label).font(.callout.weight(.medium)).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Image(systemName: symbol).font(.callout).foregroundStyle(.blue.opacity(0.8))
            }
            Text(value).font(.system(size: 28, weight: .medium, design: .rounded)).monospacedDigit()
            Text(caption).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
        }.frame(minWidth: 145, maxWidth: .infinity, alignment: .leading).padding(18)
            .background(.quaternary.opacity(0.20), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.055), lineWidth: 1))
    }
    private func compactMetric(_ label: String, value: String, help: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 24, weight: .medium, design: .rounded)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(.quaternary.opacity(0.20), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.055), lineWidth: 1))
            .help(help)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(help)
            .accessibilityValue(value)
    }
    private func banner(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol).font(.caption).foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(color.opacity(0.07))
    }
}
