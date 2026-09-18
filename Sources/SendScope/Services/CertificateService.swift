import AppKit
import Security
import CryptoKit

@MainActor enum CertificateService {
    static func certificate() -> SecCertificate? {
        guard let pem = try? String(contentsOf: EngineService.certificate, encoding: .utf8) else { return nil }
        let base64 = pem.components(separatedBy: .newlines).filter { !$0.hasPrefix("---") }.joined()
        guard let data = Data(base64Encoded: base64) else { return nil }
        return SecCertificateCreateWithData(nil, data as CFData)
    }
    static var fingerprint: String {
        guard let cert = certificate() else { return "Not generated yet" }
        return SHA256.hash(data: SecCertificateCopyData(cert) as Data).map { String(format: "%02X", $0) }.joined(separator: ":")
    }
    static var isTrusted: Bool {
        guard let cert = certificate() else { return false }
        var trust: SecTrust?
        guard SecTrustCreateWithCertificates(cert, SecPolicyCreateBasicX509(), &trust) == errSecSuccess,
              let trust else { return false }
        SecTrustSetNetworkFetchAllowed(trust, false)
        return SecTrustEvaluateWithError(trust, nil)
    }
    static func openCertificate() {
        guard let cert = certificate() else { return }
        let url = EngineService.support.appendingPathComponent("SendScope-Local-CA.cer")
        do {
            try (SecCertificateCopyData(cert) as Data).write(to: url, options: .atomic)
            NSWorkspace.shared.open(url)
        } catch { /* The setup sheet retains the certificate status for retry. */ }
    }
}
