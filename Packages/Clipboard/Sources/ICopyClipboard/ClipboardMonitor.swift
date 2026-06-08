import AppKit
import Foundation

@MainActor
public final class ClipboardMonitor {
    private let pasteboard: PasteboardReading
    private let idleInterval: TimeInterval
    private let acceleratedInterval: TimeInterval
    private let accelerationDuration: TimeInterval
    private var lastChangeCount: Int
    private var timer: Timer?
    private var acceleratedUntil: Date?
    private var copyEventMonitor: CopyEventMonitor?

    public var onTextChange: ((String) -> Void)?

    public init(
        pasteboard: PasteboardReading,
        idleInterval: TimeInterval = 30.0,
        acceleratedInterval: TimeInterval = 0.25,
        accelerationDuration: TimeInterval = 1.5
    ) {
        self.pasteboard = pasteboard
        self.idleInterval = max(1.0, idleInterval)
        self.acceleratedInterval = max(0.1, acceleratedInterval)
        self.accelerationDuration = max(self.acceleratedInterval, accelerationDuration)
        self.lastChangeCount = pasteboard.currentChangeCount()
    }

    public func start() {
        stop()
        copyEventMonitor = CopyEventMonitor { [weak self] in
            Task { @MainActor in
                self?.accelerate()
            }
        }
        copyEventMonitor?.start()
        scheduleTimer(interval: idleInterval)
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        copyEventMonitor?.stop()
        copyEventMonitor = nil
        acceleratedUntil = nil
    }

    public func synchronize() {
        checkForChanges()
    }

    func checkForChanges() {
        let changeCount = pasteboard.currentChangeCount()
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard let value = pasteboard.currentString() else { return }
        onTextChange?(value)
    }

    private func accelerate() {
        acceleratedUntil = Date().addingTimeInterval(accelerationDuration)
        checkForChanges()
        scheduleTimer(interval: acceleratedInterval)
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        timer.tolerance = max(interval * 0.5, 0.05)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        checkForChanges()

        guard let acceleratedUntil else { return }
        if Date() >= acceleratedUntil {
            self.acceleratedUntil = nil
            scheduleTimer(interval: idleInterval)
        }
    }
}

/// 监听 Command 按下沿以触发加速采集。用 `.flagsChanged` 而非 `.keyDown`:
/// 复制必然先按下 Command,而 `.flagsChanged` 只在修饰键变化时唤醒进程,
/// 普通打字几乎零唤醒——避免逐键唤醒带来的功耗。
@MainActor
private final class CopyEventMonitor {
    private let onCopyEvent: () -> Void
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var isCommandDown = false

    init(onCopyEvent: @escaping () -> Void) {
        self.onCopyEvent = onCopyEvent
    }

    func start() {
        stop()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        isCommandDown = false
    }

    private func handle(_ event: NSEvent) {
        let commandDown = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .contains(.command)

        defer { isCommandDown = commandDown }
        guard commandDown, !isCommandDown else { return }
        onCopyEvent()
    }
}
