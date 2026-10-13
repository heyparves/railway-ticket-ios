// Renders the app icon from `RailMark`.
// Usage: bash scripts/render-icon.sh
import AppKit
import SwiftUI

@main
struct RenderIcon {
    @MainActor
    static func main() throws {
        let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
        let renderer = ImageRenderer(content: RailMark(size: 1024))
        renderer.scale = 1
        guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: URL(fileURLWithPath: output))
        print("Wrote \(output)")
    }
}
