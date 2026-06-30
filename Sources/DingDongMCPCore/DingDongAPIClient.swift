import Foundation

public struct DingDongMCPConfig {
    var codexConfigURL: URL
    var claudeMCPConfigURL: URL

    public init(
        codexConfigURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("config.toml"),
        claudeMCPConfigURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent(".mcp.json")
    ) {
        self.codexConfigURL = codexConfigURL
        self.claudeMCPConfigURL = claudeMCPConfigURL
    }
}

public final class HTTPDingDongAPIClient: DingDongAPIRequesting {
    private let baseURL: URL
    private let timeout: TimeInterval

    public init(
        baseURL: URL = HTTPDingDongAPIClient.defaultBaseURL(),
        timeout: TimeInterval = 8
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
    }

    public func request(
        method: String,
        path: String,
        query: [String: String] = [:],
        body: [String: Any]? = nil
    ) throws -> Any {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        if !query.isEmpty {
            components?.queryItems = query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components?.url else {
            throw DingDongAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let semaphore = DispatchSemaphore(value: 0)
        let responseBox = URLSessionResponseBox()

        URLSession.shared.dataTask(with: request) { data, response, error in
            responseBox.data = data
            responseBox.response = response
            responseBox.error = error
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + timeout)

        if let responseError = responseBox.error {
            throw responseError
        }

        guard let http = responseBox.response as? HTTPURLResponse else {
            throw DingDongAPIError.noResponse
        }

        let data = responseBox.data ?? Data()
        let object = data.isEmpty
            ? ["status": http.statusCode]
            : try JSONSerialization.jsonObject(with: data)

        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? String(describing: object)
            throw DingDongAPIError.http(statusCode: http.statusCode, body: bodyText)
        }

        return object
    }

    public static func defaultBaseURL() -> URL {
        if let raw = ProcessInfo.processInfo.environment["DINGDONG_BASE_URL"],
           let url = URL(string: raw), url.scheme != nil {
            return url
        }

        let activePortFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DingDong/api-port")
        if let rawPort = try? String(contentsOf: activePortFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           let port = Int(rawPort),
           (1...65_535).contains(port),
           let url = URL(string: "http://127.0.0.1:\(port)") {
            return url
        }

        return URL(string: "http://127.0.0.1:8765")!
    }
}

public enum DingDongAPIError: Error, CustomStringConvertible {
    case invalidURL
    case noResponse
    case http(statusCode: Int, body: String)

    public var description: String {
        switch self {
        case .invalidURL:
            "Invalid DingDong API URL"
        case .noResponse:
            "DingDong API did not return a response"
        case .http(let statusCode, let body):
            "DingDong API returned HTTP \(statusCode): \(body)"
        }
    }
}

private final class URLSessionResponseBox: @unchecked Sendable {
    var data: Data?
    var response: URLResponse?
    var error: Error?
}
