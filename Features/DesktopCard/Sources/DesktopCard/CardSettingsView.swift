import ICopyCore
import SwiftUI

/// 单张卡片的设置面板(齿轮按钮打开):内容模式、透明度、字体(大小/字重/字族)、颜色(预设盘+强度)。
/// 通过 appearance 绑定直接改卡片,触发去抖持久化;"恢复默认"仅作用于本卡片。
public struct CardSettingsView: View {
    @Binding var appearance: StickyCardAppearance
    let contentMode: StickyCardContentMode
    let onChangeMode: (StickyCardContentMode) -> Void
    let onReset: () -> Void

    public init(
        appearance: Binding<StickyCardAppearance>,
        contentMode: StickyCardContentMode,
        onChangeMode: @escaping (StickyCardContentMode) -> Void,
        onReset: @escaping () -> Void
    ) {
        _appearance = appearance
        self.contentMode = contentMode
        self.onChangeMode = onChangeMode
        self.onReset = onReset
    }

    private static let fontFamilies: [(label: String, value: String?)] = [
        ("系统", nil),
        ("等宽", "Menlo"),
        ("圆体", "PingFang SC"),
        ("衬线", "Songti SC")
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("卡片设置")
                .font(.system(size: 14, weight: .semibold))

            modeRow

            Divider()

            slider("透明度", value: $appearance.opacity, range: 0.1...1.0)
            slider("字号", value: $appearance.fontSize, range: 8...48, unit: "pt")
            slider("文字强度", value: $appearance.textIntensity, range: 0.1...1.0)

            weightRow
            familyRow
            colorRow

            Divider()

            HStack {
                Button("恢复默认", action: onReset)
                Spacer()
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private var modeRow: some View {
        HStack {
            Text("内容").font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: Binding(get: { contentMode }, set: { onChangeMode($0) })) {
                Text("手动").tag(StickyCardContentMode.manual)
                Text("剪贴板").tag(StickyCardContentMode.clipboard)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)
        }
    }

    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String = "") -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
            Slider(value: value, in: range)
            Text(unit.isEmpty ? String(format: "%.0f%%", value.wrappedValue * 100) : String(format: "%.0f%@", value.wrappedValue, unit))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var weightRow: some View {
        HStack {
            Text("字重").font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
            Picker("", selection: $appearance.fontWeight) {
                Text("常规").tag(StickyCardFontWeight.regular)
                Text("中").tag(StickyCardFontWeight.medium)
                Text("半粗").tag(StickyCardFontWeight.semibold)
                Text("粗").tag(StickyCardFontWeight.bold)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var familyRow: some View {
        HStack {
            Text("字体").font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
            Picker("", selection: Binding(
                get: { appearance.fontFamily ?? "" },
                set: { appearance.fontFamily = $0.isEmpty ? nil : $0 }
            )) {
                ForEach(Self.fontFamilies, id: \.label) { entry in
                    Text(entry.label).tag(entry.value ?? "")
                }
            }
            .labelsHidden()
        }
    }

    private var colorRow: some View {
        HStack(alignment: .top) {
            Text("颜色").font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 8), count: 4), spacing: 8) {
                ForEach(StickyCardColorPreset.palette) { preset in
                    swatch(preset)
                }
            }
        }
    }

    private func swatch(_ preset: StickyCardColorPreset) -> some View {
        let selected = appearance.textColor == preset.color
        return Circle()
            .fill(preset.color.swiftUI)
            .frame(width: 22, height: 22)
            .overlay(
                Circle().strokeBorder(Color.accentColor, lineWidth: selected ? 2.5 : 0)
            )
            .overlay(
                Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
            )
            .contentShape(Circle())
            .onTapGesture { appearance.textColor = preset.color }
            .help(preset.name)
    }
}
