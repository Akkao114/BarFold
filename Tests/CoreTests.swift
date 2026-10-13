import Foundation

@main
struct CoreTests {
    @MainActor
    static func main() {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            guard condition() else { fatalError("FAIL: \(name)") }
            checks += 1
        }

        check(LayoutPolicy.collapseWidth(screenWidths: []) == 500, "no display fallback")
        check(LayoutPolicy.collapseWidth(screenWidths: [1440, 3840]) == 7680, "widest display governs all menu bars")
        check(LayoutPolicy.collapseWidth(screenWidths: [7680]) == 10_000, "status item length cap")
        check(LayoutPolicy.collapseWidth(screenWidths: [.nan, .infinity, -2, 1440]) == 2880, "invalid geometry rejected")

        for enabled in [false, true] {
            for state in [BarVisibility.collapsed, .expanded, .all] {
                for widths in [[1440.0], [1440, 3840], [7680], []] {
                    let lengths = LayoutPolicy.lengths(visibility: state, alwaysHiddenEnabled: enabled, screenWidths: widths)
                    check(lengths.hidden >= 22 && lengths.hidden <= 10_000, "normal boundary is bounded")
                    check(lengths.alwaysHidden >= 0 && lengths.alwaysHidden <= 10_000, "always boundary is bounded")
                    check((lengths.hidden > 22) == (state == .collapsed), "normal section state")
                    check((lengths.alwaysHidden > 22) == (enabled && state != .all), "always-hidden section state")
                }
            }
        }

        let before = LayoutPolicy.lengths(visibility: .collapsed, alwaysHiddenEnabled: true, screenWidths: [1440])
        let after = LayoutPolicy.lengths(visibility: .collapsed, alwaysHiddenEnabled: true, screenWidths: [3840])
        check(after.hidden > before.hidden, "hotplug recalculates collapsed width")
        check(BarVisibility.collapsed.toggled == .expanded, "expand normal region")
        check(BarVisibility.expanded.toggled == .collapsed, "collapse normal region")
        check(BarVisibility.all.toggled == .collapsed, "collapse from reveal all")

        check(LayoutPolicy.shouldCollapse(visibility: .expanded, enabled: true, interaction: InteractionState()), "idle auto-hide")
        check(!LayoutPolicy.shouldCollapse(visibility: .collapsed, enabled: true, interaction: InteractionState()), "no duplicate collapse")
        check(!LayoutPolicy.shouldCollapse(visibility: .all, enabled: false, interaction: InteractionState()), "auto-hide disabled")
        for busy in [InteractionState(pointerInMenuBar: true), InteractionState(menuOpen: true),
                     InteractionState(mouseDown: true), InteractionState(settingsOpen: true), InteractionState(arranging: true)] {
            check(!LayoutPolicy.shouldCollapse(visibility: .expanded, enabled: true, interaction: busy), "interaction prevents collapse")
        }

        check(LayoutPolicy.controlsAreOrdered(toggleLeft: 130, dividerRight: 120, dividerLeft: 98, alwaysDividerRight: 70), "correct topology")
        check(!LayoutPolicy.controlsAreOrdered(toggleLeft: 80, dividerRight: 120, dividerLeft: 98, alwaysDividerRight: 70), "do not hide toggle")
        check(!LayoutPolicy.controlsAreOrdered(toggleLeft: 130, dividerRight: 120, dividerLeft: 98, alwaysDividerRight: 125), "reversed dividers rejected")
        check(!LayoutPolicy.controlsAreOrdered(toggleLeft: .nan, dividerRight: 120, dividerLeft: 98, alwaysDividerRight: nil), "invalid position rejected")

        check(LayoutPolicy.normalizedDelay(.nan) == 10, "NaN timeout")
        check(LayoutPolicy.normalizedDelay(-1) == 10, "negative timeout")
        check(LayoutPolicy.normalizedDelay(1000) == 60, "timeout upper bound")
        check(LayoutPolicy.normalizedDelay(2) == 5, "timeout lower bound")

        let preferences = Preferences(defaults: nil)
        var changes = 0
        preferences.onChange = { changes += 1 }
        preferences.autoHideDelay = .infinity
        check(preferences.autoHideDelay == 10, "persisted timeout sanitized by producer")
        preferences.hotKey = .disabled
        preferences.hasCompletedSetup = true
        check(changes == 3, "preferences notify affected consumers")
        let fresh = Preferences(defaults: nil)
        check(!fresh.hasCompletedSetup && fresh.hotKey == .controlOptionB, "QA cannot overwrite defaults")
        print("PASS: \(checks) core checks (layout, display changes, interaction, recovery, preferences).")
    }
}
