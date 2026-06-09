import CoreGraphics
import ICopyCore
import SwiftUI

/// 锁定态嵌入桌面后,卡片本身收不到鼠标事件;视图把"可复制区域"的窗口内坐标
/// 上报给 App 层的覆盖层,由覆盖层做命中测试并触发复制。这是视图 ↔ 覆盖层的关键契约。
public struct CardCopyableRegion: Equatable, Sendable {
    public enum Payload: Equatable, Sendable {
        case section(StickyCardSection.ID)   // 手动卡片分区
        case clipboardItem(ClipboardItem.ID) // 剪贴板卡片行
    }

    public let payload: Payload
    /// 窗口内坐标(SwiftUI .global,左上原点)。覆盖层负责翻转 y 并转屏幕坐标。
    public let frame: CGRect

    public init(payload: Payload, frame: CGRect) {
        self.payload = payload
        self.frame = frame
    }
}

public struct CardCopyableRegionsKey: PreferenceKey {
    public static let defaultValue: [CardCopyableRegion] = []

    public static func reduce(value: inout [CardCopyableRegion], nextValue: () -> [CardCopyableRegion]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// 仅在锁定渲染的基础层调用(绝不在加深叠层上调用,避免重复区域)。
    func reportCopyRegion(_ payload: CardCopyableRegion.Payload) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CardCopyableRegionsKey.self,
                    value: [CardCopyableRegion(payload: payload, frame: proxy.frame(in: .global))]
                )
            }
        )
    }
}
