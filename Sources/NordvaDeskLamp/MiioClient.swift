import Darwin
import Foundation
import NordvaDeskLampCore

enum LampError: LocalizedError {
    case notConfigured
    case badAddress(String)
    case noLocalNetworkAccess
    case network(Int32)
    case timeout
    case device(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Enter the lamp's address and token first"
        case let .badAddress(host): return "Can't find \(host) on the network"
        case .noLocalNetworkAccess:
            return "Local Network access is off: System Settings → Privacy & Security → Local Network"
        case let .network(code): return "Network error: \(String(cString: strerror(code)))"
        case .timeout: return "The lamp didn't answer. Check the address and the token"
        case let .device(message): return "The lamp refused: \(message)"
        }
    }
}

/// Blocking miIO calls over UDP. Every method must run on the caller's own serial queue.
final class MiioClient {
    private static let port: UInt16 = 54321

    private var host = ""
    private var tokenHex: String?
    private var codec: MiioCodec?
    private var fd: Int32 = -1
    private var address = sockaddr_in()
    private var deviceID: UInt32 = 0
    private var deviceStamp: UInt32 = 0
    private var handshakeAt = Date.distantPast
    private var nextID = 1

    func configure(host: String, tokenHex: String?) {
        guard host != self.host || tokenHex != self.tokenHex else { return }
        self.host = host
        self.tokenHex = tokenHex
        codec = tokenHex.flatMap { try? MiioCodec(tokenHex: $0) }
        closeSocket()
    }

    func call(_ method: String, _ params: [Any] = []) throws -> Any {
        do {
            return try attempt(method, params)
        } catch LampError.timeout {
            handshakeAt = .distantPast
            return try attempt(method, params)
        }
    }

    private func attempt(_ method: String, _ params: [Any]) throws -> Any {
        guard let codec, !host.isEmpty else { throw LampError.notConfigured }
        try openSocket()
        if Date().timeIntervalSince(handshakeAt) > 60 {
            try send(MiioCodec.hello)
            let reply = try receive()
            let header = try MiioCodec.header(of: reply)
            deviceID = header.deviceID
            deviceStamp = header.stamp
            handshakeAt = Date()
        }

        let id = nextID
        nextID += 1
        let request = try JSONSerialization.data(withJSONObject: ["id": id, "method": method, "params": params])
        let stamp = deviceStamp &+ UInt32(Date().timeIntervalSince(handshakeAt)) &+ 1
        try send(codec.encode(Array(request), deviceID: deviceID, stamp: stamp))

        while true {
            let reply = try receive()
            guard let plain = try? codec.decode(reply),
                  let json = try? JSONSerialization.jsonObject(with: Data(plain)) as? [String: Any],
                  json["id"] as? Int == id
            else { continue }
            if let error = json["error"] as? [String: Any] {
                throw LampError.device(error["message"] as? String ?? "\(error)")
            }
            Log.debug("lamp \(method) \(params) → \(json["result"] ?? "nil")")
            return json["result"] ?? NSNull()
        }
    }

    private func openSocket() throws {
        guard fd < 0 else { return }
        var hints = addrinfo(ai_flags: 0, ai_family: AF_INET, ai_socktype: SOCK_DGRAM, ai_protocol: 0,
                             ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let info = result, let sockaddr = info.pointee.ai_addr else {
            throw LampError.badAddress(host)
        }
        address = sockaddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
        address.sin_port = Self.port.bigEndian
        freeaddrinfo(result)

        fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { throw LampError.network(errno) }
        var timeout = timeval(tv_sec: 1, tv_usec: 500_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        handshakeAt = .distantPast
    }

    private func closeSocket() {
        if fd >= 0 { close(fd) }
        fd = -1
        handshakeAt = .distantPast
    }

    private func send(_ packet: [UInt8]) throws {
        let sent = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(fd, packet, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard sent == packet.count else {
            let code = errno
            closeSocket()
            // macOS reports a denied Local Network permission as "no route to host".
            throw code == EHOSTUNREACH ? LampError.noLocalNetworkAccess : LampError.network(code)
        }
    }

    private func receive() throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = recv(fd, &buffer, buffer.count, 0)
        guard count > 0 else {
            if errno == EAGAIN || errno == EWOULDBLOCK { throw LampError.timeout }
            throw LampError.network(errno)
        }
        return Array(buffer.prefix(count))
    }
}
