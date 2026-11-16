import AppKit
import Foundation

// Render the editable SVGs using macOS's native SVG support. The resulting
// iconset is packaged into an .icns by iconutil in build-app.sh.
guard CommandLine.arguments.count == 5 else {
    fputs("Usage: GenerateIcons.swift APP.svg MENU.svg OUTPUT.iconset RESOURCES_DIR\n", stderr)
    exit(1)
}

let arguments = CommandLine.arguments
guard let appIcon = NSImage(contentsOfFile: arguments[1]),
      let menuIcon = NSImage(contentsOfFile: arguments[2]) else {
    fputs("Could not load the SVG icon artwork\n", stderr)
    exit(1)
}

let iconset = URL(fileURLWithPath: arguments[3], isDirectory: true)
let resources = URL(fileURLWithPath: arguments[4], isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

func writePNG(_ image: NSImage, pixels: Int, to url: URL) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    context.imageInterpolation = .high
    image.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: .zero, operation: .sourceOver, fraction: 1,
        respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: url, options: .atomic)
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(points)x\(points)\(suffix).png"
        try writePNG(appIcon, pixels: points * scale, to: iconset.appendingPathComponent(name))
    }
}
try writePNG(menuIcon, pixels: 18, to: resources.appendingPathComponent("MenuBarIcon.png"))
try writePNG(menuIcon, pixels: 36, to: resources.appendingPathComponent("MenuBarIcon@2x.png"))
