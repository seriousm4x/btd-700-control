import Foundation

@main
struct HardwareReconnect {
    static func main() throws {
        let first = try BTDHID.open()
        let initial = try first.snapshot()
        guard initial.isMediaConnected, initial.mode == .gaming else {
            first.close()
            throw NSError(domain: "HardwareReconnect", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Requires connected Gaming mode"])
        }
        print("Requesting a temporary Bluetooth disconnect.")
        try first.perform(.disconnect)
        first.close()

        var succeeded = false
        defer {
            if !succeeded, let device = try? BTDHID.open() {
                try? device.perform(.connect)
                device.close()
                print("Reconnect requested; reconnect headphones manually if necessary.")
            }
        }

        let start = ProcessInfo.processInfo.systemUptime
        var nextConnect = start
        var sawConnection = false
        var stableGaming = 0
        var lastDescription = ""
        while ProcessInfo.processInfo.systemUptime - start < 45 {
            Thread.sleep(forTimeInterval: 1)
            guard let device = try? BTDHID.open() else { continue }
            do {
                let snapshot = try device.snapshot()
                let description = "\(snapshot.stateDescription), \(snapshot.mode?.title ?? "Unknown"), \(snapshot.codecDescription)"
                if description != lastDescription {
                    print(description)
                    lastDescription = description
                }
                if snapshot.isConnected {
                    sawConnection = true
                    if snapshot.mode == .gaming, let mask = snapshot.codecMask, mask != 0, mask != 1 {
                        stableGaming += 1
                        if stableGaming >= 3 {
                            device.close()
                            succeeded = true
                            print("Reconnected and remained in Gaming mode with a non-SBC codec.")
                            return
                        }
                    } else {
                        stableGaming = 0
                    }
                } else {
                    stableGaming = 0
                    let now = ProcessInfo.processInfo.systemUptime
                    if !sawConnection && now >= nextConnect {
                        try device.perform(.connect)
                        nextConnect = now + 8
                    }
                }
            } catch {
                print("Transient USB error: \(error.localizedDescription)")
            }
            device.close()
        }
        throw NSError(domain: "HardwareReconnect", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "Did not reach stable Gaming within 45 seconds"])
    }
}
