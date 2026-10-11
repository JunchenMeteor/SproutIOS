/// 录音核心控件。
/// 居中布局：大圆形主按钮驱动录制/停止，副按钮处理回放与重录；
/// 状态色走 recording 色组，时长用等宽数字 mm:ss；
/// uploading 用不定值 ProgressView，禁止假百分比与假波形。
/// 组件不 import 录音服务，只通过回调与外界通信。
import SwiftUI

/// 录音控件状态输入（与录音服务状态机解耦，由页面适配转换）。
enum RecorderControlState: Equatable {
    /// 待录制。
    case idle
    /// 录制中，携带已录时长（秒）。
    case recording(duration: TimeInterval)
    /// 被来电等系统事件中断。
    case interrupted
    /// 录制完成，携带总时长（秒）。
    case recorded(duration: TimeInterval)
    /// 上传中（不定值，无进度数据）。
    case uploading
    /// 失败，携带中文原因。
    case failed(message: String)
}


/// 录音核心视图。
/// 输入 state 与 isPlaybackAvailable；输出 onRecord/onStop/onPlay/onDiscard 四个回调。
struct RecorderControl: View {
    /// 主按钮直径，大于最小触控尺寸 48，便于儿童点按。
    private static let mainButtonDiameter: CGFloat = 72

    @Environment(\.theme) private var theme

    private let state: RecorderControlState
    private let isPlaybackAvailable: Bool
    private let onRecord: () -> Void
    private let onStop: () -> Void
    private let onPlay: () -> Void
    private let onDiscard: () -> Void

    /// 创建录音控件。所有动作经回调透出，组件自身不持有录音状态。
    init(
        state: RecorderControlState,
        isPlaybackAvailable: Bool = false,
        onRecord: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onPlay: @escaping () -> Void,
        onDiscard: @escaping () -> Void
    ) {
        self.state = state
        self.isPlaybackAvailable = isPlaybackAvailable
        self.onRecord = onRecord
        self.onStop = onStop
        self.onPlay = onPlay
        self.onDiscard = onDiscard
    }

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            statusContent
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var statusContent: some View {
        switch state {
        case .idle:
            mainButton(icon: "mic.fill", label: "开始录音", isActive: false, action: onRecord)
        case .recording(let duration):
            mainButton(icon: "stop.fill", label: "停止", isActive: true, action: onStop)
            durationText(duration)
        case .interrupted:
            interruptedContent
        case .recorded(let duration):
            durationText(duration)
            recordedActions
        case .uploading:
            uploadingContent
        case .failed(let message):
            failedContent(message)
        }
    }

    private func mainButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: AppSpacing.xSmall) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(AppFont.section)
                    .foregroundStyle(isActive ? theme.recording.activeIcon : theme.recording.idleForeground)
                    .frame(width: Self.mainButtonDiameter, height: Self.mainButtonDiameter)
                    .background(isActive ? theme.recording.activeBackground : theme.recording.idleBackground)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isActive ? theme.recording.activeBorder : theme.recording.idleBorder, lineWidth: 2)
                    )
            }
            .accessibilityLabel(label)
            Text(label)
                .font(AppFont.helper)
                .foregroundStyle(isActive ? theme.recording.activeForeground : theme.recording.idleForeground)
        }
    }

    private func durationText(_ duration: TimeInterval) -> some View {
        Text(Self.formatDuration(duration))
            .font(AppFont.section)
            .monospacedDigit()
            .foregroundStyle(theme.textPrimary)
    }

    private var interruptedContent: some View {
        VStack(spacing: AppSpacing.medium) {
            Label("录音被来电中断，请重新录制或继续", systemImage: "exclamationmark.triangle.fill")
                .font(AppFont.body)
                .foregroundStyle(theme.warning.foreground)
            AppButton("重新录制", kind: .secondary, action: onRecord)
        }
    }

    private var recordedActions: some View {
        HStack(spacing: AppSpacing.medium) {
            secondaryAction(icon: "play.fill", label: "回放", isEnabled: isPlaybackAvailable, action: onPlay)
            secondaryAction(icon: "arrow.counterclockwise", label: "重录", isEnabled: true, action: onDiscard)
        }
    }

    /* 上传无进度数据，只展示不定值指示器，不做假百分比。 */
    private var uploadingContent: some View {
        VStack(spacing: AppSpacing.small) {
            ProgressView()
                .tint(theme.iconPrimary)
            Text("上传中，请稍候")
                .font(AppFont.helper)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func failedContent(_ message: String) -> some View {
        VStack(spacing: AppSpacing.medium) {
            Label(message, systemImage: "xmark.octagon.fill")
                .font(AppFont.body)
                .foregroundStyle(theme.error.foreground)
            AppButton("重试", kind: .secondary, action: onRecord)
        }
    }

    private func secondaryAction(
        icon: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xSmall) {
                Image(systemName: icon)
                Text(label)
                    .font(AppFont.body)
            }
            .padding(.horizontal, AppSpacing.medium)
            .frame(minHeight: AppLayout.minTouchTarget)
            .foregroundStyle(isEnabled ? theme.buttonSecondaryForeground : theme.disabledForeground)
            .background(isEnabled ? theme.buttonSecondaryBackground : theme.disabledBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .stroke(isEnabled ? theme.buttonSecondaryBorder : theme.disabledBorder, lineWidth: 1)
            )
        }
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}


#Preview {
    VStack(spacing: AppSpacing.xLarge) {
        RecorderControl(state: .idle, onRecord: {}, onStop: {}, onPlay: {}, onDiscard: {})
        RecorderControl(
            state: .recording(duration: 65),
            onRecord: {},
            onStop: {},
            onPlay: {},
            onDiscard: {}
        )
        RecorderControl(
            state: .recorded(duration: 42),
            isPlaybackAvailable: true,
            onRecord: {},
            onStop: {},
            onPlay: {},
            onDiscard: {}
        )
    }
    .padding(AppSpacing.medium)
}
