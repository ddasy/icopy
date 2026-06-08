import Carbon
import AppKit
import Foundation

struct KeyboardShortcut: Codable, Equatable {
    let title: String
    let keyCode: UInt32
    let modifiers: UInt32

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.title = Self.title(keyCode: keyCode, modifiers: modifiers)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private static func title(keyCode: UInt32, modifiers: UInt32) -> String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        result += keyTitle(keyCode)
        return result
    }

    private static func keyTitle(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: "A"
        case kVK_ANSI_B: "B"
        case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_E: "E"
        case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"
        case kVK_ANSI_H: "H"
        case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"
        case kVK_ANSI_K: "K"
        case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"
        case kVK_ANSI_N: "N"
        case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"
        case kVK_ANSI_Q: "Q"
        case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"
        case kVK_ANSI_T: "T"
        case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"
        case kVK_ANSI_W: "W"
        case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"
        case kVK_ANSI_Z: "Z"
        case kVK_ANSI_0: "0"
        case kVK_ANSI_1: "1"
        case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"
        case kVK_ANSI_4: "4"
        case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"
        case kVK_ANSI_7: "7"
        case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_Space: "Space"
        default: "Key \(keyCode)"
        }
    }
}

enum ShortcutPreference: Equatable {
    case doubleCommand
    case hotKey(KeyboardShortcut)

    var title: String {
        switch self {
        case .doubleCommand:
            "双击 Command"
        case .hotKey(let shortcut):
            shortcut.title
        }
    }

    static func load() -> ShortcutPreference {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: "shortcut.mode") == "hotKey" else {
            return .doubleCommand
        }

        let keyCode = defaults.integer(forKey: "shortcut.keyCode")
        let modifiers = defaults.integer(forKey: "shortcut.modifiers")
        guard keyCode > 0, modifiers > 0 else {
            return .doubleCommand
        }

        return .hotKey(KeyboardShortcut(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers)))
    }

    func save() {
        let defaults = UserDefaults.standard
        switch self {
        case .doubleCommand:
            defaults.set("doubleCommand", forKey: "shortcut.mode")
            defaults.removeObject(forKey: "shortcut.keyCode")
            defaults.removeObject(forKey: "shortcut.modifiers")
        case .hotKey(let shortcut):
            defaults.set("hotKey", forKey: "shortcut.mode")
            defaults.set(Int(shortcut.keyCode), forKey: "shortcut.keyCode")
            defaults.set(Int(shortcut.modifiers), forKey: "shortcut.modifiers")
        }
    }
}
