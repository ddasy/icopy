import AppKit

@MainActor
public protocol PasteboardReading {
    func currentString() -> String?
    func currentChangeCount() -> Int
}

@MainActor
public protocol PasteboardWriting {
    func writeString(_ value: String)
}

@MainActor
public struct SystemPasteboardClient: PasteboardReading, PasteboardWriting {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func currentString() -> String? {
        pasteboard.string(forType: .string)
    }

    public func currentChangeCount() -> Int {
        pasteboard.changeCount
    }

    public func writeString(_ value: String) {
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }
}
