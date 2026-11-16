import Foundation

/// All USB requests and policy state are serialized off the AppKit thread.
final class DongleMonitor {
    private let queue = DispatchQueue(label: "local.btd700.usb", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var policy = ModePolicy()
    private var preferred: AudioMode?
    private var lastPublished: MenuStatus?
    private let onUpdate: (MenuStatus) -> Void

    init(preferred: AudioMode?, onUpdate: @escaping (MenuStatus) -> Void) {
        self.preferred = preferred
        self.onUpdate = onUpdate
    }

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in self?.poll() }
        self.timer = timer
        timer.resume()
    }

    func select(_ mode: AudioMode) {
        queue.async { [weak self] in
            guard let self else { return }
            self.preferred = mode
            self.policy.preferenceChanged()
            self.poll()
        }
    }

    private func publish(_ status: MenuStatus) {
        guard status != lastPublished else { return }
        lastPublished = status
        // NSMenu tracks mouse events in a separate run-loop mode. Deliver
        // status updates there too, so the open menu stays up to date.
        RunLoop.main.perform(inModes: [.default, .eventTracking, .modalPanel]) { [onUpdate] in
            onUpdate(status)
        }
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }

    private func poll() {
        do {
            let dongle = try BTDHID.open()
            defer { dongle.close() }
            let snapshot = try dongle.snapshot()
            if let action = policy.nextAction(
                snapshot: snapshot,
                preferred: preferred,
                now: ProcessInfo.processInfo.systemUptime
            ) {
                try dongle.perform(action)
            }
            publish(MenuStatus(snapshot: snapshot, message: policy.message, error: nil))
        } catch {
            if let dongleError = error as? DongleError {
                switch dongleError {
                case .notFound, .multipleDevices: policy.deviceUnavailable()
                default: break
                }
            }
            publish(MenuStatus(snapshot: nil, message: nil, error: error.localizedDescription))
        }
    }
}
