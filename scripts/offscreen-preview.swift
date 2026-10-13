import AppKit
import SwiftUI

@main
struct OffscreenPreview {
    @MainActor
    static func main() throws {
        let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let controller = MenuBarController(preferences: Preferences(defaults: nil), ephemeral: true)
        var files: [String] = []
        for page in SettingsPage.allCases {
            for dark in [false, true] {
                let minimum = dark
                let width = minimum ? 740.0 : 800
                let height = minimum ? 620.0 : 690
                let content = PreferencesView(controller: controller, page: page, scrollable: false)
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .frame(width: width, height: height)
                let renderer = ImageRenderer(content: content)
                renderer.scale = 2
                guard let image = renderer.cgImage,
                      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                let name = "\(page.rawValue)-\(dark ? "dark" : "light")-offscreen.png"
                try png.write(to: destination.appendingPathComponent(name))
                files.append(name)
            }
        }
        let manifest: [String: Any] = ["status": "partial", "liveUI": false, "files": files,
            "scope": "Actual SwiftUI page content without the AppKit-backed scroll-view wrapper",
            "limits": "ImageRenderer emits unsupported placeholders for native buttons, switches and pickers. Native controls and scrolling remain unverified."]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: destination.appendingPathComponent("manifest.json"))
        print("Rendered offscreen SwiftUI views. Native embedded controls still require live visual verification.")
    }
}
