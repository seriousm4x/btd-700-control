import Foundation
import IOKit
import IOKit.hid

enum DongleError: LocalizedError {
    case notFound
    case multipleDevices
    case open(IOReturn)
    case write(IOReturn)
    case timeout(UInt8)
    case malformed(UInt8)

    var errorDescription: String? {
        switch self {
        case .notFound: return "BTD 700 not found"
        case .multipleDevices: return "Multiple BTD 700 dongles found"
        case .open(let code): return String(format: "Cannot open USB control interface (0x%08x)", UInt32(bitPattern: code))
        case .write(let code): return String(format: "USB write failed (0x%08x)", UInt32(bitPattern: code))
        case .timeout(let command): return String(format: "Dongle did not answer command 0x%02x", command)
        case .malformed(let command): return String(format: "Invalid response to command 0x%02x", command)
        }
    }
}

/// BTD 700 HID protocol based on https://github.com/sobalap/btd700ctl.
/// Each session is confined to one thread and releases the interface after use.
final class BTDHID {
    private let manager: IOHIDManager
    private let device: IOHIDDevice
    private let runLoop: CFRunLoop
    private let reportBuffer: UnsafeMutablePointer<UInt8>
    private let reportCapacity = 512
    private var pendingCommand: UInt8?
    private var reply: [UInt8]?
    private var closed = false

    private static let reportCallback: IOHIDReportCallback = {
        context, result, _, _, reportID, report, length in
        guard let context, result == kIOReturnSuccess, length > 0 else { return }
        let session = Unmanaged<BTDHID>.fromOpaque(context).takeUnretainedValue()
        var bytes = Array(UnsafeBufferPointer(start: report, count: length))
        // IOHID implementations may expose a numbered report with or without
        // its ID in the byte buffer. Normalize to the HIDAPI form.
        if bytes.first != 0x34 && reportID == 0x34 { bytes.insert(0x34, at: 0) }
        guard bytes.count >= 4, bytes[0] == 0x34, bytes[1] == 0xFF,
              bytes[2] == session.pendingCommand else { return }
        let count = Int(bytes[3])
        guard bytes.count >= 4 + count else { return }
        session.reply = Array(bytes[4..<(4 + count)])
    }

    static func open() throws -> BTDHID {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: 0x3542,
            kIOHIDProductIDKey: 0x3001
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        let runLoop = CFRunLoopGetCurrent()!
        IOHIDManagerScheduleWithRunLoop(manager, runLoop, CFRunLoopMode.defaultMode.rawValue)
        _ = CFRunLoopRunInMode(.defaultMode, 0.001, false)
        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        let candidates = devices.filter { device in
            guard let pairs = IOHIDDeviceGetProperty(device, kIOHIDDeviceUsagePairsKey as CFString)
                as? [[String: Any]] else { return false }
            return pairs.contains {
                ($0[kIOHIDDeviceUsagePageKey] as? NSNumber)?.intValue == 0xFFA2 &&
                ($0[kIOHIDDeviceUsageKey] as? NSNumber)?.intValue == 1
            }
        }
        guard candidates.count == 1, let device = candidates.first else {
            IOHIDManagerUnscheduleFromRunLoop(manager, runLoop, CFRunLoopMode.defaultMode.rawValue)
            if candidates.isEmpty { throw DongleError.notFound }
            throw DongleError.multipleDevices
        }
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager, runLoop, CFRunLoopMode.defaultMode.rawValue)
            throw DongleError.open(result)
        }
        return BTDHID(manager: manager, device: device, runLoop: runLoop)
    }

    private init(manager: IOHIDManager, device: IOHIDDevice, runLoop: CFRunLoop) {
        self.manager = manager
        self.device = device
        self.runLoop = runLoop
        self.reportBuffer = .allocate(capacity: reportCapacity)
        reportBuffer.initialize(repeating: 0, count: reportCapacity)
        IOHIDDeviceRegisterInputReportCallback(
            device, reportBuffer, reportCapacity, Self.reportCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        IOHIDDeviceScheduleWithRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue)
    }

    func close() {
        guard !closed else { return }
        closed = true
        IOHIDDeviceRegisterInputReportCallback(device, reportBuffer, reportCapacity, nil, nil)
        IOHIDDeviceUnscheduleFromRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(manager, runLoop, CFRunLoopMode.defaultMode.rawValue)
        reportBuffer.deinitialize(count: reportCapacity)
        reportBuffer.deallocate()
    }

    deinit { close() }

    @discardableResult
    func command(_ command: UInt8, arguments: [UInt8] = []) throws -> [UInt8] {
        precondition(arguments.count <= 60)
        var packet: [UInt8] = [0x34, 0xFE, command, UInt8(arguments.count)] + arguments
        packet += Array(repeating: 0, count: 64 - packet.count)
        pendingCommand = command
        reply = nil
        let result = packet.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0x34, $0.baseAddress!, $0.count)
        }
        guard result == kIOReturnSuccess else { throw DongleError.write(result) }
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        while reply == nil && ProcessInfo.processInfo.systemUptime < deadline {
            _ = CFRunLoopRunInMode(.defaultMode, 0.1, true)
        }
        pendingCommand = nil
        guard let reply else { throw DongleError.timeout(command) }
        return reply
    }

    func snapshot() throws -> DongleSnapshot {
        let state = try command(0x06)
        let config = try command(0x01)
        guard let stateByte = state.first else { throw DongleError.malformed(0x06) }
        guard config.count >= 2 else { throw DongleError.malformed(0x01) }
        // Some firmware/modes may not answer the codec query; an unavailable
        // codec must not prevent the user from leaving broadcast mode.
        let codec = try? command(0x05)
        let codecMask: UInt16? = codec.flatMap { bytes in
            guard !bytes.isEmpty else { return nil }
            return UInt16(bytes[0]) | (bytes.count > 1 ? UInt16(bytes[1]) << 8 : 0)
        }
        return DongleSnapshot(
            state: stateByte,
            mode: AudioMode(rawValue: config[0]),
            transport: config[1],
            codecMask: codecMask
        )
    }

    func perform(_ action: DongleAction) throws {
        switch action {
        case .setMode(let mode, let transport):
            try command(0x02, arguments: [mode.rawValue, transport])
        case .disconnect:
            try command(0x14, arguments: [0])
        case .connect:
            try command(0x14, arguments: [1])
        }
    }
}
