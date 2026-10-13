import Foundation

enum BarVisibility: String {
    case collapsed, expanded, all

    var title: String {
        switch self {
        case .collapsed: return "已收起"
        case .expanded: return "已展开"
        case .all: return "全部已展开"
        }
    }

    var toggled: BarVisibility { self == .collapsed ? .expanded : .collapsed }
}

struct DividerLengths: Equatable {
    let hidden: Double
    let alwaysHidden: Double
}

struct InteractionState {
    var pointerInMenuBar = false
    var menuOpen = false
    var mouseDown = false
    var settingsOpen = false
    var arranging = false

    var busy: Bool { pointerInMenuBar || menuOpen || mouseDown || settingsOpen || arranging }
}

enum LayoutPolicy {
    static let dividerWidth = 22.0
    static let hideDelays = [5.0, 10, 20, 30, 60]

    static func collapseWidth(screenWidths: [Double]) -> Double {
        let widest = screenWidths.filter { $0.isFinite && $0 > 0 }.max() ?? 0
        return max(500, min(widest * 2, 10_000))
    }

    static func lengths(visibility: BarVisibility, alwaysHiddenEnabled: Bool,
                        screenWidths: [Double]) -> DividerLengths {
        let width = collapseWidth(screenWidths: screenWidths)
        return DividerLengths(
            hidden: visibility == .collapsed ? width : dividerWidth,
            alwaysHidden: !alwaysHiddenEnabled ? 0 : (visibility == .all ? dividerWidth : width)
        )
    }

    static func normalizedDelay(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return 10 }
        return hideDelays.min { abs($0 - value) < abs($1 - value) } ?? 10
    }

    static func shouldCollapse(visibility: BarVisibility, enabled: Bool,
                               interaction: InteractionState) -> Bool {
        enabled && visibility != .collapsed && !interaction.busy
    }

    static func controlsAreOrdered(toggleLeft: Double, dividerRight: Double,
                                   dividerLeft: Double, alwaysDividerRight: Double?) -> Bool {
        let positions = [toggleLeft, dividerRight, dividerLeft] + [alwaysDividerRight].compactMap { $0 }
        guard positions.allSatisfy(\.isFinite), dividerRight > dividerLeft else { return false }
        return toggleLeft >= dividerRight - 1 && (alwaysDividerRight.map { $0 <= dividerLeft + 1 } ?? true)
    }
}

enum HotKeyChoice: String, CaseIterable, Identifiable {
    case controlOptionB, controlOptionM, commandShiftB, disabled
    var id: String { rawValue }
    var title: String {
        switch self {
        case .controlOptionB: return "⌃ ⌥ B"
        case .controlOptionM: return "⌃ ⌥ M"
        case .commandShiftB: return "⌘ ⇧ B"
        case .disabled: return "关闭快捷键"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}
