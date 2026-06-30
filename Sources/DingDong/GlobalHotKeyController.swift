import Carbon.HIToolbox
import Foundation

enum GlobalHotKeyState: Equatable {
    case inactive
    case registered
    case failed(OSStatus)

    func displayText(language: AppLanguage) -> String {
        switch self {
        case .inactive:
            language.text(.hotKeyInactive)
        case .registered:
            language.text(.hotKeyReady)
        case .failed:
            language.text(.hotKeyUnavailable)
        }
    }
}

final class GlobalHotKeyController: @unchecked Sendable {
    static let clipboardKeyCode = UInt32(kVK_ANSI_V)
    static let clipboardModifiers = UInt32(cmdKey | shiftKey)
    private static let hotKeySignature = fourCharCode("DDCV")
    private static let hotKeyIDValue: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let action: @MainActor @Sendable () -> Void

    init(action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> GlobalHotKeyState {
        guard hotKeyRef == nil else {
            return .registered
        }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else {
                    return noErr
                }

                guard let event,
                      let hotKeyID = GlobalHotKeyController.hotKeyID(from: event),
                      hotKeyID.signature == GlobalHotKeyController.hotKeySignature,
                      hotKeyID.id == GlobalHotKeyController.hotKeyIDValue
                else {
                    return OSStatus(eventNotHandledErr)
                }

                let controller = Unmanaged<GlobalHotKeyController>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    controller.action()
                }
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            return .failed(handlerStatus)
        }

        let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: Self.hotKeyIDValue)
        let registrationStatus = RegisterEventHotKey(
            Self.clipboardKeyCode,
            Self.clipboardModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registrationStatus == noErr else {
            if let eventHandlerRef {
                RemoveEventHandler(eventHandlerRef)
                self.eventHandlerRef = nil
            }
            hotKeyRef = nil
            return .failed(registrationStatus)
        }

        return .registered
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { result, byte in
            (result << 8) + OSType(byte)
        }
    }

    private static func hotKeyID(from event: EventRef) -> EventHotKeyID? {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        return status == noErr ? hotKeyID : nil
    }
}

@MainActor
final class ClipboardQuickPasteHotKeyController: @unchecked Sendable {
    private static let hotKeySignature = fourCharCode("DDQP")
    private static let commandModifiers = UInt32(cmdKey)
    private static let numberKeyCodes: [UInt32] = [
        UInt32(kVK_ANSI_1),
        UInt32(kVK_ANSI_2),
        UInt32(kVK_ANSI_3),
        UInt32(kVK_ANSI_4),
        UInt32(kVK_ANSI_5),
        UInt32(kVK_ANSI_6),
        UInt32(kVK_ANSI_7),
        UInt32(kVK_ANSI_8),
        UInt32(kVK_ANSI_9)
    ]

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private let action: @MainActor @Sendable (Int) -> Void

    init(action: @escaping @MainActor @Sendable (Int) -> Void) {
        self.action = action
    }

    func start() {
        guard hotKeyRefs.isEmpty else {
            return
        }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData,
                      let event,
                      let hotKeyID = ClipboardQuickPasteHotKeyController.hotKeyID(from: event),
                      hotKeyID.signature == ClipboardQuickPasteHotKeyController.hotKeySignature,
                      (1...9).contains(Int(hotKeyID.id))
                else {
                    return OSStatus(eventNotHandledErr)
                }

                let controller = Unmanaged<ClipboardQuickPasteHotKeyController>.fromOpaque(userData).takeUnretainedValue()
                let shortcutNumber = Int(hotKeyID.id)
                Task { @MainActor in
                    controller.action(shortcutNumber)
                }
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            return
        }

        for (index, keyCode) in Self.numberKeyCodes.enumerated() {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: UInt32(index + 1))
            let status = RegisterEventHotKey(
                keyCode,
                Self.commandModifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr, let hotKeyRef {
                hotKeyRefs.append(hotKeyRef)
            }
        }

        if hotKeyRefs.isEmpty {
            stop()
        }
    }

    func stop() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { result, byte in
            (result << 8) + OSType(byte)
        }
    }

    private static func hotKeyID(from event: EventRef) -> EventHotKeyID? {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        return status == noErr ? hotKeyID : nil
    }
}
