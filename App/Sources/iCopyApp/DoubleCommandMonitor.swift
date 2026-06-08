import AppKit
import Foundation

@MainActor
final class DoubleCommandMonitor {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var isCommandDown = false
    private var lastCommandUpAt: Date?
    private let threshold: TimeInterval = 0.35
    private var action: (() -> Void)?

    func start(action: @escaping () -> Void) {
        stop()
        self.action = action

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
        lastCommandUpAt = nil
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let commandDown = flags.contains(.command)
        let onlyCommand = flags.subtracting(.command).isEmpty

        if commandDown, !isCommandDown {
            isCommandDown = true
            guard onlyCommand else { return }

            if let lastCommandUpAt, Date().timeIntervalSince(lastCommandUpAt) <= threshold {
                self.lastCommandUpAt = nil
                action?()
            }
        } else if !commandDown, isCommandDown {
            isCommandDown = false
            lastCommandUpAt = Date()
        }
    }
}
