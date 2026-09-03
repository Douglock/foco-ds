import Foundation
import Network

final class FocoDSBridge {
    private let port: NWEndpoint.Port = 28475
    private var listener: NWListener?
    private weak var model: FocoDSModel?

    init(model: FocoDSModel) {
        self.model = model
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: port)
            
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("[FocoDSBridge] Listening on 127.0.0.1:28475")
                case .failed(let error):
                    print("[FocoDSBridge] Listener failed: \(error)")
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: .main)
        } catch {
            print("[FocoDSBridge] Failed to start listener: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        receiveNext(from: connection)
    }

    private func receiveNext(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let content = content, !content.isEmpty {
                self.processRequest(content: content, connection: connection)
            }

            if isComplete {
                connection.cancel()
            } else if error == nil {
                self.receiveNext(from: connection)
            }
        }
    }

    private func processRequest(content: Data, connection: NWConnection) {
        guard let requestString = String(data: content, encoding: .utf8) else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "{\"error\": \"Bad encoding\"}")
            return
        }

        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "{\"error\": \"Invalid request\"}")
            return
        }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "{\"error\": \"Malformed request line\"}")
            return
        }

        let method = parts[0].uppercased()
        let path = parts[1]

        // Handle CORS Preflight
        if method == "OPTIONS" {
            let headers = [
                "HTTP/1.1 204 No Content",
                "Access-Control-Allow-Origin: *",
                "Access-Control-Allow-Methods: POST, GET, OPTIONS",
                "Access-Control-Allow-Headers: Content-Type, Authorization",
                "Content-Length: 0",
                "\r\n"
            ].joined(separator: "\r\n")
            connection.send(content: headers.data(using: .utf8), completion: .contentProcessed({ _ in
                connection.cancel()
            }))
            return
        }

        // Ping / Healthcheck
        if method == "GET" && path.starts(with: "/ping") {
            sendResponse(connection: connection, status: "200 OK", body: "{\"status\": \"ok\", \"app\": \"Foco DS\"}")
            return
        }

        // State Update
        if method == "POST" && path.starts(with: "/state") {
            // Find body after double newline
            let bodyParts = requestString.components(separatedBy: "\r\n\r\n")
            if bodyParts.count > 1, let bodyData = bodyParts[1].data(using: .utf8) {
                do {
                    struct StatePayload: Decodable {
                        let isTracking: Bool?
                        let taskTitle: String?
                        let timeSpentMs: Int64?
                        let timeEstimateMs: Int64?
                        let isBreak: Bool?
                        let taskId: String?
                    }

                    let payload = try JSONDecoder().decode(StatePayload.self, from: bodyData)

                    DispatchQueue.main.async { [weak self] in
                        self?.model?.update(
                            isTracking: payload.isTracking ?? false,
                            taskTitle: payload.taskTitle ?? "Foco DS",
                            timeSpentMs: payload.timeSpentMs ?? 0,
                            timeEstimateMs: payload.timeEstimateMs ?? 0,
                            isBreak: payload.isBreak ?? false,
                            taskId: payload.taskId
                        )
                    }

                    sendResponse(connection: connection, status: "200 OK", body: "{\"ok\": true}")
                    return
                } catch {
                    sendResponse(connection: connection, status: "400 Bad Request", body: "{\"error\": \"JSON decode failed\"}")
                    return
                }
            }
        }

        sendResponse(connection: connection, status: "404 Not Found", body: "{\"error\": \"Not found\"}")
    }

    private func sendResponse(connection: NWConnection, status: String, body: String) {
        let bodyData = body.data(using: .utf8) ?? Data()
        let headers = [
            "HTTP/1.1 \(status)",
            "Content-Type: application/json; charset=utf-8",
            "Content-Length: \(bodyData.count)",
            "Access-Control-Allow-Origin: *",
            "Connection: close",
            "\r\n"
        ].joined(separator: "\r\n")

        var fullData = headers.data(using: .utf8) ?? Data()
        fullData.append(bodyData)

        connection.send(content: fullData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
}
