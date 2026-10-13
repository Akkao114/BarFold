import AppKit
import Combine
import CoreGraphics
import ServiceManagement

@MainActor
final class MenuBarController: NSObject, ObservableObject, NSMenuDelegate {
    let preferences: Preferences
    private let ephemeral: Bool
    private(set) var toggleItem: NSStatusItem?
    private(set) var hiddenDivider: NSStatusItem?
    private(set) var alwaysDivider: NSStatusItem?
    private var fixtureItems: [String: NSStatusItem] = [:]
    private let hotKey = GlobalHotKey()
    private var autoHideTimer: Timer?
    private var hoverTimer: Timer?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var contextMenuOpen = false
    private var started = false

    @Published private(set) var visibility: BarVisibility = .all
    @Published private(set) var isArranging = false
    @Published private(set) var hotKeyError: String?
    @Published private(set) var layoutNotice: String?
    @Published private(set) var loginEnabled = false
    @Published private(set) var loginNeedsApproval = false
    @Published private(set) var loginError: String?
    var onShowSettings: (() -> Void)?
    var settingsOpen = false { didSet { armAutoHide() } }

    init(preferences: Preferences, ephemeral: Bool = false) {
        self.preferences = preferences
        self.ephemeral = ephemeral
        super.init()
        preferences.onChange = { [weak self] in self?.preferencesChanged() }
        hotKey.action = { [weak self] in self?.toggleHidden() }
    }

    func start(smokeFixtures: Bool = false) {
        guard !started else { return }
        started = true
        if smokeFixtures { fixtureItems["visible"] = makeFixture("V") }
        toggleItem = makeItem(name: "Toggle", title: "", action: #selector(toggleClicked(_:)))
        toggleItem?.length = 28
        toggleItem?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        hiddenDivider = makeItem(name: "HiddenBoundary", title: "│", action: #selector(toggleClicked(_:)))
        if smokeFixtures { fixtureItems["hidden"] = makeFixture("H") }
        if preferences.alwaysHiddenEnabled {
            alwaysDivider = makeItem(name: "AlwaysHiddenBoundary", title: "┊", action: #selector(alwaysClicked(_:)))
        }
        if smokeFixtures { fixtureItems["alwaysHidden"] = makeFixture("A") }

        NotificationCenter.default.addObserver(self, selector: #selector(displayChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(displayChanged),
            name: NSWorkspace.didWakeNotification, object: nil)
        applyLengths()
        preferencesChanged()
        if !ephemeral { refreshLoginStatus() }

        // Status-item windows need one layout pass before their order can be checked safely.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.started else { return }
            if self.preferences.hasCompletedSetup && self.preferences.collapseOnLaunch {
                self.setVisibility(.collapsed)
            } else if self.preferences.hasCompletedSetup {
                self.setVisibility(.expanded)
            }
        }
    }

    private func makeItem(name: String, title: String, action: Selector) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: LayoutPolicy.dividerWidth)
        if !ephemeral { item.autosaveName = "BarFold.\(name)" }
        item.behavior = []
        item.isVisible = true
        item.button?.title = title
        item.button?.font = .systemFont(ofSize: 15, weight: .medium)
        item.button?.alignment = .right
        item.button?.target = self
        item.button?.action = action
        item.button?.setAccessibilityLabel(name == "Toggle" ? "BarFold，展开或收起菜单栏图标" : "BarFold 分区边界，按住 Command 拖动")
        return item
    }

    private func makeFixture(_ title: String) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: 24)
        item.button?.title = title
        return item
    }

    @objc private func toggleClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            toggleAll()
        } else {
            toggleHidden()
        }
    }

    @objc private func alwaysClicked(_ sender: Any?) { toggleAll() }
    @objc private func toggleFromMenu() { toggleHidden() }
    @objc private func allFromMenu() { toggleAll() }
    @objc private func arrangeFromMenu() { beginArrangement(); onShowSettings?() }
    @objc private func settingsFromMenu() { onShowSettings?() }
    @objc private func quitFromMenu() { NSApp.terminate(nil) }

    private func showContextMenu() {
        guard let toggleItem, let button = toggleItem.button else { return }
        let menu = NSMenu()
        menu.delegate = self
        let title = NSMenuItem(title: "BarFold · \(visibility.title)", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        addMenuItem(menu, title: visibility == .collapsed ? "展开隐藏图标" : "收起隐藏图标", action: #selector(toggleFromMenu))
        if preferences.alwaysHiddenEnabled {
            addMenuItem(menu, title: visibility == .all ? "恢复始终隐藏区域" : "显示所有图标", action: #selector(allFromMenu))
        }
        addMenuItem(menu, title: "整理图标…", action: #selector(arrangeFromMenu))
        menu.addItem(.separator())
        addMenuItem(menu, title: "偏好设置…", action: #selector(settingsFromMenu), key: ",")
        addMenuItem(menu, title: "退出 BarFold", action: #selector(quitFromMenu), key: "q")
        toggleItem.menu = menu
        button.performClick(nil)
        toggleItem.menu = nil
    }

    private func addMenuItem(_ menu: NSMenu, title: String, action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    func menuWillOpen(_ menu: NSMenu) { contextMenuOpen = true; autoHideTimer?.invalidate() }
    func menuDidClose(_ menu: NSMenu) { contextMenuOpen = false; armAutoHide() }

    func toggleHidden() {
        if isArranging { finishArrangement(); return }
        setVisibility(visibility.toggled)
    }

    func toggleAll() {
        guard !isArranging else { return }
        setVisibility(visibility == .all ? .expanded : .all)
    }

    func beginArrangement() {
        isArranging = true
        layoutNotice = nil
        setVisibility(.all)
    }

    func finishArrangement() {
        isArranging = false
        // Completion is recorded only after a valid divider order is confirmed.
        if setVisibility(.collapsed) { preferences.hasCompletedSetup = true }
    }

    @discardableResult
    func setVisibility(_ next: BarVisibility) -> Bool {
        if next != .all, visibility != .collapsed, let ordered = controlsAreOrdered(), !ordered {
            visibility = .all
            layoutNotice = "请保持从左到右为：┊ 分隔线、│ 分隔线、BarFold 按钮。按住 ⌘ 拖动调整。"
            applyLengths()
            autoHideTimer?.invalidate()
            onShowSettings?()
            return false
        }
        visibility = next
        layoutNotice = nil
        applyLengths()
        armAutoHide()
        return true
    }

    private func controlsAreOrdered() -> Bool? {
        guard let toggle = frame(of: toggleItem), let divider = frame(of: hiddenDivider),
              toggle.width > 0, divider.width > 0 else { return nil }
        return LayoutPolicy.controlsAreOrdered(toggleLeft: toggle.minX, dividerRight: divider.maxX,
            dividerLeft: divider.minX, alwaysDividerRight: frame(of: alwaysDivider).map { Double($0.maxX) })
    }

    private func applyLengths() {
        let lengths = LayoutPolicy.lengths(visibility: visibility,
            alwaysHiddenEnabled: preferences.alwaysHiddenEnabled,
            screenWidths: NSScreen.screens.map { $0.frame.width })
        hiddenDivider?.length = lengths.hidden
        alwaysDivider?.length = lengths.alwaysHidden
        toggleItem?.button?.image = NSImage(systemSymbolName: visibility == .collapsed ? "chevron.left" : "chevron.right", accessibilityDescription: "BarFold")
        toggleItem?.button?.toolTip = "BarFold · \(visibility.title)\n点击展开或收起 · ⌥ 点击显示全部 · 右键打开设置"
        hiddenDivider?.button?.toolTip = "│ 左侧：收起区域 · 按住 ⌘ 拖动图标分区"
        alwaysDivider?.button?.toolTip = "┊ 左侧：始终隐藏 · 点击此分隔线临时显示全部"
    }

    private func preferencesChanged() {
        if started {
            if preferences.alwaysHiddenEnabled && alwaysDivider == nil {
                alwaysDivider = makeItem(name: "AlwaysHiddenBoundary", title: "┊", action: #selector(alwaysClicked(_:)))
                visibility = .all
            } else if !preferences.alwaysHiddenEnabled, let item = alwaysDivider {
                NSStatusBar.system.removeStatusItem(item)
                alwaysDivider = nil
            }
            hotKeyError = hotKey.update(preferences.hotKey)
            updateHoverMonitoring()
            applyLengths()
            armAutoHide()
        }
        switch preferences.appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    @objc private func displayChanged() {
        applyLengths()
        hoverTimer?.invalidate()
        hoverTimer = nil
        armAutoHide()
    }

    private func armAutoHide(after delay: Double? = nil) {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        guard started, preferences.autoHideEnabled, preferences.hasCompletedSetup,
              visibility != .collapsed, !isArranging, !settingsOpen, !contextMenuOpen else { return }
        let timer = Timer(timeInterval: delay ?? preferences.autoHideDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.autoHideIfIdle() }
        }
        autoHideTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func autoHideIfIdle() {
        let point = NSEvent.mouseLocation
        let inMenuBar = NSScreen.screens.contains { screen in
            let height = max(NSStatusBar.system.thickness, screen.safeAreaInsets.top)
            return screen.frame.contains(point) && point.y >= screen.frame.maxY - height
        }
        let interaction = InteractionState(pointerInMenuBar: inMenuBar,
            menuOpen: contextMenuOpen || anotherMenuIsOpen(),
            mouseDown: NSEvent.pressedMouseButtons != 0,
            settingsOpen: settingsOpen, arranging: isArranging)
        if LayoutPolicy.shouldCollapse(visibility: visibility, enabled: preferences.autoHideEnabled, interaction: interaction) {
            setVisibility(.collapsed)
        } else {
            armAutoHide(after: 1.25)
        }
    }

    private func anotherMenuIsOpen() -> Bool {
        // Window layers only; no window titles, pixels or screen-recording permission are used.
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return true
        }
        let menuLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))
        return windows.contains { window in
            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            return layer == menuLayer && (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value != ProcessInfo.processInfo.processIdentifier
        }
    }

    private func updateHoverMonitoring() {
        if preferences.hoverEnabled && globalMouseMonitor == nil && localMouseMonitor == nil {
            globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                Task { @MainActor in self?.pointerMoved() }
            }
            localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                Task { @MainActor in self?.pointerMoved() }
                return event
            }
        } else if !preferences.hoverEnabled {
            removeHoverMonitoring()
        }
    }

    private func pointerMoved() {
        guard visibility == .collapsed, preferences.hoverEnabled, let rect = frame(of: toggleItem),
              rect.insetBy(dx: -4, dy: -2).contains(NSEvent.mouseLocation) else {
            hoverTimer?.invalidate(); hoverTimer = nil
            return
        }
        guard hoverTimer == nil else { return }
        let timer = Timer(timeInterval: 0.45, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.hoverTimer = nil
                guard self.started, self.preferences.hoverEnabled, self.visibility == .collapsed,
                      let rect = self.frame(of: self.toggleItem),
                      rect.insetBy(dx: -4, dy: -2).contains(NSEvent.mouseLocation) else { return }
                self.setVisibility(.expanded)
            }
        }
        hoverTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func removeHoverMonitoring() {
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        globalMouseMonitor = nil
        localMouseMonitor = nil
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    func refreshLoginStatus() {
        guard !ephemeral else { return }
        let status = SMAppService.mainApp.status
        loginEnabled = status == .enabled || status == .requiresApproval
        loginNeedsApproval = status == .requiresApproval
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard !ephemeral else { loginError = "预览模式不修改系统登录项。"; return }
        loginError = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            loginError = "macOS 未能更新登录项。请将应用放在固定位置后重试。"
        }
        refreshLoginStatus()
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    func frame(of item: NSStatusItem?) -> NSRect? {
        guard let button = item?.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    func diagnostics() -> [String: Any] {
        var fixtureFrames: [String: [String: Double]] = [:]
        for (name, item) in fixtureItems {
            if let rect = frame(of: item) { fixtureFrames[name] = ["x": rect.minX, "right": rect.maxX, "width": rect.width] }
        }
        return ["visibility": visibility.rawValue, "hiddenLength": hiddenDivider?.length ?? -1,
                "alwaysHiddenLength": alwaysDivider?.length ?? 0, "toggleVisible": toggleItem?.isVisible ?? false,
                "hotKeyRegistered": hotKey.isRegistered, "hotKeyError": hotKeyError ?? "",
                "layoutNotice": layoutNotice ?? "", "fixtures": fixtureFrames]
    }

    func stop() {
        started = false
        autoHideTimer?.invalidate()
        removeHoverMonitoring()
        hotKey.stop()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        // Removing our boundaries restores the original status items, including always-hidden items.
        for item in [toggleItem, hiddenDivider, alwaysDivider].compactMap({ $0 }) + Array(fixtureItems.values) {
            NSStatusBar.system.removeStatusItem(item)
        }
        toggleItem = nil; hiddenDivider = nil; alwaysDivider = nil
        fixtureItems.removeAll()
    }
}
