import Foundation

struct HTTPResponse: Equatable {
    var statusCode: Int
    var reason: String
    var headers: [String: String]
    var body: Data

    init(statusCode: Int, reason: String, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.reason = reason
        self.headers = headers
        self.body = body
    }

    static func json(statusCode: Int = 200, reason: String = "OK", object: [String: String]) -> HTTPResponse {
        let body = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        return HTTPResponse(
            statusCode: statusCode,
            reason: reason,
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: body
        )
    }

    static func jsonObject(statusCode: Int = 200, reason: String = "OK", _ object: [String: Any]) -> HTTPResponse {
        let body = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
        return HTTPResponse(
            statusCode: statusCode,
            reason: reason,
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: body
        )
    }

    func serialized() -> Data {
        var headerLines = [
            "HTTP/1.1 \(statusCode) \(reason)",
            "Content-Length: \(body.count)",
            "Connection: close"
        ]

        for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
            headerLines.append("\(key): \(value)")
        }

        headerLines.append("")
        headerLines.append("")

        var data = headerLines.joined(separator: "\r\n").data(using: .utf8) ?? Data()
        data.append(body)
        return data
    }
}

struct HTTPRequest {
    var method: String
    var path: String
    var body: Data
}

enum HTTPRequestParser {
    static func parse(_ data: Data) -> HTTPRequest? {
        guard let raw = String(data: data, encoding: .utf8),
              let splitRange = raw.range(of: "\r\n\r\n") else {
            return nil
        }

        let header = String(raw[..<splitRange.lowerBound])
        let bodyStart = splitRange.upperBound
        let body = Data(raw[bodyStart...].utf8)
        let firstLine = header.split(separator: "\r\n", maxSplits: 1, omittingEmptySubsequences: false).first
        let parts = firstLine?.split(separator: " ")

        guard let parts, parts.count >= 2 else {
            return nil
        }

        return HTTPRequest(
            method: String(parts[0]).uppercased(),
            path: String(parts[1]),
            body: body
        )
    }
}
