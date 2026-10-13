import AppKit
import SwiftUI

enum RunMode {
    case app, qa, render(URL), smoke(URL)

    static func parse() -> RunMode {
        let args = CommandLine.arguments
        for (flag, render) in [("--render-previews", true), ("--smoke-test", false)] {
            if let index = args.firstIndex(of: flag), args.indices.contains(index + 1) {
                let url = URL(fileURLWithPath: args[index + 1], isDirectory: render)
                return render ? .render(url) : .smoke(url)
            }
        }
        return args.contains("--qa") ? .qa : .app
    }

    var ephemeral: Bool {
        if case .app = self { return false }
        return true
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let mode = RunMode.parse()
    let controller: MenuBarController
    private var settingsWindow: NSWindow?
    private var previewWindow: NSWindow?
    private var smokeResults: [[String: Any]] = []
    private var smokeFailures: [String] = []

    override init() {
        let mode = RunMode.parse()
        let preferences = Preferences(defaults: mode.ephemeral ? nil : .standard)
        controller = MenuBarController(preferences: preferences, ephemeral: mode.ephemeral)
        super.init()
        controller.onShowSettings = { [weak self] in self?.showSettings() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        if let iconURL = Bundle.main.url(forResource: "BarFold", withExtension: "icns"), let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        switch mode {
        case .app:
            controller.start()
            if !controller.preferences.hasCompletedSetup { showSettings() }
        case .qa:
            controller.start()
            showSettings()
        case .render(let destination):
            renderPreviews(to: destination, index: 0)
        case .smoke(let destination):
            controller.preferences.hasCompletedSetup = true
            controller.preferences.autoHideEnabled = false
            controller.preferences.collapseOnLaunch = false
            controller.start(smokeFixtures: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.runSmokeStep(0, destination: destination)
            }
        }
    }

    private func installMainMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "BarFold")
        let settings = NSMenuItem(title: "偏好设置…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "退出 BarFold", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 690),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "BarFold"
            window.contentMinSize = NSSize(width: 740, height: 620)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PreferencesView(controller: controller))
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        controller.settingsOpen = true
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        controller.refreshLoginStatus()
    }

    func windowWillClose(_ notification: Notification) { controller.settingsOpen = false }
    func applicationDidBecomeActive(_ notification: Notification) { controller.refreshLoginStatus() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller.beginArrangement()
        showSettings()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) { controller.stop() }

    private struct Preview {
        let page: SettingsPage
        let dark: Bool
        let width: Double
        let height: Double
        let filename: String
    }

    private let previews = [
        Preview(page: .menuBar, dark: false, width: 800, height: 690, filename: "menu-light.png"),
        Preview(page: .menuBar, dark: true, width: 740, height: 660, filename: "menu-dark-minimum.png"),
        Preview(page: .behavior, dark: false, width: 800, height: 720, filename: "behavior-light.png"),
        Preview(page: .behavior, dark: true, width: 740, height: 620, filename: "behavior-dark-minimum.png"),
        Preview(page: .about, dark: false, width: 800, height: 690, filename: "about-light.png")
    ]

    private func renderPreviews(to destination: URL, index: Int) {
        guard previews.indices.contains(index) else {
            print("Rendered \(previews.count) native UI previews to \(destination.path)")
            NSApp.terminate(nil)
            return
        }
        let spec = previews[index]
        do { try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true) }
        catch { fail("Cannot create preview directory: \(error)"); return }
        NSApp.appearance = NSAppearance(named: spec.dark ? .darkAqua : .aqua)
        controller.setVisibility(.collapsed)
        let view = PreferencesView(controller: controller, page: spec.page)
            .environment(\.colorScheme, spec.dark ? .dark : .light)
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: spec.width, height: spec.height),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "BarFold · Visual QA"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.appearance = NSApp.appearance
        window.center()
        window.orderFront(nil)
        previewWindow = window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self else { return }
            hosting.layoutSubtreeIfNeeded()
            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
                self.fail("Native bitmap capture unavailable."); return
            }
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                self.fail("PNG encoding unavailable."); return
            }
            do { try png.write(to: destination.appendingPathComponent(spec.filename), options: .atomic) }
            catch { self.fail("Cannot write preview: \(error)"); return }
            window.orderOut(nil)
            self.previewWindow = nil
            self.renderPreviews(to: destination, index: index + 1)
        }
    }

    private func runSmokeStep(_ index: Int, destination: URL) {
        let states: [BarVisibility] = [.all, .expanded, .collapsed, .all]
        guard states.indices.contains(index) else {
            let registered = controller.diagnostics()["hotKeyRegistered"] as? Bool ?? false
            if !registered { smokeFailures.append("Global hotkey did not register: \(controller.hotKeyError ?? "unknown")") }
            controller.stop()
            let removed = controller.toggleItem == nil && controller.hiddenDivider == nil && controller.alwaysDivider == nil
            if !removed { smokeFailures.append("Status items not removed on shutdown") }
            let result: [String: Any] = ["status": smokeFailures.isEmpty ? "pass" : "fail",
                "os": ProcessInfo.processInfo.operatingSystemVersionString,
                "ephemeralPreferences": true, "states": smokeResults,
                "cleanupPassed": removed, "failures": smokeFailures]
            do {
                let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: destination, options: .atomic)
                print(String(data: data, encoding: .utf8) ?? "")
            } catch { fail("Cannot save smoke results: \(error)"); return }
            if !smokeFailures.isEmpty { exit(1) }
            NSApp.terminate(nil)
            return
        }
        let state = states[index]
        controller.setVisibility(state)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            let snapshot = self.controller.diagnostics()
            self.smokeResults.append(snapshot)
            if self.controller.visibility != state { self.smokeFailures.append("Transition to \(state.rawValue) rejected") }
            if let fixtures = snapshot["fixtures"] as? [String: [String: Double]] {
                let left = NSScreen.screens.map { $0.frame.minX }.min() ?? 0
                for name in ["visible", "hidden", "alwaysHidden"] {
                    guard let right = fixtures[name]?["right"] else {
                        self.smokeFailures.append("Missing native fixture frame: \(name)"); continue
                    }
                    let hidden = name == "alwaysHidden" ? state != .all : (name == "hidden" && state == .collapsed)
                    if hidden && right > left + 1 { self.smokeFailures.append("\(name) fixture remains on-screen in \(state.rawValue)") }
                    if !hidden && right <= left { self.smokeFailures.append("\(name) fixture is off-screen in \(state.rawValue)") }
                }
            } else { self.smokeFailures.append("Native fixture geometry unavailable") }
            self.runSmokeStep(index + 1, destination: destination)
        }
    }

    private func fail(_ message: String) {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        controller.stop()
        exit(1)
    }
}

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()
