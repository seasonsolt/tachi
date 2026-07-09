import Foundation
import Network

final class WebSocketServer: @unchecked Sendable {
    private let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "ws.server", qos: .userInitiated)
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private let lock = NSLock()

    /// Called on the queue when a client sends a text message.
    var onClientMessage: ((NWConnection, String) -> Void)?

    /// Called on the queue when a new client connects (after WebSocket handshake).
    var onClientConnected: ((NWConnection) -> Void)?

    init(port: UInt16 = 3666) {
        self.port = port
    }

    // MARK: - Lifecycle

    func start() {
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true

        let params = NWParameters.tcp
        // Bind to the loopback interface only. The intended client is the local
        // eacc-screen SPA on the same machine; without this the listener binds
        // every interface (0.0.0.0/::) and exposes session paths, prompts, and
        // usage figures to anyone on the same LAN.
        params.requiredInterfaceType = .loopback
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("[WS] Failed to create listener: \(error)")
            return
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[WS] Listening on port \(self.port)")
            case .failed(let err):
                print("[WS] Listener failed: \(err)")
                self.listener?.cancel()
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] conn in
            self?.handleNewConnection(conn)
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        lock.lock()
        let conns = Array(connections.values)
        lock.unlock()
        for conn in conns {
            conn.cancel()
        }
        lock.lock()
        connections.removeAll()
        lock.unlock()
    }

    // MARK: - Broadcasting

    func broadcast(_ message: Data) {
        lock.lock()
        let conns = Array(connections.values)
        lock.unlock()
        for conn in conns {
            sendData(conn, message)
        }
    }

    func send(to connection: NWConnection, data: Data) {
        sendData(connection, data)
    }

    // MARK: - Private

    private func handleNewConnection(_ conn: NWConnection) {
        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.addConnection(conn)
                self?.onClientConnected?(conn)
                self?.receiveLoop(conn)
            case .failed, .cancelled:
                self?.removeConnection(conn)
            default:
                break
            }
        }
        conn.start(queue: queue)
    }

    private func receiveLoop(_ conn: NWConnection) {
        conn.receiveMessage { [weak self] content, context, isComplete, error in
            guard let self else { return }

            if let error {
                // Connection closed or errored
                if case NWError.posix(let code) = error, code == .ECANCELED {
                    // Normal close
                } else {
                    print("[WS] Receive error: \(error)")
                }
                self.removeConnection(conn)
                return
            }

            if let context, let meta = context.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata {
                switch meta.opcode {
                case .close:
                    self.removeConnection(conn)
                    return
                case .text:
                    if let content, let text = String(data: content, encoding: .utf8) {
                        self.onClientMessage?(conn, text)
                    }
                case .binary:
                    if let content, let text = String(data: content, encoding: .utf8) {
                        self.onClientMessage?(conn, text)
                    }
                default:
                    break
                }
            }

            // Continue receiving
            self.receiveLoop(conn)
        }
    }

    private func sendData(_ conn: NWConnection, _ data: Data) {
        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "ws", metadata: [meta])
        conn.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { error in
            if let error {
                print("[WS] Send error: \(error)")
            }
        })
    }

    private func addConnection(_ conn: NWConnection) {
        let key = ObjectIdentifier(conn)
        lock.lock()
        connections[key] = conn
        let count = connections.count
        lock.unlock()
        print("[WS] Client connected (\(count) total)")
    }

    private func removeConnection(_ conn: NWConnection) {
        let key = ObjectIdentifier(conn)
        lock.lock()
        let removed = connections.removeValue(forKey: key)
        let count = connections.count
        lock.unlock()
        if removed != nil {
            conn.cancel()
            print("[WS] Client disconnected (\(count) remaining)")
        }
    }
}
