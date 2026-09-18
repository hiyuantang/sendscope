import Foundation
enum Format {
    static func bytes(_ count: Int64) -> String {
        if count == 0 { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}
