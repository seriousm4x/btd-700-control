import Foundation

enum AudioMode: UInt8, CaseIterable {
    case highQuality = 0
    case gaming = 1
    case broadcast = 2

    var title: String {
        switch self {
        case .highQuality: return "High Quality"
        case .gaming: return "Gaming / Low Latency"
        case .broadcast: return "Auracast Broadcast"
        }
    }
}

struct DongleSnapshot: Equatable {
    let state: UInt8
    let mode: AudioMode?
    let transport: UInt8
    let codecMask: UInt16?

    var isConnected: Bool { (2...4).contains(state) }
    var isMediaConnected: Bool { state == 2 || state == 3 }
    var isVoice: Bool { state == 4 }

    var stateDescription: String {
        switch state {
        case 0: return "Waiting for headphones"
        case 1: return "Headphones disconnected"
        case 2: return "Headphones connected"
        case 3: return "Streaming audio"
        case 4: return "Voice / call"
        default: return "Unknown (\(state))"
        }
    }

    var codecDescription: String {
        guard let codecMask, codecMask != 0 else { return "Not available" }
        let names = ["SBC", "aptX", "aptX Adaptive", "aptX Lossless", "aptX Lite", "LC3"]
        let active = names.enumerated().compactMap { index, name in
            (codecMask & (1 << index)) != 0 ? name : nil
        }
        return active.isEmpty ? String(format: "Unknown (0x%04x)", codecMask) : active.joined(separator: ", ")
    }
}

struct MenuStatus: Equatable {
    var snapshot: DongleSnapshot?
    var message: String?
    var error: String?
}
