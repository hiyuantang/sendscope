import SwiftUI

struct SetupView: View {
    @Bindable var store: InspectionStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Inspect HTTPS, locally").font(.title2.weight(.semibold))
                    Text("A one-time setup, with you in control.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            step("1", "Inspection engine", store.engineInstalled ? "Installed · mitmproxy" : "Engine missing. Run script/setup_engine.sh, then rebuild.", ready: store.engineInstalled)
            step("2", "Create a local certificate", "A unique inspection key stays on this Mac. It is never uploaded.", ready: store.certificateExists)
            Button(store.preparingCertificate ? "Preparing…" : "Generate certificate") { store.start(prepareOnly: true) }
                .disabled(store.active || store.certificateExists || !store.engineInstalled)
                .padding(.leading, 40)
            step("3", "Trust the inspection certificate", "Open the certificate in Keychain Access. Add it to your login keychain, open its Trust section, and allow SSL trust. Its displayed name is mitmproxy.", ready: store.certificateTrusted)
            HStack {
                Button("Open certificate…") { CertificateService.openCertificate() }.disabled(!store.certificateExists)
                Button("Check trust") { store.refreshCertificate() }
                if store.certificateTrusted { Label("Trusted", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
            }.padding(.leading, 40)
            if store.certificateExists {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Certificate SHA-256").font(.caption.weight(.medium))
                    Text(CertificateService.fingerprint).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                }.padding(12).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            }
            Divider()
            Text("HTTPS inspection can read sensitive data while it passes through. SendScope records metadata only. Select the processes you want to inspect; pinned certificates and app-level encryption may limit visibility. macOS may also ask you to approve the capture extension when you first start.")
                .font(.callout).foregroundStyle(.secondary)
            if let message = store.message { Text(message).font(.caption).foregroundStyle(.orange) }
        }.padding(28).frame(width: 580)
            .onAppear { store.refreshCertificate() }
    }
    private func step(_ number: String, _ title: String, _ subtitle: String, ready: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(ready ? Color.green.opacity(0.12) : Color.blue.opacity(0.1)).frame(width: 28, height: 28)
                if ready { Image(systemName: "checkmark").foregroundStyle(.green) }
                else { Text(number).foregroundStyle(.blue) }
            }.font(.caption.weight(.semibold))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
