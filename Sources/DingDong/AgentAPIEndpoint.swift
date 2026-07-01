import Foundation

struct AgentAPIEndpoint {
    static let defaultPort: UInt16 = 8765

    let port: UInt16

    init(port: UInt16 = Self.defaultPort) {
        self.port = port
    }

    var baseURL: String {
        "http://127.0.0.1:\(port)"
    }

    var runtimeObject: [String: Any] {
        [
            "transport": "loopback-http",
            "host": "127.0.0.1",
            "port": Int(port),
            "network": "local-only"
        ]
    }
}
