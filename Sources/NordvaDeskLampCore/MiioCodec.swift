import CommonCrypto
import CryptoKit
import Foundation

public enum MiioError: Error, Equatable {
    case badToken
    case badPacket
    case badChecksum
    case cryptoFailed
}

/// Xiaomi's local miIO protocol over UDP 54321: a 32-byte header, then a JSON payload
/// encrypted with AES-128-CBC. Key = MD5(token), IV = MD5(key + token).
public struct MiioCodec: Sendable {
    public struct Header: Equatable, Sendable {
        public let deviceID: UInt32
        public let stamp: UInt32
    }

    /// Discovery packet: the device answers with its id and current stamp.
    public static let hello: [UInt8] = [0x21, 0x31, 0x00, 0x20] + [UInt8](repeating: 0xFF, count: 28)

    private let token: [UInt8]
    private let key: [UInt8]
    private let iv: [UInt8]

    public init(tokenHex: String) throws {
        guard let token = Self.bytes(hex: tokenHex), token.count == 16 else { throw MiioError.badToken }
        self.token = token
        key = md5(token)
        iv = md5(key + token)
    }

    public static func isValidToken(_ hex: String) -> Bool {
        bytes(hex: hex)?.count == 16
    }

    public static func bytes(hex: String) -> [UInt8]? {
        let clean = Array(hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        guard clean.count.isMultiple(of: 2), clean.allSatisfy(\.isHexDigit) else { return nil }
        return stride(from: 0, to: clean.count, by: 2).map { UInt8(String(clean[$0...$0 + 1]), radix: 16)! }
    }

    public static func header(of packet: [UInt8]) throws -> Header {
        guard packet.count >= 32, packet[0] == 0x21, packet[1] == 0x31 else { throw MiioError.badPacket }
        return Header(deviceID: bigEndian(packet, at: 8), stamp: bigEndian(packet, at: 12))
    }

    public func encode(_ payload: [UInt8], deviceID: UInt32, stamp: UInt32) throws -> [UInt8] {
        let encrypted = try crypt(payload, operation: CCOperation(kCCEncrypt))
        var header: [UInt8] = [0x21, 0x31]
        header += bigEndianBytes(UInt16(32 + encrypted.count))
        header += [0, 0, 0, 0]
        header += bigEndianBytes(deviceID)
        header += bigEndianBytes(stamp)
        let checksum = md5(header + token + encrypted)
        return header + checksum + encrypted
    }

    public func decode(_ packet: [UInt8]) throws -> [UInt8] {
        _ = try Self.header(of: packet)
        guard Int(packet[2]) << 8 | Int(packet[3]) == packet.count else { throw MiioError.badPacket }
        guard packet.count > 32 else { return [] }
        let body = Array(packet[32...])
        guard md5(Array(packet[0..<16]) + token + body) == Array(packet[16..<32]) else {
            throw MiioError.badChecksum
        }
        var plain = try crypt(body, operation: CCOperation(kCCDecrypt))
        while plain.last == 0 { plain.removeLast() }
        return plain
    }

    private func crypt(_ input: [UInt8], operation: CCOperation) throws -> [UInt8] {
        var output = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
        let capacity = output.count
        var written = 0
        let status = CCCrypt(
            operation, CCAlgorithm(kCCAlgorithmAES128), CCOptions(kCCOptionPKCS7Padding),
            key, key.count, iv, input, input.count, &output, capacity, &written
        )
        guard status == kCCSuccess else { throw MiioError.cryptoFailed }
        return Array(output.prefix(written))
    }
}

private func md5(_ data: [UInt8]) -> [UInt8] {
    Array(Insecure.MD5.hash(data: data))
}

private func bigEndianBytes<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
    withUnsafeBytes(of: value.bigEndian) { Array($0) }
}

private func bigEndian(_ bytes: [UInt8], at offset: Int) -> UInt32 {
    bytes[offset..<offset + 4].reduce(0) { $0 << 8 | UInt32($1) }
}
