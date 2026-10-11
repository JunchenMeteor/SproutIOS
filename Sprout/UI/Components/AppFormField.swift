/// 表单输入字段。
/// label 左对齐（helper 字、textSecondary）；输入底 input、button 圆角、1pt 描边，
/// 错误时描边走 error 实线，焦点时叠加 focusBorder 外环；
/// 必填用"必填"文字标识而非仅靠颜色；错误文案与字段做无障碍绑定。
import SwiftUI
import UIKit

/// 通用文本表单字段。
/// iOS 没有 macOS 的 accessibilityLabeledBy，这里用
/// accessibilityElement(children: .combine) 合并 label/输入框/错误为一条朗读，
/// 并对输入框给出显式合并 label，达到等价的"错误与字段绑定"效果。
struct AppFormField: View {
    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    private let label: String
    @Binding private var text: String
    private let placeholder: String
    private let isRequired: Bool
    private let error: String?
    private let keyboardType: UIKeyboardType
    private let onSubmit: (() -> Void)?

    /// 创建表单字段。error 非 nil 时字段进入错误态并朗读错误。
    init(
        label: String,
        text: Binding<String>,
        placeholder: String = "",
        isRequired: Bool = false,
        error: String? = nil,
        keyboardType: UIKeyboardType = .default,
        onSubmit: (() -> Void)? = nil
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.isRequired = isRequired
        self.error = error
        self.keyboardType = keyboardType
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            labelRow
            inputField
            if let error {
                errorRow(error)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var labelRow: some View {
        HStack(spacing: AppSpacing.xxSmall) {
            Text(label)
                .font(AppFont.helper)
                .foregroundStyle(theme.textSecondary)
            if isRequired {
                Text("* 必填")
                    .font(AppFont.helper)
                    .foregroundStyle(theme.error.foreground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputField: some View {
        TextField(placeholder, text: $text)
            .font(AppFont.body)
            .foregroundStyle(theme.textPrimary)
            .keyboardType(keyboardType)
            .focused($isFocused)
            .padding(.horizontal, AppSpacing.small)
            .frame(minHeight: AppLayout.minTouchTarget)
            .background(theme.input)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .overlay(fieldBorder)
            .onSubmit {
                onSubmit?()
            }
            .accessibilityLabel(fieldAccessibilityLabel)
    }

    @ViewBuilder
    private var fieldBorder: some View {
        if error != nil {
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(theme.error.foreground, lineWidth: 1)
        } else if isFocused {
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(theme.focusBorder, lineWidth: 2)
        } else {
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(theme.border, lineWidth: 1)
        }
    }

    private func errorRow(_ message: String) -> some View {
        Text("错误：\(message)")
            .font(AppFont.helper)
            .foregroundStyle(theme.error.foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fieldAccessibilityLabel: String {
        var result = label
        if isRequired {
            result += "，必填"
        }
        if let error {
            result += "，错误：\(error)"
        }
        return result
    }
}


#Preview {
    struct PreviewHost: View {
        @State private var name = ""
        @State private var email = "bad-input"

        var body: some View {
            VStack(spacing: AppSpacing.medium) {
                AppFormField(label: "孩子昵称", text: $name, placeholder: "请输入昵称", isRequired: true)
                AppFormField(
                    label: "家长邮箱",
                    text: $email,
                    error: "邮箱格式不正确",
                    keyboardType: .emailAddress
                )
            }
            .padding(AppSpacing.medium)
        }
    }
    return PreviewHost()
}
