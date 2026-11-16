import AppKit

final class MenuProbe: NSObject, NSMenuDelegate {
    var isOpen = false
    func menuWillOpen(_ menu: NSMenu) { isOpen = true }
    func menuDidClose(_ menu: NSMenu) { isOpen = false }
}

@main
struct NativeMenuTests {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "BTD test"

        // If a GUI session is unavailable, fail instead of hanging forever.
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
            fputs("Native menu test timed out\n", stderr)
            exit(1)
        }

        // Allow AppKit to attach the status item to the menu bar first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let anchor = statusItem.button else { fatalError("Missing status button") }
            let menu = NSMenu()
            menu.autoenablesItems = false
            let probe = MenuProbe()
            menu.delegate = probe
            let status = NSMenuItem(title: "Status: connected", action: nil, keyEquivalent: "")
            status.isEnabled = false
            menu.addItem(status)
            var selections = 0
            var passed = false
            let view = NativeModeItem(title: "Gaming / Low Latency") { selections += 1 }
            let item = NSMenuItem(title: "Gaming / Low Latency", action: nil, keyEquivalent: "")
            item.view = view
            menu.addItem(item)

            let timer = Timer(timeInterval: 0.3, repeats: false) { _ in
                guard probe.isOpen, let window = view.window else { fatalError("Menu not open") }
                let point = view.convert(NSPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
                guard let down = NSEvent.mouseEvent(
                    with: .leftMouseDown, location: point, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil,
                    eventNumber: 1, clickCount: 1, pressure: 1
                ), let up = NSEvent.mouseEvent(
                    with: .leftMouseUp, location: point, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil,
                    eventNumber: 2, clickCount: 1, pressure: 0
                ) else { fatalError("Cannot create test click") }
                let verify = Timer(timeInterval: 0.5, repeats: false) { _ in
                    guard selections == 1, probe.isOpen else { fatalError("Selection dismissed the menu") }
                    view.selected = true

                    // Verify the modal Auracast warning does not dismiss the menu.
                    app.activate(ignoringOtherApps: true)
                    let alert = NSAlert()
                    alert.messageText = "Testing confirmation"
                    alert.addButton(withTitle: "OK")
                    let alertTimer = Timer(timeInterval: 0.3, repeats: false) { _ in
                        app.stopModal(withCode: .alertSecondButtonReturn)
                    }
                    RunLoop.main.add(alertTimer, forMode: .modalPanel)
                    _ = alert.runModal()
                    guard probe.isOpen else { fatalError("Confirmation dismissed the menu") }

                    // Match the monitor's delivery path during NSMenu tracking.
                    DispatchQueue.global().async {
                        RunLoop.main.perform(inModes: [.default, .eventTracking, .modalPanel]) {
                            guard probe.isOpen else { fatalError("Menu closed before update") }
                            status.title = "Status: streaming"
                            guard status.title == "Status: streaming" else { fatalError("Status update failed") }
                            passed = true
                            print("Native menu tests passed")
                            menu.cancelTracking()
                        }
                        CFRunLoopWakeUp(CFRunLoopGetMain())
                    }
                }
                RunLoop.main.add(verify, forMode: .eventTracking)
                // Route a complete click through AppKit's menu event loop.
                app.postEvent(up, atStart: true)
                app.postEvent(down, atStart: true)
            }
            RunLoop.main.add(timer, forMode: .eventTracking)
            _ = menu.popUp(positioning: nil, at: anchor.bounds.origin, in: anchor)
            guard passed else { fatalError("Menu did not stay open through the test") }
            NSStatusBar.system.removeStatusItem(statusItem)
            app.stop(nil)
        }
        app.run()
    }
}
