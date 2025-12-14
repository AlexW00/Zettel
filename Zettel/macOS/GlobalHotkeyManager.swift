//
//  GlobalHotkeyManager.swift
//  zettel-desktop
//
//  Created by Codex on 26.10.25.
//

import Carbon

final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    var activationHandler: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {}

    func registerDefaultHotkey() {
        register(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(controlKey | optionKey | cmdKey))
    }

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()
        var hotKeyID = EventHotKeyID(signature: OSType(UInt32(bigEndian: 0x5A544C4E)), id: 1) // 'ZTLN'
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        guard status == noErr else { return }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { (_, event, userData) in
            guard let userData else { return noErr }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.activationHandler?()
            return noErr
        }, 1, &eventSpec, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &eventHandler)
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
    }

    deinit {
        unregister()
    }
}
