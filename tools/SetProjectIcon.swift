import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: SetProjectIcon.swift PROJECT_DIRECTORY APP_ICON.icns\n", stderr)
    exit(1)
}
let project = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).standardizedFileURL
let iconURL = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
guard let icon = NSImage(contentsOf: iconURL) else {
    fputs("Could not load the app icon at \(iconURL.path)\n", stderr)
    exit(1)
}
guard NSWorkspace.shared.setIcon(icon, forFile: project.path, options: []) else {
    fputs("Could not set the Finder folder icon for \(project.path)\n", stderr)
    exit(1)
}
print("Set the Finder icon for \(project.path)")
