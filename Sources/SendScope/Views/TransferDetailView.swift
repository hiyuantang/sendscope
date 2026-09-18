import SwiftUI
import SendScopeCore

struct TransferDetailView: View {
    let transfer: Transfer?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Label("Request details", systemImage: "info.circle").font(.headline)
                if let flow = transfer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(flow.host).font(.title3.weight(.semibold)).textSelection(.enabled)
                        Label(flow.tls ? "HTTPS decrypted" : "Plain HTTP", systemImage: flow.tls ? "lock.open" : "network")
                            .font(.caption).foregroundStyle(.blue)
                    }
                    Divider()
                    detail("Capture selection", flow.source ?? "Unknown")
                    detail("Observed request body", Format.bytes(flow.bytes))
                    detail("Observed response body", Format.bytes(flow.responseBytes))
                    detail("Content type", flow.contentType.isEmpty ? "Not declared" : flow.contentType)
                    detail("Result", flow.statusCode.map { "HTTP \($0) · \(flow.status)" } ?? flow.status)
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("File evidence").font(.subheadline.weight(.semibold))
                        if flow.files.isEmpty {
                            Text("No filename observed").foregroundStyle(.secondary)
                            Text("This may be API data, an archive, or an upload without a filename. Encrypted archives remain opaque.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            ForEach(flow.files, id: \.self) { name in
                                Label(name, systemImage: "doc").textSelection(.enabled)
                            }
                            Text("Names reported by the app in multipart headers. They do not establish the original local path. Only the first 16 KB is scanned.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    Text("Observed bytes passed through the inspector. A server response does not prove that a file was stored. URLs, credentials, and body contents are not retained.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 30, weight: .light)).foregroundStyle(.tertiary).padding(.top, 30)
                    Text("Select a request").font(.subheadline.weight(.medium))
                    Text("See the destination, transfer size, and exactly what evidence is available.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout).textSelection(.enabled)
        }
    }
}
