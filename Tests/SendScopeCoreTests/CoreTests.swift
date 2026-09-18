import XCTest
@testable import SendScopeCore

final class CoreTests: XCTestCase {
    func testTargetCannotExpandToAllProcesses() {
        for value in ["", " ", "!curl", "curl,Safari", "local:", "*", "curl\nSafari"] {
            XCTAssertFalse(CaptureValidation.validTarget(value), value)
        }
        for value in ["curl", "1234", "Google Chrome Helper", "/Applications/Example.app/Contents/MacOS/Example"] {
            XCTAssertTrue(CaptureValidation.validTarget(value), value)
        }
    }
    func testLedgerUpdatesInsteadOfDoubleCountingAndEvicts() throws {
        let json = #"{"id":"one","started":0,"host":"example.test","method":"POST","scheme":"https","contentType":"application/octet-stream","bytes":40,"responseBytes":0,"status":"Inspecting","files":[],"tls":true}"#
        var item = try JSONDecoder().decode(Transfer.self, from: Data(json.utf8))
        var ledger = TransferLedger(limit: 2)
        ledger.upsert(item)
        item.bytes = 100; ledger.upsert(item)
        XCTAssertEqual(ledger.transfers.count, 1)
        XCTAssertEqual(ledger.transfers[0].bytes, 100)
        item.id = "two"; ledger.upsert(item)
        item.id = "three"; ledger.upsert(item)
        XCTAssertEqual(ledger.transfers.map(\.id), ["three", "two"])
    }
}
