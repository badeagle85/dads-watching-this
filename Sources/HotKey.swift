import AppKit
import Carbon.HIToolbox

/**
 전역 단축키 ⌥⌘L. Carbon `RegisterEventHotKey` 를 쓴다 —
 NSEvent 전역 모니터와 달리 손쉬운 사용 권한이 필요 없다.
 */
final class HotKey {
    private static let signature: OSType = 0x4457_5448 // 'DWTH'
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var eventHandler: EventHandlerRef?

    private var reference: EventHotKeyRef?
    private let id: UInt32

    init(keyCode: UInt32 = UInt32(kVK_ANSI_L),
         modifiers: UInt32 = UInt32(optionKey | cmdKey),
         action: @escaping () -> Void) {
        id = UInt32(Self.handlers.count + 1)
        Self.handlers[id] = action
        Self.installEventHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &reference)
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        Self.handlers[id] = nil
    }

    private static func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr, let action = HotKey.handlers[hotKeyID.id] else { return status }
            DispatchQueue.main.async(execute: action)
            return noErr
        }, 1, &spec, nil, &eventHandler)
    }
}
