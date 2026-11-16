import AppKit

/// A native menu item view handles its own clicks so the enclosing NSMenu
/// remains open. The item title/action remain available to AppKit's menu
/// keyboard handling.
final class NativeModeItem: NSView {
    private let title: String
    private let onSelect: () -> Void
    private var hoverTracking: NSTrackingArea?
    private var hovered = false

    var selected = false {
        didSet { needsDisplay = true }
    }

    init(title: String, onSelect: @escaping () -> Void) {
        self.title = title
        self.onSelect = onSelect
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 22))
        autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTracking = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        var shouldSelect = false
        // Consume the release inside this view. Otherwise NSMenu's tracking
        // loop treats the mouse-up as a completed menu selection and closes.
        window.trackEvents(
            matching: [.leftMouseDragged, .leftMouseUp],
            timeout: NSEvent.foreverDuration,
            mode: .eventTracking
        ) { [weak self] trackedEvent, stop in
            guard let self, let trackedEvent else {
                stop.pointee = true
                return
            }
            let inside = self.bounds.contains(self.convert(trackedEvent.locationInWindow, from: nil))
            self.hovered = inside
            self.needsDisplay = true
            if trackedEvent.type == .leftMouseUp {
                shouldSelect = inside
                stop.pointee = true
            }
        }
        if shouldSelect { onSelect() }
    }

    override func mouseDragged(with event: NSEvent) {
        hovered = bounds.contains(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            onSelect()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = hovered || (enclosingMenuItem?.isHighlighted ?? false)
        if highlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 5, yRadius: 5).fill()
        }
        let color = highlighted ? NSColor.selectedMenuItemTextColor : NSColor.labelColor
        let font = NSFont.menuFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let text = title as NSString
        let textHeight = text.size(withAttributes: attributes).height
        text.draw(
            in: NSRect(x: 26, y: (bounds.height - textHeight) / 2,
                       width: max(0, bounds.width - 34), height: textHeight),
            withAttributes: attributes
        )
        if selected {
            color.setStroke()
            let check = NSBezierPath()
            check.lineWidth = 1.6
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            check.move(to: NSPoint(x: 9, y: 11))
            check.line(to: NSPoint(x: 12, y: 14))
            check.line(to: NSPoint(x: 17, y: 8))
            check.stroke()
        }
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .radioButton }
    override func accessibilityLabel() -> String? { title }
    override func accessibilityValue() -> Any? { selected ? 1 : 0 }
    override func accessibilityPerformPress() -> Bool {
        onSelect()
        return true
    }
}
