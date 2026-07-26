import SwiftUI

#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var timer: PomodoroTimerViewModel
    @EnvironmentObject private var appActivityMonitor: AppActivityMonitor
    @AppStorage(VoiceGender.defaultsKey) private var voiceGender = VoiceGender.female.rawValue
    @State private var avatarGender = VoiceGender.current
    @State private var avatarPresentation = DigitalAvatarPresentation.docked
    @State private var isAvatarVisible = true
    @State private var avatarSequence = 0
    @State private var showingSettings = false
    @StateObject private var avatarSpeechController = AvatarSpeechController()

    var body: some View {
        GeometryReader { proxy in
            let metrics = AdaptiveLayoutMetrics(size: proxy.size, dynamicTypeSize: dynamicTypeSize)

            Group {
                if metrics.isCompact {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: metrics.sectionSpacing) {
                            TimerColumnView(
                                metrics: metrics,
                                voiceGender: $voiceGender,
                                onVoiceGenderChange: handleVoiceGenderChange
                            )
                            AvatarSectionView(
                                gender: avatarGender,
                                presentation: avatarPresentation,
                                isVisible: isAvatarVisible,
                                metrics: metrics
                            )
                        }
                        .frame(maxWidth: metrics.maxContentWidth)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        HStack(alignment: .center, spacing: metrics.sectionSpacing) {
                            TimerColumnView(
                                metrics: metrics,
                                voiceGender: $voiceGender,
                                onVoiceGenderChange: handleVoiceGenderChange
                            )
                                .frame(width: metrics.timerColumnWidth)

                            AvatarSectionView(
                                gender: avatarGender,
                                presentation: avatarPresentation,
                                isVisible: isAvatarVisible,
                                metrics: metrics
                            )
                        }
                        .frame(maxWidth: metrics.maxContentWidth)
                        .frame(maxWidth: .infinity, minHeight: max(0, proxy.size.height - metrics.verticalPadding * 2))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 560)
        #endif
        .background(Self.windowBackgroundColor)
        .timerSensoryFeedback(state: timer.state)
        #if os(macOS)
        .background(macKeyboardShortcuts)
        #endif
        .onAppear {
            appActivityMonitor.refresh()
            avatarGender = VoiceGender(rawValue: voiceGender) ?? .female
            avatarPresentation = .docked
            isAvatarVisible = true
            SpeechNotifier.logConfiguredVoices()
        }
        #if os(iOS)
        .overlay(alignment: .topTrailing) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("设置")
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .environmentObject(timer)
                    .navigationTitle("设置")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showingSettings = false }
                        }
                    }
            }
        }
        .onChange(of: timer.state) { _, newState in
            announceTimerState(newState)
            let snapshot = timer.liveActivitySnapshot
            Task { await LiveActivityController.sync(snapshot) }
        }
        .onChange(of: timer.liveActivityEndDate) { _, _ in
            let snapshot = timer.liveActivitySnapshot
            Task { await LiveActivityController.sync(snapshot) }
        }
        #endif
    }

    private static var windowBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    private func handleVoiceGenderChange(_ rawValue: String) {
        guard let gender = VoiceGender(rawValue: rawValue) else { return }

        avatarSequence += 1
        let sequence = avatarSequence
        NotificationCenter.default.post(name: .voiceGenderDidChange, object: nil)
        SpeechNotifier.logConfiguredVoices()

        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
            isAvatarVisible = false
        }

        Task { @MainActor in
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(120))
            }

            guard sequence == avatarSequence else { return }

            avatarGender = gender
            avatarPresentation = .introducing
            withAnimation(reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.86)) {
                isAvatarVisible = true
            }

            avatarSpeechController.notifier.playSelfIntro(gender: gender)
            avatarSpeechController.notifier.runAfterCurrentSpeech {
                guard sequence == avatarSequence else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.9)) {
                    avatarPresentation = .docked
                }
            }
        }
    }

    #if os(macOS)
    private var macKeyboardShortcuts: some View {
        ZStack {
            Button("开始或暂停", action: togglePrimary)
                .keyboardShortcut(.space, modifiers: [])
            Button("重置", action: timer.reset)
                .keyboardShortcut("r", modifiers: [])
            Button("跳过休息", action: timer.skipBreak)
                .keyboardShortcut("s", modifiers: [])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func togglePrimary() {
        switch timer.state {
        case .idle:
            timer.start()
        case .running:
            timer.pause()
        case .paused:
            timer.resume()
        case .breaking:
            timer.skipBreak()
        }
    }
    #endif

    private func announceTimerState(_ state: PomodoroTimerState) {
        #if os(iOS)
        let announcement: String
        switch state {
        case .idle:
            announcement = "番茄钟未开始"
        case .running:
            announcement = "番茄钟开始"
        case .paused:
            announcement = "番茄钟已暂停"
        case .breaking:
            announcement = "开始休息"
        }
        UIAccessibility.post(notification: .announcement, argument: announcement)
        #endif
    }

}

struct FocusDayStat: Codable, Identifiable {
    let day: String
    var count: Int
    var focusSeconds: Int

    var id: String { day }
}

@MainActor
final class FocusStatsStore: ObservableObject {
    @Published private(set) var days: [String: FocusDayStat]

    private let defaults: UserDefaults
    private let now: () -> Date
    private let storageKey = "focusStats.days.v1"
    private let calendar = Calendar.current

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: FocusDayStat].self, from: data) {
            days = decoded
        } else {
            days = [:]
        }
    }

    func record(focusSeconds: Int) {
        guard focusSeconds > 0 else { return }
        let key = Self.dayFormatter.string(from: now())
        var stat = days[key] ?? FocusDayStat(day: key, count: 0, focusSeconds: 0)
        stat.count += 1
        stat.focusSeconds += focusSeconds
        days[key] = stat
        persist()
    }

    var todayCount: Int {
        days[Self.dayFormatter.string(from: now())]?.count ?? 0
    }

    var todayFocusMinutes: Int {
        (days[Self.dayFormatter.string(from: now())]?.focusSeconds ?? 0) / 60
    }

    var totalCount: Int {
        days.values.reduce(0) { $0 + $1.count }
    }

    var currentStreak: Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: now())
        while let stat = days[Self.dayFormatter.string(from: cursor)], stat.count > 0 {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    func recentDays(_ count: Int) -> [FocusDayStat] {
        let today = calendar.startOfDay(for: now())
        return (0..<count).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let key = Self.dayFormatter.string(from: date)
            return days[key] ?? FocusDayStat(day: key, count: 0, focusSeconds: 0)
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(days) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

struct FocusStatsView: View {
    @EnvironmentObject private var stats: FocusStatsStore

    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("专注战绩", systemImage: "trophy.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TimerPalette.statsAccent)

            HStack(spacing: 10) {
                statTile(value: "\(stats.todayCount)", unit: "个", caption: "今日番茄")
                statTile(value: "\(stats.todayFocusMinutes)", unit: "分", caption: "今日专注")
                statTile(value: "\(stats.currentStreak)", unit: "天", caption: "连续打卡")
                statTile(value: "\(stats.totalCount)", unit: "个", caption: "累计")
            }

            weekChart
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.quaternary.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(TimerPalette.statsAccent.opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "专注战绩,今日\(stats.todayCount)个番茄,专注\(stats.todayFocusMinutes)分钟,"
                + "连续打卡\(stats.currentStreak)天,累计\(stats.totalCount)个"
        )
    }

    private func statTile(value: String, unit: String, caption: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var weekChart: some View {
        let recent = stats.recentDays(7)
        let peak = max(1, recent.map(\.count).max() ?? 1)
        let calendar = Calendar.current

        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(recent) { day in
                let weekday = weekdayLabel(for: day.day, calendar: calendar)
                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        Capsule()
                            .fill(.quaternary)
                            .frame(width: 10, height: 40)
                        Capsule()
                            .fill(day.count > 0 ? AnyShapeStyle(TimerPalette.statsAccent) : AnyShapeStyle(Color.clear))
                            .frame(width: 10, height: max(4, 40 * CGFloat(day.count) / CGFloat(peak)))
                    }
                    Text(weekday)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func weekdayLabel(for dayKey: String, calendar: Calendar) -> String {
        guard let date = FocusStatsView.keyFormatter.date(from: dayKey) else { return "" }
        let index = calendar.component(.weekday, from: date) - 1
        return weekdaySymbols[safe: index] ?? ""
    }

    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct TimerSensoryFeedbackModifier: ViewModifier {
    let state: PomodoroTimerState

    func body(content: Content) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            content.sensoryFeedback(trigger: state) { _, newState in
                switch newState {
                case .running:
                    return .impact(weight: .medium)
                case .paused:
                    return .impact(weight: .light, intensity: 0.7)
                case .breaking:
                    return .success
                case .idle:
                    return .impact(flexibility: .soft, intensity: 0.55)
                }
            }
        } else {
            content
        }
    }
}

private extension View {
    func timerSensoryFeedback(state: PomodoroTimerState) -> some View {
        modifier(TimerSensoryFeedbackModifier(state: state))
    }
}

#Preview {
    ContentView()
        .environmentObject(PomodoroTimerViewModel())
        .environmentObject(AppActivityMonitor())
        .environmentObject(FocusStatsStore())
}
