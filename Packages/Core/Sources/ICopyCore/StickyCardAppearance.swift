import Foundation

public enum StickyCardFontWeight: String, Codable, CaseIterable, Sendable {
    case regular, medium, semibold, bold   // UI 层映射到 Font.Weight
}

/// 纯 RGBA,无 SwiftUI Color。UI 层映射到 Color(.sRGB, ...)。
public struct StickyCardColor: Codable, Equatable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red.clampedUnit
        self.green = green.clampedUnit
        self.blue = blue.clampedUnit
        self.alpha = alpha.clampedUnit
    }

    /// 默认主文本色(深色,接近系统 label)。
    public static let primaryLabel = StickyCardColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
}

public struct StickyCardAppearance: Codable, Equatable, Hashable, Sendable {
    public var opacity: Double         // 0.1...1.0(下限 0.1,防 Window Server 把全透明当穿透)
    public var fontSize: Double        // 磅
    public var fontWeight: StickyCardFontWeight
    public var fontFamily: String?     // nil = 系统字体
    public var textColor: StickyCardColor
    public var textIntensity: Double   // 0.1...1.0,文本加深/淡化,独立于 alpha

    public init(
        opacity: Double = 1.0,
        fontSize: Double = 14,
        fontWeight: StickyCardFontWeight = .regular,
        fontFamily: String? = nil,
        textColor: StickyCardColor = .primaryLabel,
        textIntensity: Double = 1.0
    ) {
        self.opacity = opacity.clamped(to: 0.1...1.0)
        self.fontSize = fontSize.clamped(to: 8...48)
        self.fontWeight = fontWeight
        self.fontFamily = fontFamily
        self.textColor = textColor
        self.textIntensity = textIntensity.clamped(to: 0.1...1.0)
    }

    public static let `default` = StickyCardAppearance()
}

extension Double {
    fileprivate var clampedUnit: Double { clamped(to: 0...1) }

    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
