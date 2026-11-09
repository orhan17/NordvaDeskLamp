import Foundation

enum Log {
    static var isEnabled = false

    static func debug(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        FileHandle.standardError.write(Data((message() + "\n").utf8))
    }
}
