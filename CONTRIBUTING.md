# Contributing to BarFold

Thanks for helping make the menu bar a little calmer. This is an early source preview; reliable native behavior comes before more features. Reports and discussion in English or Chinese are welcome.

## A useful first contribution

Try the preview on a Mac you can test safely. Report the macOS version, whether the display has a notch, your display arrangement, the action you tried, and the result you actually saw. Please separate observed behavior from guesses about the cause.

The current settings UI is in Simplified Chinese. English localization and native menu bar interaction fixes are also welcome. For substantial changes, open an issue first so we can agree on scope.

## Work on the code

```bash
./build.sh
./test.sh
```

Use macOS 14+ with Swift 6 Command Line Tools. There are no third-party dependencies. Keep changes focused, use the shared layout policy, and preserve the opt-in behavior of hover monitoring and login launch.

| File | Responsibility |
| --- | --- |
| `Sources/LayoutPolicy.swift` | Zone states, display widths, interaction guards, divider order |
| `Sources/Preferences.swift` | Local settings and normalization |
| `Sources/GlobalHotKey.swift` | Hotkey registration and conflict reporting |
| `Sources/MenuBarController.swift` | Status items, timers, hover, login items |
| `Sources/PreferencesView.swift` | Native settings |
| `Sources/main.swift` | Lifecycle, reopen recovery, QA entrypoints |
| `Tests/CoreTests.swift` | Core policy and settings regression checks |

Include the problem, the resulting behavior, checks you ran, and what remains untested in your pull request. For a UI change, include actual native screenshots with personal information removed. Clearly label illustrations and partial offscreen renders.

The core test runner does not validate WindowServer behavior or actual mouse/keyboard events. Native QA commands and their limits are in [VALIDATION.md](docs/VALIDATION.md). Avoid changing other apps' menu bar arrangements during automated checks.

## Keep reports safe to share

Exclude credentials, private window titles, full environment dumps, personal paths, and unrelated logs. Crop screenshots to the relevant controls and remove personal information. Build output and local QA artifacts belong in the ignored `.build/`, `dist/`, and `artifacts/` directories.

Contributions are provided under the project's [MIT license](LICENSE). Use original code and artwork, or include the license and attribution required for any contributed material.
