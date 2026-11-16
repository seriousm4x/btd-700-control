import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferenceKey = "preferredAudioMode"
    private var preferred: AudioMode?
    private var monitor: DongleMonitor?
    private var statusItem: NSStatusItem!
    private var status = MenuStatus(snapshot: nil, message: "Looking for BTD 700…", error: nil)
    private let stateItem = NSMenuItem(title: "Status: Looking for BTD 700…", action: nil, keyEquivalent: "")
    private let activeItem = NSMenuItem(title: "Active: —", action: nil, keyEquivalent: "")
    private let codecItem = NSMenuItem(title: "Codec: —", action: nil, keyEquivalent: "")
    private let preferredItem = NSMenuItem(title: "Preferred: Not selected", action: nil, keyEquivalent: "")
    private var modeViews: [AudioMode: NativeModeItem] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let saved = UserDefaults.standard.object(forKey: preferenceKey) as? NSNumber,
           let mode = AudioMode(rawValue: saved.uint8Value) {
            preferred = mode
        }
        setupStatusItem()
        let monitor = DongleMonitor(preferred: preferred) { [weak self] status in
            self?.received(status)
        }
        self.monitor = monitor
        monitor.start()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(named: NSImage.Name("MenuBarIcon")) {
                image.size = NSSize(width: 18, height: 18)
                image.accessibilityDescription = "BTD 700 Control"
                image.isTemplate = true
                button.image = image
            } else if let image = NSImage(systemSymbolName: "headphones", accessibilityDescription: "BTD 700 Control") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "BTD"
            }
            button.toolTip = "BTD 700 Control"
        }

        let menu = NSMenu()
        menu.autoenablesItems = false
        let heading = NSMenuItem(title: "BTD 700 Control", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        for item in [stateItem, activeItem, codecItem, preferredItem] {
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())

        for mode in AudioMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectModeFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.tag = Int(mode.rawValue)
            let view = NativeModeItem(title: mode.title) { [weak self] in self?.selectMode(mode) }
            item.view = view
            menu.addItem(item)
            modeViews[mode] = view
        }
        menu.addItem(.separator())
        let github = NSMenuItem(title: "GitHub ♥︎", action: #selector(openGitHub), keyEquivalent: "")
        github.target = self
        menu.addItem(github)
        let quit = NSMenuItem(title: "Quit BTD 700 Control", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        render()
    }

    private func received(_ newStatus: MenuStatus) {
        status = newStatus

        // On first run, adopt the existing unicast mode without changing the
        // dongle. Auracast requires an explicit choice because it broadcasts.
        if preferred == nil, let snapshot = status.snapshot, snapshot.isMediaConnected,
           let mode = snapshot.mode, mode != .broadcast {
            save(mode)
            monitor?.select(mode)
        }
        render()
    }

    private func save(_ mode: AudioMode) {
        preferred = mode
        UserDefaults.standard.set(Int(mode.rawValue), forKey: preferenceKey)
    }

    private func render() {
        if let error = status.error {
            stateItem.title = "Status: \(error)"
        } else if let message = status.message {
            stateItem.title = "Status: \(message)"
        } else {
            stateItem.title = "Status: \(status.snapshot?.stateDescription ?? "Looking for BTD 700…")"
        }
        activeItem.title = "Active: \(status.snapshot?.mode?.title ?? "—")"
        codecItem.title = "Codec: \(status.snapshot?.codecDescription ?? "—")"
        preferredItem.title = "Preferred: \(preferred?.title ?? "Not selected")"
        for (mode, view) in modeViews {
            view.selected = preferred == mode
        }
        statusItem.button?.toolTip = status.error ?? status.snapshot.map {
            "BTD 700: \($0.stateDescription), \($0.mode?.title ?? "unknown mode")"
        } ?? "BTD 700 Control"
    }

    private func selectMode(_ mode: AudioMode) {
        if mode == .broadcast && preferred != .broadcast {
            let alert = NSAlert()
            alert.messageText = "Enable Auracast broadcasting?"
            alert.informativeText = """
            Audio may be broadcast to nearby compatible devices. This mode will \
            be remembered and automatically restored while the app is running.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Enable Broadcast")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            let confirmed = alert.runModal() == .alertFirstButtonReturn
            guard confirmed else {
                render()
                return
            }
        }
        save(mode)
        status.message = "Applying \(mode.title)…"
        render()
        monitor?.select(mode)
    }

    @objc private func selectModeFromMenu(_ sender: NSMenuItem) {
        guard let mode = AudioMode(rawValue: UInt8(sender.tag)) else { return }
        selectMode(mode)
    }

    @objc private func openGitHub() {
        guard let url = URL(string: "https://github.com/seriousm4x/btd-700-control") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@main
struct BTD700App {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}
