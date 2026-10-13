<p align="center">
  <img src="docs/assets/logo.png" width="88" height="88" alt="BarFold icon">
</p>

<h1 align="center">BarFold</h1>
<p align="center"><strong>Your menu bar. Room to breathe.</strong></p>
<p align="center">A native, open-source macOS menu bar organizer inspired by Bartender.<br>Keep everyday icons in sight. Fold the rest away.</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2d8069?style=flat-square" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-263f36?style=flat-square" alt="macOS 14 or newer build target">
  <img src="https://img.shields.io/badge/built_with-Swift_6-e87945?style=flat-square" alt="Built with Swift 6">
  <a href="docs/VALIDATION.md"><img src="https://img.shields.io/badge/status-early_preview-b28a42?style=flat-square" alt="Early preview"></a>
</p>

<p align="center"><a href="#build-it-in-two-commands">Build it</a> · <a href="#three-zones-one-calmer-menu-bar">How it works</a> · <a href="CONTRIBUTING.md">Contribute</a> · <a href="README.zh-CN.md">简体中文</a></p>

![BarFold concept: arrange icons into always-hidden, collapsible, and always-visible zones, then fold away the first two.](docs/assets/hero.png)

*Concept illustration, not an app screenshot.*

> **Early preview:** the app builds locally and 123 core checks pass. Live menu bar interactions, native UI acceptance, and independent code review are still pending. The current settings UI is in Simplified Chinese. See the [validation record](docs/VALIDATION.md) before trying it.

## Less clutter. Still your Mac.

Your menu bar fills up one useful app at a time. BarFold gives those icons a place: the ones you reach for stay visible; the rest stay a click away.

Written in **Swift, AppKit, and SwiftUI**, it uses native macOS menu bar items and Command-drag arrangement. There are no third-party dependencies, accounts, network requests, or telemetry in the app.

## Three zones, one calmer menu bar

```text
Always hidden  ┊  Show on demand  │  BarFold  Always visible
```

| Zone | What belongs here | When it appears |
| --- | --- | --- |
| **Always visible** | The icons you use throughout the day | Stays in the menu bar |
| **Show on demand** | Useful utilities you open occasionally | Click BarFold or use your shortcut |
| **Always hidden** | Background tools you rarely need | Option-click BarFold to reveal everything |

These zones are implemented in the current source. Actual behavior on your Mac still needs validation.

## Small interactions that add up

| Implemented feature | What it does |
| --- | --- |
| **One-click folding** | Expand or collapse the on-demand zone |
| **Quick reveal** | Option-click to show all three zones |
| **Keyboard access** | Default shortcut: **Control + Option + B**; two alternatives and a disable option |
| **Optional hover** | Reveal after a short dwell over BarFold |
| **Auto-collapse** | Choose 5, 10, 20, 30, or 60 seconds; pauses while arranging, using menus, or editing settings |
| **Native settings** | Light, dark, and system appearance; settings saved locally |
| **Opt-in login launch** | Uses macOS login items; disabled by default |
| **Recovery** | Reopen BarFold to reveal the zones and return to setup |

## Build it in two commands

Requires **macOS 14+** and **Apple Command Line Tools with Swift 6**. The build uses your Mac's architecture. No full Xcode project or dependency download is needed.

```bash
git clone https://github.com/Akkao114/BarFold.git && cd BarFold
./build.sh
```

Open `dist/BarFold.app` in Finder. The local build is **ad hoc signed**, not Developer ID signed or notarized. This preview is distributed as source; there is no verified installer release yet.

For the core checks:

```bash
./test.sh
```

## Make it yours

1. Open BarFold. First launch reveals all zones and opens settings.
2. Click **开始整理** (Start arranging).
3. Hold **⌘ Command** and drag the actual icons in the macOS menu bar into the zones. Keep the controls ordered **┊ → │ → BarFold** from left to right.
4. Click **完成整理** (Finish arranging). BarFold checks the divider order before collapsing.

Click BarFold to toggle the on-demand icons. **⌥ Option-click** reveals everything. Right-click opens settings, arrangement, and quit actions. Quitting removes BarFold's dividers so the icons can return to the menu bar.

## Know the edges

- Icons expand in the original menu bar. **There is no second bar**, so a display notch or long application menus can still obscure icons.
- Some system or app-owned icons may not support Command-drag. Newly launched items may need rearranging.
- A macOS 14 deployment target is a build requirement, not proof of compatibility on every macOS release. Physical multi-display changes, sleep/wake, and login launch are unverified.
- The native launch attempt stopped during system application registration in the build environment. That does not establish whether manual launch will succeed elsewhere.

The app uses status-item widths to fold icons beyond the visible menu bar. Hover installs mouse-movement monitoring only when enabled; auto-collapse inspects pointer/button state and window metadata, not window titles or pixels. [Implementation and validation details →](docs/VALIDATION.md)

## Help shape the next release

The most useful contributions right now are **real-device test reports**, **English UI localization**, and **native interaction fixes**. If you try it, tell us your macOS version, display arrangement, and what happened in a [bug report](https://github.com/Akkao114/BarFold/issues/new?template=bug_report.md).

Have an idea for a calmer menu bar? [Suggest it](https://github.com/Akkao114/BarFold/issues/new?template=feature_request.md). Want to work on the code? Start with [CONTRIBUTING.md](CONTRIBUTING.md).

**If this is the kind of Mac utility you'd like to see grow, give BarFold a star.** It helps others discover the project.

## Credits & license

Inspired by [Bartender](https://www.macbartender.com/Bartender6/) and informed by [Hidden Bar's architecture](https://github.com/dwarvesf/hidden/blob/develop/docs/ARCHITECTURE.md). The source and artwork in this repository are original implementations; no code or assets were copied from those projects. BarFold is an independent project with no affiliation to Bartender.

[MIT licensed](LICENSE). Built for people who like their Mac a little quieter.
