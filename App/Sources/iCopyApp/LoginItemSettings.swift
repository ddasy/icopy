import Foundation
import ServiceManagement

@MainActor
final class LoginItemSettings {
    private(set) var errorMessage: String?

    var isAvailable: Bool {
        Self.isAppBundle
    }

    var isEnabled: Bool {
        Self.currentStatus()
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != Self.currentStatus() else { return }

        guard Self.isAppBundle else {
            errorMessage = "打包为 App 后才能设置开机自启。"
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
        } catch {
            errorMessage = "无法设置开机自启。"
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
