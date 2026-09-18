import SwiftUI
import Observation
import SendScopeCore

@MainActor @Observable final class InspectionStore {
    static let shared = InspectionStore()
    var mode: CaptureMode = .process
    var target = ""
    var phase = "Stopped"
    var running = false
    var starting = false
    var preparingCertificate = false
    var certificateExists = false
    var certificateTrusted = false
    var message: String?
    var coverage: String?
    var transfers: [Transfer] = []
    var selection: String?
    var search = ""
    var section = "activity"
    var setupShown = false
    var preserveHistory = UserDefaults.standard.bool(forKey: "preserveHistory")
    var pauseForLowPower = UserDefaults.standard.object(forKey: "pauseForLowPower") as? Bool ?? true
    var elapsed: TimeInterval = 0
    var sessionStarted: Date?
    private var ledger = TransferLedger()
    private let engine = EngineService()
    private var timer: Timer?
    private var safetyObservers: [NSObjectProtocol] = []
    private var activeSource = ""
    private var timeout: Task<Void, Never>?
    private var stopping = false

    var engineInstalled: Bool { EngineService.enginePath != nil }
    var active: Bool { running || starting }
    var totalBytes: Int64 { transfers.reduce(0) { $0 + $1.bytes } }
    var bodyCount: Int { transfers.filter(\.hasBody).count }
    var hosts: Int { Set(transfers.map(\.host)).count }
    var selected: Transfer? { transfers.first { $0.id == selection } }
    var filtered: [Transfer] {
        transfers.filter { flow in
            let category = section != "uploads" || flow.hasBody
            let query = search.isEmpty || "\(flow.host) \(flow.method) \(flow.files.joined(separator: " "))".localizedCaseInsensitiveContains(search)
            return category && query
        }
    }

    init() {
        refreshCertificate()
        if preserveHistory,
           let data = try? Data(contentsOf: Self.historyURL),
           let saved = try? JSONDecoder().decode([Transfer].self, from: data) {
            for var flow in saved.prefix(500).reversed() {
                if !flow.isFinished { flow.status = "Inspection stopped" }
                ledger.upsert(flow)
            }
            transfers = ledger.transfers
        }
        engine.onExit = { [weak self] code in self?.didExit(code) }
        for name in [ProcessInfo.thermalStateDidChangeNotification, Notification.Name.NSProcessInfoPowerStateDidChange] {
            safetyObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.checkPower() }
            })
        }
    }

    func refreshCertificate() {
        certificateExists = FileManager.default.fileExists(atPath: EngineService.certificate.path)
        certificateTrusted = CertificateService.isTrusted
    }
    func start(prepareOnly: Bool = false) {
        guard !active, !engine.isRunning else { return }
        message = nil; coverage = nil
        if !prepareOnly && mode == .process && !CaptureValidation.validTarget(target) {
            message = "Choose an app or enter one process name, such as curl."; return
        }
        refreshCertificate()
        if !prepareOnly && mode == .process && !certificateTrusted {
            setupShown = true; message = "Complete certificate setup before inspecting an app."; return
        }
        if !prepareOnly && shouldPauseForPower {
            message = "Inspection is paused for heat or Low Power Mode. You can change the Low Power preference in Settings."; return
        }
        preparingCertificate = prepareOnly; stopping = false
        activeSource = prepareOnly ? "Setup" : (mode == .proxy ? "Manual proxy (app unverified)" : target)
        starting = true; phase = prepareOnly ? "Preparing certificate" : "Starting"
        do {
            try engine.start(target: target.trimmingCharacters(in: .whitespacesAndNewlines), manual: prepareOnly || mode == .proxy)
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.flush() }
            }
            timer?.tolerance = 0.3
            timeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(25))
                guard !Task.isCancelled, let self, self.starting else { return }
                self.message = "The engine did not become ready. Check macOS permissions or whether port 8877 is already in use."
                self.stop()
            }
        } catch {
            starting = false; preparingCertificate = false; phase = "Stopped"
            message = error.localizedDescription
        }
    }
    func stop() {
        timeout?.cancel(); stopping = true
        phase = "Stopping"
        engine.stop()
    }
    func shutdown() { engine.stop(); persist() }

    private func flush() {
        let (events, lost) = engine.inbox.drain()
        if lost > 0 { coverage = "Some activity was omitted during a burst. Totals cover retained records only." }
        for data in events {
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let kind = object["kind"] as? String else { continue }
            if kind == "ready" {
                timeout?.cancel(); refreshCertificate()
                if preparingCertificate { stop(); continue }
                if !stopping {
                    starting = false; running = true; phase = "Inspecting"
                    sessionStarted = Date()
                }
            } else if kind == "coverage" {
                coverage = object["message"] as? String
            } else if kind == "flow", var transfer = try? JSONDecoder().decode(Transfer.self, from: data) {
                transfer.source = activeSource
                ledger.upsert(transfer)
            }
        }
        if !events.isEmpty { transfers = ledger.transfers }
        if let sessionStarted { elapsed = Date().timeIntervalSince(sessionStarted) }
    }
    private func didExit(_ code: Int32) {
        flush(); timer?.invalidate(); timer = nil; timeout?.cancel()
        if code != 0 && !stopping {
            message = "Inspection engine exited (\(code)). Check the selected process, macOS network permission, and engine installation."
        }
        for var transfer in ledger.transfers where !transfer.isFinished {
            transfer.status = "Inspection stopped"; ledger.upsert(transfer)
        }
        transfers = ledger.transfers
        running = false; starting = false; preparingCertificate = false; stopping = false
        phase = "Stopped"; refreshCertificate(); persist()
    }
    private var shouldPauseForPower: Bool {
        let state = ProcessInfo.processInfo.thermalState
        return state == .serious || state == .critical || (pauseForLowPower && ProcessInfo.processInfo.isLowPowerModeEnabled)
    }
    private func checkPower() {
        if active && !preparingCertificate && shouldPauseForPower {
            message = "Inspection stopped to reduce energy use. Resume when your Mac is ready."
            stop()
        }
    }
    func clear() {
        ledger = TransferLedger(); transfers = []; selection = nil
        try? FileManager.default.removeItem(at: Self.historyURL)
    }
    func settingsChanged() {
        UserDefaults.standard.set(preserveHistory, forKey: "preserveHistory")
        UserDefaults.standard.set(pauseForLowPower, forKey: "pauseForLowPower")
        if preserveHistory { persist() } else { try? FileManager.default.removeItem(at: Self.historyURL) }
        checkPower()
    }
    private static var historyURL: URL { EngineService.support.appendingPathComponent("history.json") }
    private func persist() {
        guard preserveHistory, let data = try? JSONEncoder().encode(transfers) else { return }
        try? FileManager.default.createDirectory(at: EngineService.support, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? data.write(to: Self.historyURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.historyURL.path)
    }
}
