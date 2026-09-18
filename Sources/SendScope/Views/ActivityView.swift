import SwiftUI
import SendScopeCore

struct ActivityView: View {
    @Bindable var store: InspectionStore
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(store.section == "uploads" ? "Requests with data" : "Request timeline").font(.headline)
                Text("\(store.filtered.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 3).background(.quaternary.opacity(0.5), in: Capsule())
                Spacer()
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find a destination or filename", text: $store.search)
                    .textFieldStyle(.plain).frame(maxWidth: 210)
                Button { store.clear() } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain).help("Clear retained activity").disabled(store.transfers.isEmpty || store.active)
            }.padding(.horizontal, 28).padding(.vertical, 18)
            if store.filtered.isEmpty {
                GeometryReader { geometry in
                ScrollView {
                VStack(spacing: 10) {
                    if geometry.size.height >= 230 {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(.blue.opacity(0.055)).frame(width: 52, height: 52)
                        Image(systemName: "viewfinder").font(.system(size: 30, weight: .ultraLight)).foregroundStyle(.blue.opacity(0.65))
                        Image(systemName: "arrow.right").font(.system(size: 16, weight: .medium)).foregroundStyle(.blue)
                    }
                    }
                    Text(emptyTitle)
                        .font(.system(size: 20, weight: .semibold))
                    Text(emptyMessage)
                        .font(.callout).multilineTextAlignment(.center).foregroundStyle(.secondary).lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                    if !store.active && !store.certificateTrusted && store.search.isEmpty {
                        Button("Set up HTTPS inspection") { store.setupShown = true }
                            .buttonStyle(.bordered).controlSize(.large).padding(.top, 4)
                    }
                }.padding(.vertical, 12).padding(.horizontal, 16)
                    .frame(maxWidth: .infinity).frame(minHeight: geometry.size.height)
                }
                }
            } else {
                Table(store.filtered, selection: $store.selection) {
                    TableColumn("Destination") { flow in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(flow.host).fontWeight(.medium).lineLimit(1)
                            Text(flow.date, style: .time).font(.caption2).foregroundStyle(.secondary)
                        }.padding(.vertical, 5)
                    }.width(min: 130, ideal: 230)
                    TableColumn("Method", value: \.method).width(60)
                    TableColumn("Body") { flow in Text(Format.bytes(flow.bytes)).monospacedDigit() }.width(80)
                    TableColumn("Result") { flow in
                        if let code = flow.statusCode { Text("HTTP \(code)").foregroundStyle(code >= 400 ? Color.orange : Color.secondary) }
                        else { Text(flow.status).foregroundStyle(.secondary) }
                    }.width(min: 90, ideal: 130)
                }.tableStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
    private var emptyTitle: String {
        if !store.search.isEmpty { return "No matching requests" }
        if store.section == "uploads" && !store.transfers.isEmpty { return "No outgoing bodies observed" }
        return store.active ? "Listening for new requests" : "Your traffic, in focus"
    }
    private var emptyMessage: String {
        if !store.search.isEmpty { return "Try another destination or reported filename." }
        if store.mode == .proxy {
            return "Connect a compatible app to the local proxy.\nOnly requests routed through SendScope appear here."
        }
        return store.active
            ? "Use the selected app to make a new connection.\nOnly activity routed through the inspector appears here."
            : "Select an app above to see its outgoing requests,\ntransfer sizes, and any reported filenames."
    }
}
