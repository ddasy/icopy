import Foundation

@MainActor
public final class ClipboardMonitor {
    private let pasteboard: PasteboardReading
    private let interval: TimeInterval
    private var lastChangeCount: Int
    private var timer: Timer?

    public var onTextChange: ((String) -> Void)?

    public init(
        pasteboard: PasteboardReading,
        interval: TimeInterval = 0.6
    ) {
        self.pasteboard = pasteboard
        self.interval = interval
        self.lastChangeCount = pasteboard.currentChangeCount()
    }

    public func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChanges()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    func checkForChanges() {
        let changeCount = pasteboard.currentChangeCount()
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard let value = pasteboard.currentString() else { return }
        onTextChange?(value)
    }
}
