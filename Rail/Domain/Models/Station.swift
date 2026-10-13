import Foundation

struct Station: Identifiable, Hashable, Codable, Sendable {
    /// Short station code, e.g. "DHK".
    let code: String
    let name: String

    var id: String { code }
}
