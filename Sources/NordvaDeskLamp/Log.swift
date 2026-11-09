import Foundation

enum Log {
    static var isEnabled = false

    static func debug(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let time = String(format: "%.1f", ProcessInfo.processInfo.systemUptime)
        FileHandle.standardError.write(Data(("[\(time)] " + message() + "\n").utf8))
    }
}
