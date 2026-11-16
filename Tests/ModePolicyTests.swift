import Foundation

@main
struct ModePolicyTests {
    static func main() {
        let high = DongleSnapshot(state: 3, mode: .highQuality, transport: 3, codecMask: 4)
        let gaming = DongleSnapshot(state: 3, mode: .gaming, transport: 1, codecMask: 4)
        let sbc = DongleSnapshot(state: 3, mode: .highQuality, transport: 3, codecMask: 1)
        let disconnected = DongleSnapshot(state: 1, mode: .highQuality, transport: 0, codecMask: 0)
        let voice = DongleSnapshot(state: 4, mode: .highQuality, transport: 3, codecMask: 1)
        let broadcast = DongleSnapshot(state: 1, mode: .broadcast, transport: 0, codecMask: 0)

        var policy = ModePolicy()
        assert(policy.nextAction(snapshot: high, preferred: nil, now: 1) == nil)
        assert(policy.nextAction(snapshot: disconnected, preferred: .gaming, now: 2) == nil)
        assert(policy.nextAction(snapshot: voice, preferred: .gaming, now: 3) == nil)
        assert(policy.nextAction(snapshot: high, preferred: .gaming, now: 4) == .setMode(.gaming, 3))
        assert(policy.nextAction(snapshot: high, preferred: .gaming, now: 5) == nil)
        assert(policy.nextAction(snapshot: high, preferred: .gaming, now: 9) == .setMode(.gaming, 3))
        assert(policy.nextAction(snapshot: gaming, preferred: .gaming, now: 10) == nil)
        assert(policy.nextAction(snapshot: disconnected, preferred: .gaming, now: 11) == nil)
        assert(policy.nextAction(snapshot: high, preferred: .gaming, now: 12) == .setMode(.gaming, 3))

        // A failed gaming request with SBC triggers one bounded recovery.
        policy = ModePolicy()
        assert(policy.nextAction(snapshot: sbc, preferred: .gaming, now: 1) == .setMode(.gaming, 3))
        assert(policy.nextAction(snapshot: sbc, preferred: .gaming, now: 2) == .disconnect)
        assert(policy.nextAction(snapshot: sbc, preferred: .gaming, now: 3) == nil)
        assert(policy.nextAction(snapshot: disconnected, preferred: .gaming, now: 4) == .connect)
        assert(policy.nextAction(snapshot: disconnected, preferred: .gaming, now: 8) == nil)
        assert(policy.nextAction(snapshot: disconnected, preferred: .gaming, now: 9) == .connect)
        assert(policy.nextAction(snapshot: disconnected, preferred: .gaming, now: 19) == nil)

        // Don't disconnect again within the same recovered connection.
        policy = ModePolicy()
        assert(policy.nextAction(snapshot: sbc, preferred: .gaming, now: 1) == .setMode(.gaming, 3))
        assert(policy.nextAction(snapshot: sbc, preferred: .gaming, now: 2) == .disconnect)
        assert(policy.nextAction(snapshot: disconnected, preferred: .gaming, now: 3) == .connect)
        assert(policy.nextAction(snapshot: sbc, preferred: .gaming, now: 4) == .setMode(.gaming, 3))
        assert(policy.nextAction(snapshot: sbc, preferred: .gaming, now: 5) == nil)

        // An explicit preference change must not strand a disconnected headset.
        policy = ModePolicy()
        _ = policy.nextAction(snapshot: sbc, preferred: .gaming, now: 1)
        _ = policy.nextAction(snapshot: sbc, preferred: .gaming, now: 2)
        policy.preferenceChanged()
        assert(policy.nextAction(snapshot: disconnected, preferred: .highQuality, now: 3) == .connect)

        // Exit broadcasting before asking for gaming, even with no headphones.
        policy = ModePolicy()
        assert(policy.nextAction(snapshot: broadcast, preferred: .gaming, now: 1) == .setMode(.highQuality, 1))
        assert(policy.nextAction(snapshot: high, preferred: .gaming, now: 2) == .setMode(.gaming, 3))
        policy = ModePolicy()
        assert(policy.nextAction(snapshot: disconnected, preferred: .broadcast, now: 1) == .setMode(.broadcast, 1))
        print("Mode policy tests passed")
    }
}
