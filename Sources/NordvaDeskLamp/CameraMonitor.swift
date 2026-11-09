import CoreMediaIO
import Foundation

/// Tells whether any app is using a camera. CoreMediaIO reports "running somewhere" for
/// each video device without this app opening the camera, so no camera permission is needed.
final class CameraMonitor {
    var onChange: ((Bool) -> Void)?
    private(set) var isActive = false
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        check()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.check() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
    }

    private func check() {
        let active = Self.anyCameraRunning()
        guard active != isActive else { return }
        isActive = active
        Log.debug("camera \(active ? "on" : "off")")
        onChange?(active)
    }

    /// `--camera-check`: what this process sees, since camera visibility can depend on its permissions.
    static func describe() -> String {
        var devicesAddress = address(CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices))
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var size: UInt32 = 0
        let sizeStatus = CMIOObjectGetPropertyDataSize(system, &devicesAddress, 0, nil, &size)
        var devices = [CMIODeviceID](repeating: 0, count: Int(size) / MemoryLayout<CMIODeviceID>.size)
        var used: UInt32 = 0
        let listStatus = CMIOObjectGetPropertyData(system, &devicesAddress, 0, nil, size, &used, &devices)
        var runningAddress = address(CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere))
        let states = devices.map { device -> String in
            var running: UInt32 = 0
            var runningUsed: UInt32 = 0
            let status = CMIOObjectGetPropertyData(device, &runningAddress, 0, nil, 4, &runningUsed, &running)
            return "device \(device): running=\(running) status=\(status)"
        }
        return "status \(sizeStatus)/\(listStatus), \(devices.count) devices; " + states.joined(separator: "; ")
            + "; anyCameraRunning=\(anyCameraRunning())"
    }

    private static func anyCameraRunning() -> Bool {
        var devicesAddress = address(CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices))
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &devicesAddress, 0, nil, &size) == noErr, size > 0 else {
            return false
        }
        var devices = [CMIODeviceID](repeating: 0, count: Int(size) / MemoryLayout<CMIODeviceID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &devicesAddress, 0, nil, size, &used, &devices) == noErr else {
            return false
        }
        var runningAddress = address(CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere))
        return devices.contains { device in
            var running: UInt32 = 0
            var runningUsed: UInt32 = 0
            let status = CMIOObjectGetPropertyData(
                device, &runningAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &runningUsed, &running
            )
            return status == noErr && running != 0
        }
    }

    private static func address(_ selector: CMIOObjectPropertySelector) -> CMIOObjectPropertyAddress {
        CMIOObjectPropertyAddress(
            mSelector: selector,
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
    }
}
