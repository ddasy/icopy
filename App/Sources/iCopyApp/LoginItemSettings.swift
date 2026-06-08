import AppKit
import Foundation
import ServiceManagement

@MainActor
final class LoginItemSettings: ObservableObject {
    @Published private(set) var isAvailable: Bool
    @Published private(set) var isEnabled: Bool
    @Published private(set) var errorMessage: String?

    init() {
        isAvailable = Self.isAppBundle
        isEnabled = Self.currentStatus()
    }

    func refresh() {
        isAvailable = Self.isAppBundle
        isEnabled = Self.currentStatus()
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }

        guard Self.isAppBundle else {
            errorMessage = "打包为 App 后才能设置开机自启。"
            isEnabled = false
            return
        }

        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
            isEnabled = Self.currentStatus()
        } catch {
            errorMessage = "无法设置开机自启。"
            isEnabled = Self.currentStatus()
        }
    }

    private static var isAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    private static func currentStatus() -> Bool {
        guard isAppBundle else { return false }
        return SMAppService.mainApp.status == .enabled
    }
}
