import Foundation

@main
struct HardwareSmoke {
    static func main() throws {
        let dongle = try BTDHID.open()
        defer { dongle.close() }
        let before = try dongle.snapshot()
        print("State: \(before.stateDescription)")
        print("Mode: \(before.mode?.title ?? "Unknown")")
        print("Transport: \(before.transport)")
        print("Codec: \(before.codecDescription)")

        // Opt-in only. This changes the actual dongle and may interrupt audio.
        if CommandLine.arguments.contains("--set-gaming") {
            guard before.isMediaConnected else {
                throw NSError(domain: "HardwareSmoke", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "No media headphones connected"])
            }
            let transport: UInt8 = (1...3).contains(before.transport) ? before.transport : 1
            try dongle.perform(.setMode(.gaming, transport))
            Thread.sleep(forTimeInterval: 1)
            let after = try dongle.snapshot()
            print("After request: \(after.mode?.title ?? "Unknown") / \(after.codecDescription)")
            guard after.mode == .gaming else {
                throw NSError(domain: "HardwareSmoke", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Dongle did not enter gaming mode"])
            }
        }
        // Opt-in reversible test, never used while broadcasting.
        if CommandLine.arguments.contains("--roundtrip") {
            guard before.isMediaConnected, let original = before.mode, original != .broadcast else {
                throw NSError(domain: "HardwareSmoke", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "Requires connected unicast audio"])
            }
            let transport: UInt8 = (1...3).contains(before.transport) ? before.transport : 1
            let temporary: AudioMode = original == .gaming ? .highQuality : .gaming
            defer { try? dongle.perform(.setMode(original, transport)) }
            try dongle.perform(.setMode(temporary, transport))
            Thread.sleep(forTimeInterval: 1)
            let changed = try dongle.snapshot()
            print("Changed temporarily: \(changed.mode?.title ?? "Unknown")")
            guard changed.mode == temporary else {
                throw NSError(domain: "HardwareSmoke", code: 4,
                              userInfo: [NSLocalizedDescriptionKey: "Temporary mode was not applied"])
            }
            try dongle.perform(.setMode(original, transport))
            Thread.sleep(forTimeInterval: 1)
            let restored = try dongle.snapshot()
            print("Restored: \(restored.mode?.title ?? "Unknown")")
            guard restored.mode == original else {
                throw NSError(domain: "HardwareSmoke", code: 5,
                              userInfo: [NSLocalizedDescriptionKey: "Original mode was not restored"])
            }
        }
        // With the app running and Gaming selected, verify it restores a
        // temporary physical mode change. The dongle is restored on failure.
        if CommandLine.arguments.contains("--test-app-restore") {
            guard before.isMediaConnected, before.mode == .gaming else {
                throw NSError(domain: "HardwareSmoke", code: 6,
                              userInfo: [NSLocalizedDescriptionKey: "Requires connected gaming mode"])
            }
            let transport: UInt8 = (1...3).contains(before.transport) ? before.transport : 1
            try dongle.perform(.setMode(.highQuality, transport))
            dongle.close()
            for _ in 0..<20 {
                Thread.sleep(forTimeInterval: 0.5)
                if let check = try? BTDHID.open() {
                    let current = try? check.snapshot()
                    check.close()
                    if current?.mode == .gaming {
                        print("The app restored Gaming / Low Latency.")
                        return
                    }
                }
            }
            if let restore = try? BTDHID.open() {
                try? restore.perform(.setMode(.gaming, transport))
                restore.close()
            }
            throw NSError(domain: "HardwareSmoke", code: 7,
                          userInfo: [NSLocalizedDescriptionKey: "App did not restore gaming within 10 seconds"])
        }
    }
}
