import Foundation

/// Reads off the main thread. A bounded queue prevents bursts from overwhelming SwiftUI.
final class EventInbox: @unchecked Sendable {
    private let lock = NSLock()
    private var remainder = Data()
    private var events: [Data] = []
    private var dropped = 0
    func append(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        remainder.append(data)
        while let newline = remainder.firstIndex(of: 10) {
            let line = remainder.prefix(upTo: newline)
            let prefix = Data("SENDSCOPE ".utf8)
            if line.starts(with: prefix) {
                if events.count < 1000 { events.append(Data(line.dropFirst(prefix.count))) }
                else { dropped += 1 }
            }
            remainder.removeSubrange(...newline)
        }
        if remainder.count > 128 * 1024 { remainder.removeAll(); dropped += 1 }
    }
    func drain() -> ([Data], Int) {
        lock.lock(); defer { lock.unlock() }
        let result = (events, dropped)
        events.removeAll(keepingCapacity: true); dropped = 0
        return result
    }
}

@MainActor final class EngineService {
    private var process: Process?
    private var stdout: Pipe?
    private var stderr: Pipe?
    let inbox = EventInbox()
    var onExit: ((Int32) -> Void)?
    var isRunning: Bool { process?.isRunning == true }

    static var support: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SendScope", isDirectory: true)
    }
    static var certificate: URL { support.appendingPathComponent("certificates/mitmproxy-ca-cert.pem") }
    static var enginePath: String? {
        if let resource = Bundle.main.url(forResource: "engine-path", withExtension: "txt"),
           let path = try? String(contentsOf: resource, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           FileManager.default.isExecutableFile(atPath: path) { return path }
        return ["/opt/homebrew/bin/mitmdump", "/usr/local/bin/mitmdump"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func start(target: String, manual: Bool) throws {
        guard process == nil else { return }
        guard let executable = Self.enginePath,
              let addon = Bundle.main.url(forResource: "sendscope_addon", withExtension: "py") else {
            throw NSError(domain: "SendScope", code: 1, userInfo: [NSLocalizedDescriptionKey: "Inspection engine is missing. Run script/setup_engine.sh, then rebuild SendScope."])
        }
        let conf = Self.support.appendingPathComponent("certificates", isDirectory: true)
        try FileManager.default.createDirectory(at: conf, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        _ = inbox.drain()
        let child = Process(), output = Pipe(), errors = Pipe()
        child.executableURL = URL(fileURLWithPath: executable)
        child.arguments = ["--mode", manual ? "regular@127.0.0.1:8877" : "local:\(target)",
                           "--set", "confdir=\(conf.path)", "--set", "flow_detail=0",
                           "--set", "termlog_verbosity=error", "--set", "connection_strategy=lazy",
                           "--set", "ssl_insecure=false", "-s", addon.path, "-q"]
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        // Ignore externally inherited proxy settings for the inspector itself.
        for key in ["HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"] { environment.removeValue(forKey: key) }
        child.environment = environment
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = output; child.standardError = errors
        let inbox = self.inbox
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { inbox.append(data) }
        }
        // Drain diagnostic output but never persist potentially sensitive strings.
        errors.fileHandleForReading.readabilityHandler = { handle in _ = handle.availableData }
        child.terminationHandler = { [weak self] child in
            Task { @MainActor in
                guard let self, self.process === child else { return }
                self.stdout?.fileHandleForReading.readabilityHandler = nil
                self.stderr?.fileHandleForReading.readabilityHandler = nil
                self.process = nil; self.stdout = nil; self.stderr = nil
                self.onExit?(child.terminationStatus)
            }
        }
        try child.run()
        process = child; stdout = output; stderr = errors
    }

    func stop() {
        guard let process, process.isRunning else { return }
        process.terminate()
        // SIGKILL only our own retained child if graceful shutdown stalls.
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }
}
