import Foundation

enum DongleAction: Equatable {
    case setMode(AudioMode, UInt8)
    case disconnect
    case connect
}

/// Pure decision logic. Actual device responses are checked on later polls:
/// an acknowledgement is not proof that a mode was applied.
struct ModePolicy {
    private enum Recovery {
        case disconnecting(deadline: TimeInterval)
        case connecting(deadline: TimeInterval, retried: Bool)
    }

    private var recovery: Recovery?
    private var recoveryUsed = false
    private var wasConnected = false
    private var attemptedMode: AudioMode?
    private var nextModeAttempt: TimeInterval = 0
    private(set) var message: String?

    mutating func preferenceChanged() {
        attemptedMode = nil
        nextModeAttempt = 0
        // A recovery we started must finish reconnecting, even if the user
        // changes their preference while the dongle is disconnected.
        if recovery == nil { recoveryUsed = false }
        message = nil
    }

    mutating func deviceUnavailable() {
        recovery = nil
        recoveryUsed = false
        wasConnected = false
        attemptedMode = nil
        nextModeAttempt = 0
        message = nil
    }

    mutating func nextAction(
        snapshot: DongleSnapshot, preferred: AudioMode?, now: TimeInterval
    ) -> DongleAction? {
        message = nil

        if let recovery {
            switch recovery {
            case .disconnecting(let deadline):
                if !snapshot.isConnected {
                    self.recovery = .connecting(deadline: now + 5, retried: false)
                    message = "Reconnecting headphones…"
                    return .connect
                }
                if now >= deadline {
                    self.recovery = nil
                    message = "Could not disconnect for codec recovery"
                } else {
                    message = "Reconnecting headphones…"
                }
                return nil
            case .connecting(let deadline, let retried):
                if snapshot.isConnected {
                    self.recovery = nil
                    wasConnected = true
                    nextModeAttempt = 0
                    attemptedMode = nil
                    // Continue below and apply the selected mode.
                } else if now >= deadline {
                    if retried {
                        self.recovery = nil
                        wasConnected = false
                        message = "Reconnect failed; reconnect headphones manually"
                        return nil
                    }
                    self.recovery = .connecting(deadline: now + 10, retried: true)
                    message = "Retrying headphone connection…"
                    return .connect
                } else {
                    message = "Reconnecting headphones…"
                    return nil
                }
            }
        }

        if snapshot.isConnected {
            wasConnected = true
        } else if wasConnected {
            // A normal headphone disconnect starts a new recovery allowance.
            wasConnected = false
            recoveryUsed = false
            attemptedMode = nil
            nextModeAttempt = 0
        }

        guard let preferred else { return nil }
        if snapshot.isVoice {
            message = "Mode changes paused during a call"
            return nil
        }
        guard let active = snapshot.mode else {
            message = "Unknown dongle mode"
            return nil
        }
        if active == preferred {
            attemptedMode = nil
            return nil
        }

        // Leave Auracast before trying to select gaming; it may have no
        // connected unicast headphones while broadcasting.
        let target: AudioMode = active == .broadcast && preferred == .gaming ? .highQuality : preferred
        let canChange = snapshot.isMediaConnected || active == .broadcast || target == .broadcast
        guard canChange else {
            message = "Waiting for headphones to reconnect"
            return nil
        }

        if preferred == .gaming, target == .gaming, snapshot.isMediaConnected,
           snapshot.codecMask == 1, attemptedMode == .gaming, !recoveryUsed {
            recoveryUsed = true
            recovery = .disconnecting(deadline: now + 8)
            message = "Renegotiating Bluetooth codec…"
            return .disconnect
        }

        if now >= nextModeAttempt || attemptedMode != target {
            attemptedMode = target
            nextModeAttempt = now + 5
            message = "Applying \(target.title)…"
            // The upstream example uses Classic for mode changes. Preserve
            // unicast transport otherwise, but leave/enter broadcast via Classic.
            let transport: UInt8 = active == .broadcast || target == .broadcast
                ? 1 : ((1...3).contains(snapshot.transport) ? snapshot.transport : 1)
            return .setMode(target, transport)
        }
        message = "Waiting for \(target.title)…"
        return nil
    }
}
