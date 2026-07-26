import SwiftUI

struct TimerHeaderView: View {
    @EnvironmentObject private var timer: PomodoroTimerViewModel
    let metrics: AdaptiveLayoutMetrics

    var body: some View {
        VStack(spacing: 8) {
            Text("番茄钟")
                .font(.title2.weight(.semibold))

            Text(timer.statusText)
                .font(.callout)
                .foregroundStyle(timer.statusColor)
                .contentTransition(.opacity)

            if let systemNoticeText = timer.systemNoticeText {
                HStack(spacing: 6) {
                    Label(systemNoticeText, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(metrics.isCompact ? 3 : 2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("系统提示, \(systemNoticeText)")

                    Button("清除系统提示", systemImage: "xmark.circle") {
                        timer.clearSystemNotice()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("清除系统提示")
                    .accessibilityHint("隐藏当前系统提示")
                }
                .frame(maxWidth: min(320, metrics.timerColumnWidth))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: timer.systemNoticeText)
    }
}
