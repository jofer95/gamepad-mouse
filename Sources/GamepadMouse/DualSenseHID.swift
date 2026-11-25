import Foundation
import IOKit.hid

/// Reads what GameController doesn't give us from the DualSense's own HID input reports:
/// the battery (GameController reports it as unknown over Bluetooth) and the touchpad finger
/// with its touch-down and lift. Opens the device shared, next to GameController.
///
/// Layout of the input report data, as in the Linux hid-playstation driver:
/// offsets 32 and 36 = the two touch points (bit 7 of byte 0 set = no finger, low bits = touch
/// id, then x and y as 12-bit values over 1920 × 1080), offset 52 = status (low nibble =
/// battery level in tenths, high nibble = charging state).
final class DualSenseHID {
    struct Battery: Equatable {
        enum State { case discharging, charging, full, error }
        /// 0–10, in tenths of a full charge. The controller reports nothing finer.
        var level: Int
        var state: State
    }

    /// A finger on the touchpad. `id` changes each time a finger is put down.
    struct Touch: Equatable {
        var id: UInt8
        var x: Int
        var y: Int
    }

    private(set) var battery: Battery?
    /// The fingers on the touchpad: none, one or two.
    private(set) var touches: [Touch] = []
    /// Called when the battery reading changes.
    var onBatteryChange: (() -> Void)?

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var buffers: [ObjectIdentifier: UnsafeMutablePointer<UInt8>] = [:]
    private static let bufferSize = 128

    init() {
        let sony = 0x054C
        let matches: [[String: Int]] = [
            [kIOHIDVendorIDKey: sony, kIOHIDProductIDKey: 0x0CE6], // DualSense
            [kIOHIDVendorIDKey: sony, kIOHIDProductIDKey: 0x0DF2], // DualSense Edge
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<DualSenseHID>.fromOpaque(context).takeUnretainedValue().attach(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<DualSenseHID>.fromOpaque(context).takeUnretainedValue().detach(device)
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            NSLog("GamepadMouse: couldn't open the controller's HID reports: \(String(format: "0x%08x", result))")
        }
    }

    deinit {
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        buffers.values.forEach { $0.deallocate() }
    }

    private func attach(_ device: IOHIDDevice) {
        let id = ObjectIdentifier(device)
        guard buffers[id] == nil else { return }
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Self.bufferSize)
        buffers[id] = buffer
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, buffer, Self.bufferSize, { context, _, _, _, _, report, length in
            guard let context else { return }
            Unmanaged<DualSenseHID>.fromOpaque(context).takeUnretainedValue()
                .handle(report: report, length: length)
        }, context)
    }

    private func detach(_ device: IOHIDDevice) {
        buffers.removeValue(forKey: ObjectIdentifier(device))?.deallocate()
        if buffers.isEmpty {
            touches = []
            updateBattery(nil)
        }
    }

    /// The report includes its ID as the first byte.
    private func handle(report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        let base: Int
        switch report[0] {
        case 0x31 where length >= 55: base = 2 // Bluetooth: ID, then a tag byte
        case 0x01 where length >= 64: base = 1 // USB
        default: return // The short Bluetooth report has neither battery nor touch
        }
        // Two touch points of 4 bytes each.
        touches = [32, 36].compactMap { Self.decodeTouch(UnsafePointer(report + base + $0)) }
        updateBattery(Self.decodeBattery(report[base + 52]))
    }

    static func decodeTouch(_ point: UnsafePointer<UInt8>) -> Touch? {
        let contact = point[0]
        guard contact & 0x80 == 0 else { return nil }
        let x = Int(point[1]) | (Int(point[2] & 0x0F) << 8)
        let y = (Int(point[2]) >> 4) | (Int(point[3]) << 4)
        return Touch(id: contact & 0x7F, x: x, y: y)
    }

    static func decodeBattery(_ status: UInt8) -> Battery {
        let level = min(Int(status & 0x0F), 10)
        switch status >> 4 {
        case 0x0: return Battery(level: level, state: .discharging)
        case 0x1: return Battery(level: level, state: .charging)
        case 0x2: return Battery(level: 10, state: .full)
        default: return Battery(level: 0, state: .error)
        }
    }

    private func updateBattery(_ new: Battery?) {
        guard new != battery else { return }
        battery = new
        onBatteryChange?()
    }
}
