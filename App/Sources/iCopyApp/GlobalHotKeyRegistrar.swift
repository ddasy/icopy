import Carbon
import Foundation

@MainActor
final class GlobalHotKeyRegistrar {
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var action: (() -> Void)?

    init() {
        installEventHandler()
    }

    func register(shortcut: KeyboardShortcut, action: @escaping () -> Void) {
        unregister()
        self.action = action

        let hotKeyID = EventHotKeyID(
            signature: OSType(0x69436F70),
            id: 1
        )

        RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                DispatchQueue.main.async {
                    let registrar = Unmanaged<GlobalHotKeyRegistrar>
                        .fromOpaque(userData)
                        .takeUnretainedValue()
                    registrar.action?()
                }
                return noErr
            },
            1,
            &eventType,
            context,
            &eventHandlerRef
        )
    }
}
