import Foundation
import Network

final class NotificationServer: @unchecked Sendable {
    private let port: UInt16
    private let queue = DispatchQueue(label: "dingdong.api.server")
    private var listener: NWListener?
    private let onDing: @MainActor @Sendable (DingRequest) -> Void
    private let onShowPanel: @MainActor @Sendable (CompanionTab?) -> Void
    private let onClipboardMonitoring: @MainActor @Sendable (Bool) -> Void
    private let resourceStore: ResourceStoreProtocol
    private let clipboardRecorder: ClipboardRecorder
    private let agentEventStore: AgentEventStore
    private let agentPresenceStore: AgentPresenceStore

    init(
        port: UInt16 = 8765,
        resourceStore: ResourceStoreProtocol = ResourceStore(),
        clipboardRecorder: ClipboardRecorder = ClipboardRecorder(),
        agentEventStore: AgentEventStore = AgentEventStore(),
        agentPresenceStore: AgentPresenceStore = AgentPresenceStore(),
        onShowPanel: @escaping @MainActor @Sendable (CompanionTab?) -> Void = { _ in },
        onClipboardMonitoring: @escaping @MainActor @Sendable (Bool) -> Void = { _ in },
        onDing: @escaping @MainActor @Sendable (DingRequest) -> Void
    ) {
        self.port = port
        self.resourceStore = resourceStore
        self.clipboardRecorder = clipboardRecorder
        self.agentEventStore = agentEventStore
        self.agentPresenceStore = agentPresenceStore
        self.onShowPanel = onShowPanel
        self.onClipboardMonitoring = onClipboardMonitoring
        self.onDing = onDing
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(
            host: .ipv4(IPv4Address("127.0.0.1")!),
            port: NWEndpoint.Port(rawValue: port)!
        )

        let listener = try NWListener(using: parameters)
        listener.stateUpdateHandler = { state in
            print("DingDong API server state: \(state)")
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        read(connection: connection, buffer: Data())
    }

    private func read(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            var nextBuffer = buffer
            if let data {
                nextBuffer.append(data)
            }

            if error != nil || isComplete || Self.hasCompleteHTTPRequest(nextBuffer) {
                let response = self.respond(to: nextBuffer)
                connection.send(content: response.serialized(), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            self.read(connection: connection, buffer: nextBuffer)
        }
    }

    private func respond(to data: Data) -> HTTPResponse {
        guard let request = HTTPRequestParser.parse(data) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Malformed HTTP request"
            ])
        }

        let router = NotificationRouter(
            handleDing: { [onDing] dingRequest in
                Task { @MainActor in
                    onDing(dingRequest)
                }
            },
            handleShowPanel: { [onShowPanel] tab in
                Task { @MainActor in
                    onShowPanel(tab)
                }
            },
            handleClipboardMonitoring: { [onClipboardMonitoring] enabled in
                Task { @MainActor in
                    onClipboardMonitoring(enabled)
                }
            },
            resourceStore: resourceStore,
            clipboardRecorder: clipboardRecorder,
            agentEventStore: agentEventStore,
            agentPresenceStore: agentPresenceStore
        )

        return router.route(request)
    }

    private static func hasCompleteHTTPRequest(_ data: Data) -> Bool {
        guard let raw = String(data: data, encoding: .utf8),
              let splitRange = raw.range(of: "\r\n\r\n") else {
            return false
        }

        let header = raw[..<splitRange.lowerBound]
        let body = raw[splitRange.upperBound...]
        let contentLength = header
            .split(separator: "\r\n")
            .first { $0.lowercased().hasPrefix("content-length:") }?
            .split(separator: ":", maxSplits: 1)
            .last
            .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0

        return Data(body.utf8).count >= contentLength
    }
}
