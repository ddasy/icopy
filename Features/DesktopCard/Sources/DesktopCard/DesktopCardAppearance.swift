import ICopyCore
import SwiftUI

/// 把 Core 的纯数据外观映射到 SwiftUI 类型(Core 不依赖 UI,映射只能放在这里)。
extension StickyCardFontWeight {
    var swiftUI: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}

extension StickyCardColor {
    var swiftUI: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension StickyCardAppearance {
    var swiftUIFont: Font {
        if let family = fontFamily, !family.isEmpty {
            return Font.custom(family, size: fontSize).weight(fontWeight.swiftUI)
        }
        return Font.system(size: fontSize, weight: fontWeight.swiftUI)
    }

    /// 文本色叠加 intensity(强度作为不透明度;透明度滑块只作用于材质/边框,文本保持清晰)。
    var swiftUITextColor: Color {
        textColor.swiftUI.opacity(textIntensity)
    }
}

/// 颜色预设盘(决策:预设盘 + 强度滑块)。预设是 UI 关注点,故放在 Features 层。
public struct StickyCardColorPreset: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let color: StickyCardColor

    public init(id: String, name: String, color: StickyCardColor) {
        self.id = id
        self.name = name
        self.color = color
    }

    public static let palette: [StickyCardColorPreset] = [
        .init(id: "ink", name: "墨黑", color: StickyCardColor(red: 0.1, green: 0.1, blue: 0.1)),
        .init(id: "slate", name: "石板", color: StickyCardColor(red: 0.30, green: 0.34, blue: 0.42)),
        .init(id: "red", name: "朱红", color: StickyCardColor(red: 0.78, green: 0.16, blue: 0.16)),
        .init(id: "orange", name: "橙", color: StickyCardColor(red: 0.85, green: 0.45, blue: 0.10)),
        .init(id: "green", name: "松绿", color: StickyCardColor(red: 0.16, green: 0.50, blue: 0.30)),
        .init(id: "blue", name: "靛蓝", color: StickyCardColor(red: 0.16, green: 0.36, blue: 0.72)),
        .init(id: "purple", name: "紫", color: StickyCardColor(red: 0.45, green: 0.26, blue: 0.62))
    ]
}
