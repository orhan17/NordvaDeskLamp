import AppKit

let arguments = CommandLine.arguments
Log.isEnabled = arguments.contains("--debug")

let mode: AppDelegate.Mode
if arguments.contains("--camera-check") {
    print(CameraMonitor.describe())
    exit(0)
}

if arguments.contains("--check") {
    mode = .check
} else if let index = arguments.firstIndex(of: "--panel-snapshot"), arguments.indices.contains(index + 1) {
    mode = .snapshot(arguments[index + 1])
} else {
    mode = .normal
}

if case .normal = mode,
   let bundleID = Bundle.main.bundleIdentifier,
   NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
    print("NordvaDeskLamp is already running")
    exit(0)
}

let application = NSApplication.shared
let appDelegate = AppDelegate(mode: mode)
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()
