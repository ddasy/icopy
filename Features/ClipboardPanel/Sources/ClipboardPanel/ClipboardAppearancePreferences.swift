import Combine
import Foundation

@MainActor
public final class ClipboardAppearancePreferences: ObservableObject {
    public static let defaultPanelOpacity = 0.9
    public static let defaultTextIntensity = 0.55

    @Published public var panelOpacity: Double {
        didSet {
            panelOpacity = Self.clamp(panelOpacity)
            UserDefaults.standard.set(panelOpacity, forKey: Self.panelOpacityKey)
        }
    }

    @Published public var textIntensity: Double {
        didSet {
            textIntensity = Self.clamp(textIntensity)
            UserDefaults.standard.set(textIntensity, forKey: Self.textIntensityKey)
        }
    }

    public init() {
        let defaults = UserDefaults.standard
        let savedPanelOpacity = defaults.object(forKey: Self.panelOpacityKey) as? Double
        let savedTextIntensity = defaults.object(forKey: Self.textIntensityKey) as? Double
        panelOpacity = Self.clamp(savedPanelOpacity ?? Self.defaultPanelOpacity)
        textIntensity = Self.clamp(savedTextIntensity ?? Self.defaultTextIntensity)
    }

    public func reset() {
        panelOpacity = Self.defaultPanelOpacity
        textIntensity = Self.defaultTextIntensity
    }

    private static let panelOpacityKey = "panel.opacity"
    private static let textIntensityKey = "panel.textIntensity"

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0.1), 1.0)
    }
}
