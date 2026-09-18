import Foundation

public struct Transfer: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var started: Double
    public var host: String
    public var method: String
    public var scheme: String
    public var contentType: String
    public var bytes: Int64
    public var responseBytes: Int64
    public var status: String
    public var statusCode: Int?
    public var files: [String]
    public var tls: Bool
    public var source: String?

    public var date: Date { Date(timeIntervalSince1970: started) }
    public var hasBody: Bool { bytes > 0 }
    public var isFinished: Bool { status == "Response received" || status == "Connection failed" || status == "Inspection stopped" }
    public var evidence: String { files.isEmpty ? "Request body observed" : "Filename reported in request" }
}

public enum CaptureMode: String, Codable, CaseIterable, Sendable {
    case process = "Selected process"
    case proxy = "Manual proxy"
}

public enum CaptureValidation {
    public static func validTarget(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else { return false }
        // Reject mitmproxy spec operators so a target cannot silently mean all
        // processes, exclusions, or a different mode.
        return trimmed.range(of: #"^[A-Za-z0-9_. /()-]+$"#, options: .regularExpression) != nil
    }
}

public struct TransferLedger {
    public private(set) var transfers: [Transfer] = []
    public let limit: Int
    public init(limit: Int = 500) { self.limit = limit }
    public mutating func upsert(_ transfer: Transfer) {
        if let index = transfers.firstIndex(where: { $0.id == transfer.id }) {
            transfers[index] = transfer
        } else {
            transfers.insert(transfer, at: 0)
            if transfers.count > limit { transfers.removeLast(transfers.count - limit) }
        }
    }
}
