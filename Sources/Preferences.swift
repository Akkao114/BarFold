import Combine
import Foundation

@MainActor
final class Preferences: ObservableObject {
    private let defaults: UserDefaults?
    var onChange: (() -> Void)?

    @Published var alwaysHiddenEnabled: Bool {
        didSet { save(alwaysHiddenEnabled, key: "alwaysHiddenEnabled") }
    }
    @Published var autoHideEnabled: Bool {
        didSet { save(autoHideEnabled, key: "autoHideEnabled") }
    }
    @Published private var storedHideDelay: Double
    var autoHideDelay: Double {
        get { storedHideDelay }
        set {
            let value = LayoutPolicy.normalizedDelay(newValue)
            storedHideDelay = value
            save(value, key: "autoHideDelay")
        }
    }
    @Published var hoverEnabled: Bool {
        didSet { save(hoverEnabled, key: "hoverEnabled") }
    }
    @Published var collapseOnLaunch: Bool {
        didSet { save(collapseOnLaunch, key: "collapseOnLaunch") }
    }
    @Published var hotKey: HotKeyChoice {
        didSet { save(hotKey.rawValue, key: "hotKey") }
    }
    @Published var appearance: AppAppearance {
        didSet { save(appearance.rawValue, key: "appearance") }
    }
    var hasCompletedSetup: Bool {
        didSet { save(hasCompletedSetup, key: "hasCompletedSetup") }
    }

    // QA uses no persistent store, so previews and smoke tests cannot overwrite user settings.
    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        alwaysHiddenEnabled = defaults?.object(forKey: "alwaysHiddenEnabled") as? Bool ?? true
        autoHideEnabled = defaults?.object(forKey: "autoHideEnabled") as? Bool ?? true
        storedHideDelay = LayoutPolicy.normalizedDelay(defaults?.object(forKey: "autoHideDelay") as? Double ?? 10)
        hoverEnabled = defaults?.object(forKey: "hoverEnabled") as? Bool ?? false
        collapseOnLaunch = defaults?.object(forKey: "collapseOnLaunch") as? Bool ?? true
        hotKey = HotKeyChoice(rawValue: defaults?.string(forKey: "hotKey") ?? "") ?? .controlOptionB
        appearance = AppAppearance(rawValue: defaults?.string(forKey: "appearance") ?? "") ?? .system
        hasCompletedSetup = defaults?.object(forKey: "hasCompletedSetup") as? Bool ?? false
    }

    private func save(_ value: Any, key: String) {
        defaults?.set(value, forKey: key)
        onChange?()
    }
}
