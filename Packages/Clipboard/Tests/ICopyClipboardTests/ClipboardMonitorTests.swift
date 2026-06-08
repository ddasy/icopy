import Testing
@testable import ICopyClipboard

@MainActor
@Test
func monitorRecordsTextChangeWithoutKeyIntent() {
    let pasteboard = FakePasteboard()
    let monitor = ClipboardMonitor(pasteboard: pasteboard, idleInterval: 30)
    var capturedValues: [String] = []
    monitor.onTextChange = { value in
        capturedValues.append(value)
    }

    pasteboard.setString("copied text")
    monitor.checkForChanges()

    #expect(capturedValues == ["copied text"])
}

@MainActor
@Test
func monitorIgnoresUnchangedPasteboard() {
    let pasteboard = FakePasteboard(initialString: "existing", initialChangeCount: 1)
    let monitor = ClipboardMonitor(pasteboard: pasteboard, idleInterval: 30)
    var capturedValues: [String] = []
    monitor.onTextChange = { value in
        capturedValues.append(value)
    }

    monitor.checkForChanges()

    #expect(capturedValues.isEmpty)
}

@MainActor
private final class FakePasteboard: PasteboardReading {
    private var string: String?
    private var changeCount: Int

    init(initialString: String? = nil, initialChangeCount: Int = 0) {
        self.string = initialString
        self.changeCount = initialChangeCount
    }

    func currentString() -> String? {
        string
    }

    func currentChangeCount() -> Int {
        changeCount
    }

    func setString(_ value: String?) {
        string = value
        changeCount += 1
    }
}
