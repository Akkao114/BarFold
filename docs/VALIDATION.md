# Implementation & validation

**Source preview · 2026-10-13.** The implementation is available for inspection and contribution. Application acceptance is incomplete; this is not a stable release.

## What has evidence

The local build environment used macOS 15.7.4 on Apple Silicon and Swift 6.1.2. The deployment target is macOS 14.0. Compiling for that target does not prove runtime compatibility on every version or architecture.

| Check | Result | Scope |
| --- | --- | --- |
| Core regression checks | **123 passed** | Zone states, width bounds, interaction guards, divider ordering, settings normalization and callbacks |
| Swift 6 compilation | **Passed** | Local arm64 build |
| App bundle and signing | **Passed locally** | plist validation and strict ad hoc signature verification; no Developer ID signature or notarization |
| App icon | **Passed** | All 10 ICNS representations decoded with ImageIO |
| Build/test shell syntax | **Passed** | `bash -n build.sh test.sh` |
| SwiftUI page structure | **Partial** | Offline text, hierarchy, spacing, light/dark palettes and minimum-size checks; native controls were unsupported by the offscreen renderer |
| Normal manual launch | **Reported pass** | The project owner confirmed that the menu bar icon and Chinese settings window appeared; this is user-reported startup evidence |
| Native smoke and full UI acceptance | **Blocked / pending** | Automated launch stopped at system application registration; computer-use access remains unavailable. Actual zone interactions and native controls have not been verified |
| Actual hotkey and hover events | **Pending** | Source compiled; real events were not tested |
| Physical multi-display changes and sleep/wake | **Pending** | Width calculations have core tests; actual hardware transitions do not |
| Login item registration | **Not run** | Disabled by default; requires an explicit user choice |
| Independent code review | **Blocked / pending** | Reviewer tooling could not initialize; no review verdict was produced |

The earlier automated launch failure does not prove that the menu bar logic works or fails. A subsequent manual launch was reported successful by the project owner; that establishes startup evidence for that session, not full interaction or cross-device acceptance. The repository illustration is a concept, not runtime evidence. Local logs and machine-specific review receipts are excluded from the public repository.

## How folding works

BarFold creates a toggle and two native `NSStatusItem` dividers. Widening a divider pushes items to its left beyond the visible menu bar. The shared policy recalculates the collapse width from the widest attached display and bounds it between 500 and 10,000 points. macOS handles Command-drag arrangement and persists the status-item positions; app preferences use UserDefaults.

Divider order is checked before collapsing. Invalid order reveals all zones and provides a return to setup. Quitting removes the owned status items. Reopening starts arrangement and opens settings.

This approach expands icons in the original menu bar. It does not create an overflow panel or second bar, and does not solve every notch or menu-width conflict. Some icons cannot be dragged, and new status items may require manual arrangement.

Hover monitoring is installed only when enabled. Auto-collapse checks pointer/button state and window-layer metadata; it does not read window titles or capture screen pixels. Login launch uses `SMAppService` and is opt-in. There are no application network calls, analytics, or third-party dependencies.

## Reproduce the local checks

```bash
./build.sh
./test.sh
bash -n build.sh test.sh
```

The core test result is saved to `artifacts/core-tests.txt`. Build output is in `dist/BarFold.app`.

## Native QA on a permitted desktop

The following modes use temporary settings, do not persist normal preferences, and do not register login items. They still create actual native UI/status items and require a working desktop session.

```bash
mkdir -p artifacts
dist/BarFold.app/Contents/MacOS/BarFold --smoke-test artifacts/native-smoke.json
dist/BarFold.app/Contents/MacOS/BarFold --render-previews artifacts/visuals
dist/BarFold.app/Contents/MacOS/BarFold --qa
```

The smoke mode creates its own V/H/A test icons, checks the all/expanded/collapsed/all sequence, and removes them. It does not drag other apps' icons. Smoke results alone do not establish real hotkey presses, hover events, multiple-display behavior, or full UI acceptance.

For manual QA, verify clicks, Option-click, hotkey conflict handling and activation, hover, auto-collapse pauses, incorrect divider order, reopening, and cleanup. Use the actual native settings window to check controls, scrolling, light/dark appearance, and the minimum window size. Treat multi-display and sleep/wake tests as separate evidence. Test login launch only after explicitly enabling it in a build you intend to retain.
