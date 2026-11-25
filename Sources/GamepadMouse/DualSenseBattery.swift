import Foundation
import IOKit.hid

/// Reads the DualSense battery straight from its HID input reports, because GameController
/// reports it as unknown over Bluetooth. Opens the device shared, next to GameController.
///
/// The status byte sits at offset 52 of the input report data (same layout as the Linux
/// hid-playstation driver): low nibble = level in tenths, high nibble = charging state.
final class DualSenseBattery {
    struct Reading: Equatable {
        enum State { case discharging, charging, full, error }
        var percent: Int
        var state: State
    }

    private(set) var reading: Reading?
    var onChange: (() -> Void)?

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
            Unmanaged<DualSenseBattery>.fromOpaque(context).takeUnretainedValue().attach(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<DualSenseBattery>.fromOpaque(context).takeUnretainedValue().detach(device)
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            NSLog("GamepadMouse: couldn't open the controller for battery readings: \(String(format: "0x%08x", result))")
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
            Unmanaged<DualSenseBattery>.fromOpaque(context).takeUnretainedValue()
                .handle(report: report, length: length)
        }, context)
    }

    private func detach(_ device: IOHIDDevice) {
        buffers.removeValue(forKey: ObjectIdentifier(device))?.deallocate()
        if buffers.isEmpty { update(nil) }
    }

    /// The report includes its ID as the first byte.
    private func handle(report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        let statusIndex: Int
        switch report[0] {
        case 0x31 where length >= 55: statusIndex = 54 // Bluetooth: ID, then a tag byte
        case 0x01 where length >= 64: statusIndex = 53 // USB
        default: return // The short Bluetooth report has no battery
        }
        update(Self.decode(report[statusIndex]))
    }

    static func decode(_ status: UInt8) -> Reading {
        let level = Int(status & 0x0F)
        let percent = min(level * 10 + 5, 100)
        switch status >> 4 {
        case 0x0: return Reading(percent: percent, state: .discharging)
        case 0x1: return Reading(percent: percent, state: .charging)
        case 0x2: return Reading(percent: 100, state: .full)
        default: return Reading(percent: 0, state: .error)
        }
    }

    private func update(_ new: Reading?) {
        guard new != reading else { return }
        reading = new
        onChange?()
    }
}
