import Foundation
import IOKit.hid

/// Reads what GameController doesn't give us from the DualSense's own HID input reports:
/// the battery (GameController reports it as unknown over Bluetooth), the touchpad fingers
/// with their touch-down and lift, the mute button and the gyroscope. Opens the device shared,
/// next to GameController. Also sets the light bar with its own output report, because
/// GameController's light can stop reaching the controller and stay on one color.
///
/// Layout of the input report data, as in the Linux hid-playstation driver:
/// - offset 9: third buttons byte (bit 2 = mute)
/// - offset 15: gyroscope, three little-endian Int16s: pitch, yaw, roll
/// - offsets 32 and 36: the two touch points (bit 7 of byte 0 set = no finger, low bits = touch
///   id, then x and y as 12-bit values over 1920 × 1080)
/// - offset 52: status (low nibble = battery level in tenths, high nibble = charging state)
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
    /// The mute button under the PS logo. macOS doesn't use it, so GameController doesn't report it.
    private(set) var muteDown = false
    /// Called when the battery reading changes.
    var onBatteryChange: (() -> Void)?
    /// Called when a DualSense's HID device appears, so its light can be set.
    var onAttach: (() -> Void)?
    /// Called, at most once a second, while a Bluetooth DualSense sends only its short report,
    /// which has no gyroscope, touchpad or battery. Any output report switches it back.
    var onShortReports: (() -> Void)?
    private var lastShortReportWake: CFAbsoluteTime = 0

    /// Whether the light bar is set through the HID output report, cheap enough to animate.
    var canSetLight: Bool { !devices.isEmpty }

    /// Rotation speed in degrees per second around the controller's three axes: pitch (tipping
    /// the front up or down), yaw (turning left or right) and roll (tilting like a wheel).
    struct Rotation {
        var pitch: Double
        var yaw: Double
        var roll: Double
    }

    /// Raw gyroscope units per degree per second (about 16 at the DualSense's ±2000 °/s range).
    private static let gyroUnitsPerDegree = 16.0
    private var gyroSum = (pitch: 0.0, yaw: 0.0, roll: 0.0)
    private var gyroSamples = 0

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var buffers: [ObjectIdentifier: UnsafeMutablePointer<UInt8>] = [:]
    private var devices: [ObjectIdentifier: IOHIDDevice] = [:]
    /// Devices whose startup light has been released, so they take colors.
    private var lightReady: Set<ObjectIdentifier> = []
    /// The Bluetooth output report's sequence number, 0–15.
    private var outputSequence: UInt8 = 0
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

        // Common modes, so reports keep coming while the menu bar menu is open or a slider is dragged.
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
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
        devices[id] = device
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, buffer, Self.bufferSize, { context, _, _, _, _, report, length in
            guard let context else { return }
            Unmanaged<DualSenseHID>.fromOpaque(context).takeUnretainedValue()
                .handle(report: report, length: length)
        }, context)
        onAttach?()
    }

    private func detach(_ device: IOHIDDevice) {
        let id = ObjectIdentifier(device)
        buffers.removeValue(forKey: id)?.deallocate()
        devices[id] = nil
        lightReady.remove(id)
        if buffers.isEmpty {
            touches = []
            muteDown = false
            updateBattery(nil)
        }
    }

    /// The report includes its ID as the first byte.
    private func handle(report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        let base: Int
        switch report[0] {
        case 0x31 where length >= 55: base = 2 // Bluetooth: ID, then a tag byte
        case 0x01 where length >= 64: base = 1 // USB
        case 0x01:
            // The short Bluetooth report: buttons and sticks only. The controller falls back to it,
            // for example after reconnecting, and stays there until the Mac sends it something.
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastShortReportWake >= 1 {
                lastShortReportWake = now
                onShortReports?()
            }
            return
        default: return
        }
        // Two touch points of 4 bytes each.
        touches = [32, 36].compactMap { Self.decodeTouch(UnsafePointer(report + base + $0)) }
        // The third buttons byte: bit 0 = PS, bit 1 = touchpad click, bit 2 = mute.
        muteDown = report[base + 9] & 0x04 != 0
        // Reports arrive faster than the engine's ticks, so add them up for an average.
        func int16(_ offset: Int) -> Double {
            Double(Int16(bitPattern: UInt16(report[base + offset]) | UInt16(report[base + offset + 1]) << 8))
        }
        gyroSum.pitch += int16(15)
        gyroSum.yaw += int16(17)
        gyroSum.roll += int16(19)
        gyroSamples += 1
        updateBattery(Self.decodeBattery(report[base + 52]))
    }

    // MARK: Light bar

    /// Sets the light bar of every connected DualSense. Returns false if there is none.
    /// The report only flags the light bar, so the controller leaves rumble and the rest alone.
    @discardableResult
    func setLight(_ color: LightColor) -> Bool {
        guard !devices.isEmpty else { return false }
        func channel(_ value: Double) -> UInt8 { UInt8((min(max(value, 0), 1) * 255).rounded()) }
        var sent = false
        for (id, device) in devices {
            // The common part of the output report, as the Linux hid-playstation driver lays it out.
            var common = [UInt8](repeating: 0, count: 47)
            common[1] = 0x04                    // valid_flag1: light bar color
            if !lightReady.contains(id) {
                common[38] = 0x02               // valid_flag2: light bar setup
                common[41] = 0x02               // light bar setup: light out, ends the startup fade
            }
            common[44] = channel(color.red)
            common[45] = channel(color.green)
            common[46] = channel(color.blue)

            let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? ""
            var report: [UInt8]
            if transport.lowercased().contains("bluetooth") {
                // Bluetooth: ID 0x31, sequence and tag bytes, the common part, then a CRC-32 over
                // a 0xA2 seed byte and everything before it.
                report = [UInt8](repeating: 0, count: 78)
                report[0] = 0x31
                report[1] = outputSequence << 4
                outputSequence = (outputSequence + 1) & 0x0F
                report[2] = 0x10
                report.replaceSubrange(3..<50, with: common)
                let crc = Self.crc32([0xA2] + report[0..<74])
                for i in 0..<4 { report[74 + i] = UInt8((crc >> (8 * UInt32(i))) & 0xFF) }
            } else {
                report = [0x02] + common
            }
            let result = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(report[0]), report, report.count)
            if result == kIOReturnSuccess {
                lightReady.insert(id)
                sent = true
            } else {
                NSLog("GamepadMouse: couldn't set the light bar: \(String(format: "0x%08x", result))")
            }
        }
        return sent
    }

    private static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32<S: Sequence>(_ bytes: S) -> UInt32 where S.Element == UInt8 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes { crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
        return crc ^ 0xFFFF_FFFF
    }

    /// The average rotation since the last call, or nil if no report came in since.
    func takeRotation() -> Rotation? {
        guard gyroSamples > 0 else { return nil }
        let scale = 1 / (Double(gyroSamples) * Self.gyroUnitsPerDegree)
        let rotation = Rotation(pitch: gyroSum.pitch * scale, yaw: gyroSum.yaw * scale, roll: gyroSum.roll * scale)
        gyroSum = (0, 0, 0)
        gyroSamples = 0
        return rotation
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
