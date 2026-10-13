import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case menuBar, behavior, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .menuBar: return "菜单栏"
        case .behavior: return "行为与快捷键"
        case .about: return "关于"
        }
    }
    var symbol: String {
        switch self {
        case .menuBar: return "rectangle.topthird.inset.filled"
        case .behavior: return "slider.horizontal.3"
        case .about: return "info.circle"
        }
    }
}

@MainActor
enum BarTheme {
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.35, green: 0.79, blue: 0.65, alpha: 1)
            : NSColor(red: 0.10, green: 0.47, blue: 0.38, alpha: 1)
    })
}

struct PreferencesView: View {
    @ObservedObject var controller: MenuBarController
    @ObservedObject var preferences: Preferences
    @State private var selection: SettingsPage
    private let scrollable: Bool

    init(controller: MenuBarController, page: SettingsPage = .menuBar, scrollable: Bool = true) {
        self.controller = controller
        self.preferences = controller.preferences
        _selection = State(initialValue: page)
        self.scrollable = scrollable
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            if scrollable {
                ScrollView { pageContent }
            } else {
                // ImageRenderer cannot flatten an AppKit-backed scroll view; render the same content directly.
                pageContent.frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(minWidth: 740, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(BarTheme.accent)
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch selection {
            case .menuBar: menuBarPage
            case .behavior: behaviorPage
            case .about: aboutPage
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                BarFoldMark().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("BarFold").font(.system(size: 18, weight: .semibold))
                    Text("菜单栏，井然有序").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 22)
            .padding(.bottom, 32)

            ForEach(SettingsPage.allCases) { page in
                Button {
                    selection = page
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: page.symbol).font(.system(size: 14)).frame(width: 18)
                        Text(page.title).font(.system(size: 13, weight: selection == page ? .semibold : .regular))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(selection == page ? BarTheme.accent : Color.primary)
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(selection == page ? BarTheme.accent.opacity(0.12) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(page.title)
                .padding(.bottom, 4)
            }
            Spacer(minLength: 24)
            HStack(spacing: 6) {
                Circle().fill(BarTheme.accent).frame(width: 5, height: 5)
                Text("只在你的 Mac 上运行").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Text("版本 1.0").font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 7)
        }
        .padding(.horizontal, 16).padding(.bottom, 22)
        .frame(width: 188)
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(0.025))
    }

    private var menuBarPage: some View {
        Group {
            pageHeading("把空间，留给常用图标。", subtitle: "收起暂时用不到的图标，需要时一键展开。")

            Card {
                HStack(spacing: 16) {
                    Image(systemName: controller.visibility == .collapsed ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                        .font(.system(size: 22)).foregroundStyle(BarTheme.accent)
                        .frame(width: 44, height: 44)
                        .background(BarTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(controller.isArranging ? "正在整理图标" : controller.visibility.title)
                            .font(.system(size: 15, weight: .semibold))
                        Text(controller.isArranging ? "全部图标已展开，自动收起已暂停。" : "⌥ 点击菜单栏按钮，可临时显示全部。")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button(controller.isArranging ? "完成整理" : (controller.visibility == .collapsed ? "展开图标" : "收起图标")) {
                        controller.toggleHidden()
                    }
                    .buttonStyle(.borderedProminent).controlSize(.regular)
                }
            }

            if let notice = controller.layoutNotice {
                Notice(symbol: "arrow.left.arrow.right", text: notice)
            }

            Card {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("三个区域，各就各位").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("分区示意").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 7) {
                        if preferences.alwaysHiddenEnabled {
                            zone("始终隐藏", symbols: ["icloud", "arrow.triangle.2.circlepath"], subdued: true)
                            previewDivider("┊")
                        }
                        zone("收起区域", symbols: ["headphones", "square.stack.3d.up"], subdued: false)
                        previewDivider("│")
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(BarTheme.accent)
                            .accessibilityLabel("BarFold 控制按钮")
                        zone("常显区域", symbols: ["wifi", "battery.75percent"], subdued: false)
                    }
                    Text("实际图标请在屏幕顶部的系统菜单栏拖动。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Text("花一分钟，整理一次").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Button(controller.isArranging ? "完成整理" : "开始整理") {
                            if controller.isArranging { controller.finishArrangement() }
                            else { controller.beginArrangement() }
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                    instruction(1, "按住 ⌘，拖动屏幕顶部的菜单栏图标。")
                    instruction(2, preferences.alwaysHiddenEnabled
                        ? "拖到 │ 左侧可收起；拖到 ┊ 左侧始终隐藏。"
                        : "拖到 │ 左侧可收起，右侧保持常显。")
                    instruction(3, preferences.alwaysHiddenEnabled
                        ? "保持顺序为：┊、│、BarFold 按钮，再完成整理。"
                        : "保持 │ 位于 BarFold 按钮左侧，再完成整理。")
                }
            }

            Card {
                SwitchRow(title: "启用始终隐藏区域", detail: "为很少使用的图标多留一个区域。", isOn: $preferences.alwaysHiddenEnabled)
            }
        }
    }

    private var behaviorPage: some View {
        Group {
            pageHeading("按你的习惯，轻松展开。", subtitle: "让收起、展开和启动都恰到好处。")

            Card {
                VStack(alignment: .leading, spacing: 17) {
                    SwitchRow(title: "自动收起", detail: "菜单使用中、整理图标时和设置窗口打开时会暂停。", isOn: $preferences.autoHideEnabled)
                    if preferences.autoHideEnabled {
                        HStack {
                            Text("闲置后收起").font(.system(size: 12)).foregroundStyle(.secondary)
                            Spacer()
                            Picker("闲置后收起", selection: $preferences.autoHideDelay) {
                                ForEach(LayoutPolicy.hideDelays, id: \.self) { delay in
                                    Text("\(Int(delay)) 秒").tag(delay)
                                }
                            }
                            .labelsHidden().pickerStyle(.segmented).frame(width: 280)
                        }
                    }
                    Divider()
                    SwitchRow(title: "悬停展开", detail: "在 BarFold 按钮上停留片刻，展开收起区域。", isOn: $preferences.hoverEnabled)
                    Divider()
                    SwitchRow(title: "启动时收起", detail: "首次启动保持展开，完成整理后生效。", isOn: $preferences.collapseOnLaunch)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("全局快捷键").font(.system(size: 13, weight: .semibold))
                            Text("在任何应用中展开或收起图标。")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("全局快捷键", selection: $preferences.hotKey) {
                            ForEach(HotKeyChoice.allCases) { choice in Text(choice.title).tag(choice) }
                        }
                        .labelsHidden().frame(width: 145)
                    }
                    if let error = controller.hotKeyError {
                        Notice(symbol: "keyboard", text: error)
                    }
                    HStack(spacing: 9) {
                        Image(systemName: "cursorarrow").foregroundStyle(.secondary)
                        Text("单击展开 · ⌥ 单击显示全部 · 右键打开设置")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    SwitchRow(title: "登录时启动", detail: "登录 Mac 后，BarFold 自动在菜单栏运行。", isOn: Binding(
                        get: { controller.loginEnabled }, set: { controller.setLaunchAtLogin($0) }))
                    if controller.loginNeedsApproval {
                        HStack {
                            Text("需要在系统设置中批准登录项。")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            Spacer()
                            Button("打开系统设置") { controller.openLoginSettings() }.controlSize(.small)
                        }
                    }
                    if let error = controller.loginError { Notice(symbol: "exclamationmark.circle", text: error) }
                }
            }

            Card {
                HStack {
                    Text("外观").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Picker("外观", selection: $preferences.appearance) {
                        ForEach(AppAppearance.allCases) { mode in Text(mode.title).tag(mode) }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 250)
                }
            }
        }
    }

    private var aboutPage: some View {
        Group {
            pageHeading("一个小工具，一点大不同。", subtitle: "专注菜单栏，保持轻巧。")
            Card {
                HStack(spacing: 18) {
                    BarFoldMark().frame(width: 66, height: 66)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("BarFold").font(.system(size: 23, weight: .semibold))
                        Text("一键收起，随时展开。")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                        Text("版本 1.0 · 原生 macOS 应用")
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 18) {
                    aboutRow("hand.raised", title: "轻量权限", detail: "不需要录屏或辅助功能授权。")
                    aboutRow("internaldrive", title: "设置留在本机", detail: "没有账户、遥测或网络请求。")
                    aboutRow("power", title: "启动由你决定", detail: "登录时启动默认关闭，可随时在系统设置撤销。")
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("刘海屏使用提示", systemImage: "macbook")
                        .font(.system(size: 13, weight: .semibold))
                    Text("当前版本在原菜单栏展开图标。图标很多时仍可能被刘海遮住，建议只保留需要的菜单栏项目。")
                        .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("关闭这个窗口后，BarFold 会继续在菜单栏运行。\n若控制按钮被误拖到隐藏区域，重新打开应用即可展开全部图标并恢复整理。")
                .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
        }
    }

    private func pageHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 23, weight: .semibold))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(.top, 8).padding(.bottom, 3)
    }

    private func previewDivider(_ title: String) -> some View {
        Text(title).font(.system(size: 20, weight: .light)).foregroundStyle(.tertiary)
    }

    private func zone(_ title: String, symbols: [String], subdued: Bool) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ForEach(symbols, id: \.self) { symbol in
                    Image(systemName: symbol).font(.system(size: 15)).accessibilityHidden(true)
                }
            }
            .foregroundStyle(subdued ? Color.secondary : Color.primary)
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
    }

    private func instruction(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(number)").font(.system(size: 10, weight: .semibold))
                .foregroundStyle(BarTheme.accent).frame(width: 18, height: 18)
                .background(BarTheme.accent.opacity(0.1), in: Circle())
            Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 2)
        }
    }

    private func aboutRow(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(BarTheme.accent).frame(width: 22)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.frame(maxWidth: .infinity, alignment: .leading).padding(17)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Color.primary.opacity(0.055), lineWidth: 1))
    }
}

private struct SwitchRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).accessibilityLabel(title)
        }
    }
}

private struct Notice: View {
    let symbol: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).padding(.top, 1)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11)).foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11).background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
    }
}

struct BarFoldMark: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack {
                RoundedRectangle(cornerRadius: width * 0.24)
                    .fill(LinearGradient(colors: [Color(red: 0.24, green: 0.65, blue: 0.52), Color(red: 0.09, green: 0.36, blue: 0.31)], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(alignment: .trailing, spacing: width * 0.10) {
                    ForEach([0.42, 0.58, 0.34], id: \.self) { fraction in
                        Capsule().fill(.white.opacity(0.94)).frame(width: width * fraction, height: width * 0.075)
                    }
                }
                .frame(width: width * 0.58)
            }
        }
        .accessibilityHidden(true)
    }
}
