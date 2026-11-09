import Testing
@testable import NordvaDeskLampCore

// Expected bytes were produced independently with openssl (MD5 + AES-128-CBC).
private let token = "00112233445566778899aabbccddeeff"
private let payload = #"{"id":1,"method":"get_prop","params":["power","bright"]}"#
private let packet = MiioCodec.bytes(hex: "2131006000000000112233446553f100b22295cc3ded3c1e673615236116b86c"
    + "a5516ec6151955dc2bb2d43e7c84c1833ad6abd2560c09de4318b095b7713e2323b0713b633cb6f6df65bddd011b48e83ab6f366967a6f9c6f494b53fdb2e69f")!

@Test func encodesLikeOpenSSL() throws {
    let codec = try MiioCodec(tokenHex: token)
    #expect(try codec.encode(Array(payload.utf8), deviceID: 0x1122_3344, stamp: 1_700_000_000) == packet)
}

@Test func decodesTheReferencePacket() throws {
    let codec = try MiioCodec(tokenHex: token)
    #expect(String(decoding: try codec.decode(packet), as: UTF8.self) == payload)
}

@Test func readsTheHeader() throws {
    #expect(try MiioCodec.header(of: packet) == MiioCodec.Header(deviceID: 0x1122_3344, stamp: 1_700_000_000))
}

@Test func rejectsATamperedPacket() throws {
    let codec = try MiioCodec(tokenHex: token)
    var tampered = packet
    tampered[tampered.count - 1] ^= 0x01
    #expect(throws: MiioError.badChecksum) { try codec.decode(tampered) }
}

@Test func rejectsTheWrongToken() throws {
    let other = try MiioCodec(tokenHex: "ffeeddccbbaa99887766554433221100")
    #expect(throws: MiioError.badChecksum) { try other.decode(packet) }
}

@Test func stripsTrailingNullsFromReplies() throws {
    let codec = try MiioCodec(tokenHex: token)
    let reply = #"{"id":1,"result":["on",40]}"#
    let encoded = try codec.encode(Array(reply.utf8) + [0], deviceID: 1, stamp: 2)
    #expect(String(decoding: try codec.decode(encoded), as: UTF8.self) == reply)
}

@Test func validatesTokens() {
    #expect(MiioCodec.isValidToken(token))
    #expect(MiioCodec.isValidToken(" 00112233445566778899AABBCCDDEEFF\n"))
    #expect(!MiioCodec.isValidToken("0011"))
    #expect(!MiioCodec.isValidToken("zz112233445566778899aabbccddeeff"))
    #expect(throws: MiioError.badToken) { try MiioCodec(tokenHex: "abc") }
}

@Test func helloIsThe32ByteDiscoveryPacket() {
    #expect(MiioCodec.hello.count == 32)
    #expect(Array(MiioCodec.hello.prefix(4)) == [0x21, 0x31, 0x00, 0x20])
}
