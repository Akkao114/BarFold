import Carbon
import Foundation

@MainActor
final class GlobalHotKey {
    private var handler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var currentChoice: HotKeyChoice?
    private var currentError: String?
    var action: (() -> Void)?
    var isRegistered: Bool { hotKey != nil }

    func update(_ choice: HotKeyChoice) -> String? {
        guard choice != currentChoice else { return currentError }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        currentChoice = choice
        currentError = nil
        guard choice != .disabled else { return nil }

        if handler == nil {
            var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                              EventParamType(typeEventHotKeyID), nil,
                                              MemoryLayout<EventHotKeyID>.size, nil, &identifier)
                guard result == noErr, identifier.signature == 0x42464C44, identifier.id == 1 else {
                    return OSStatus(eventNotHandledErr)
                }
                let owner = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
                Task { @MainActor in owner.action?() }
                return noErr
            }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
            guard result == noErr else {
                currentError = "无法启用全局快捷键。你仍可点击菜单栏按钮展开图标。"
                return currentError
            }
        }

        let key: UInt32
        let modifiers: UInt32
        switch choice {
        case .controlOptionB: key = UInt32(kVK_ANSI_B); modifiers = UInt32(controlKey | optionKey)
        case .controlOptionM: key = UInt32(kVK_ANSI_M); modifiers = UInt32(controlKey | optionKey)
        case .commandShiftB: key = UInt32(kVK_ANSI_B); modifiers = UInt32(cmdKey | shiftKey)
        case .disabled: return nil
        }
        let result = RegisterEventHotKey(key, modifiers, EventHotKeyID(signature: 0x42464C44, id: 1),
                                        GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr {
            currentError = result == eventHotKeyExistsErr
                ? "快捷键已被其他应用占用，请选择另一组组合键。"
                : "macOS 未能注册这组快捷键，请选择另一组组合键。"
        }
        return currentError
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
        currentChoice = nil
        currentError = nil
    }
}
