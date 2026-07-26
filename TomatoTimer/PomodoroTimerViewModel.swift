import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#endif
@MainActor
final class PomodoroTimerViewModel: ObservableObject {
    let availableMinutes = [5, 15, 25, 45]

    @Published private(set) var snapshot = TimerSnapshot()
    @Published private(set) var systemNoticeText: String?

    private var endDate: Date?
    private var breakEndDate: Date?
    private var tickTimer: Timer?
    private var isTickQueued = false
    private var pendingSnapshot: TimerSnapshot?
    private var isSnapshotPublishQueued = false
    private var appActivityObservers: [NSObjectProtocol] = []
    private var currentTickInterval: TimeInterval?
    private var breakSessionID = 0
    private var pendingScreenSleepRequest: ScreenSleepRequest?
    private var hasSpokenReminder = false
    private var hasSpokenFinalMinute = false
    private var spokenProgressMilestones: Set<Int> = []
    private var progressEncouragementIndex = 0
    private var isDisplaySleepAssertionActive = false
    private let speechNotifier: SpeechNotifying
    private let sleepAssertion: DisplaySleepControlling
    private let screenSleeper: ScreenSleepControlling
    private let notificationScheduler: TimerNotificationControlling
    private let presentBreakAttention: (@MainActor @Sendable () -> Void)?
    private let onFocusSessionCompleted: (@MainActor @Sendable (Int) -> Void)?

    #if os(macOS)
    private var breakActivity: NSObjectProtocol?
    #endif

    private var breakTotalSeconds: TimeInterval = 5 * 60
    private let progressSpeechMinimumDuration: TimeInterval = 10 * 60
    private let progressMilestoneInterval = 5 * 60
    private let foregroundTickInterval: TimeInterval = 0.25
    private let backgroundTickInterval: TimeInterval = 1.0
    private let progressEncouragements = [
        "太厉害啦,这个节奏世界首富稳了",
        "好棒好棒,首富宝座在向你招手哦",
        "专注的你最有魅力,继续冲呀未来首富",
        "稳住稳住,离世界首富又近一步啦",
        "哇你也太能扛了,亿万身家等着你呢",
        "再加把劲,未来首富我可看好你哦",
        "你已经超神啦,首富不是你还能是谁",
        "继续保持,小钱钱正在向你飞来呀"
    ]
    private let notificationCenter: NotificationCenter
    private let defaults: UserDefaults

    init(
        notificationCenter: NotificationCenter = .default,
        speechNotifier: SpeechNotifying = SpeechNotifier(),
        sleepAssertion: DisplaySleepControlling = DisplaySleepAssertion(),
        screenSleeper: ScreenSleepControlling = SystemScreenSleeper(),
        notificationScheduler: TimerNotificationControlling = TimerNotificationScheduler(),
        userDefaults: UserDefaults = .standard,
        presentBreakAttention: (@MainActor @Sendable () -> Void)? = nil,
        onFocusSessionCompleted: (@MainActor @Sendable (Int) -> Void)? = nil
    ) {
        self.notificationCenter = notificationCenter
        self.defaults = userDefaults
        self.speechNotifier = speechNotifier
        self.sleepAssertion = sleepAssertion
        self.screenSleeper = screenSleeper
        self.notificationScheduler = notificationScheduler
        self.presentBreakAttention = presentBreakAttention
        self.onFocusSessionCompleted = onFocusSessionCompleted

        #if os(macOS)
        appActivityObservers = [
            notificationCenter.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppActivityChange()
                }
            },
            notificationCenter.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppActivityChange()
                }
            }
        ]
        #endif

        // Restore the last duration the user picked, so the app doesn't reset to
        // 25:00 on every launch.
        if let saved = savedSelectedDuration() {
            applySelectedDuration(totalSeconds: saved, selectedPresetMinutes: nil, to: &snapshot)
        }

        // Restore the configured break length and reflect it in the idle snapshot.
        breakTotalSeconds = savedBreakDuration()
        snapshot.breakTotalSeconds = breakTotalSeconds
        snapshot.breakRemainingSeconds = breakTotalSeconds

        // Restore a live session that survived app termination, so the UI matches
        // reality (and any pending notifications) instead of showing idle.
        applyRestorationIfNeeded()
    }

    private static let restorationStateKey = "timerRestorationState.v1"

    private func saveRestorationState() {
        let stateID: String?
        switch snapshot.state {
        case .running: stateID = "running"
        case .paused: stateID = "paused"
        case .breaking: stateID = "breaking"
        case .idle: stateID = nil
        }

        guard let stateID else {
            defaults.removeObject(forKey: Self.restorationStateKey)
            return
        }

        let record = TimerRestorationState(
            stateID: stateID,
            endDate: endDate,
            breakEndDate: breakEndDate,
            remainingSeconds: snapshot.remainingSeconds,
            sessionTotalSeconds: snapshot.sessionTotalSeconds,
            breakTotalSeconds: snapshot.breakTotalSeconds
        )
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: Self.restorationStateKey)
        }
    }

    private func applyRestorationIfNeeded() {
        let record = (defaults.data(forKey: Self.restorationStateKey)).flatMap {
            try? JSONDecoder().decode(TimerRestorationState.self, from: $0)
        }

        switch TimerRestorationOutcome.resolve(record, now: Date.now) {
        case .none:
            defaults.removeObject(forKey: Self.restorationStateKey)
        case let .running(endDate, sessionTotalSeconds):
            self.endDate = endDate
            snapshot.state = .running
            snapshot.remainingSeconds = max(0, endDate.timeIntervalSinceNow)
            snapshot.sessionTotalSeconds = sessionTotalSeconds
            acquireDisplaySleepAssertion()
            scheduleRunningTimerNotifications()
            startTicking()
        case let .paused(remainingSeconds, sessionTotalSeconds):
            snapshot.state = .paused
            snapshot.remainingSeconds = remainingSeconds
            snapshot.sessionTotalSeconds = sessionTotalSeconds
        case let .breaking(breakEndDate, breakTotalSeconds):
            self.breakEndDate = breakEndDate
            snapshot.state = .breaking
            snapshot.breakRemainingSeconds = max(0, breakEndDate.timeIntervalSinceNow)
            snapshot.breakTotalSeconds = breakTotalSeconds
            beginBreakActivity()
            scheduleBreakFinishedNotification()
            startTicking()
        }
    }

    var state: PomodoroTimerState {
        currentSnapshot.state
    }

    var canEditDuration: Bool {
        currentSnapshot.state == .idle
    }

    var canStart: Bool {
        canEditDuration && currentSnapshot.selectedTotalSeconds > 0
    }

    var canAdjustCountdown: Bool {
        currentSnapshot.state == .running || currentSnapshot.state == .paused
    }

    var canSkipBreak: Bool {
        currentSnapshot.state == .breaking
    }

    var selectedPresetMinutes: Int? {
        currentSnapshot.selectedPresetMinutes
    }

    var selectedHours: Int {
        currentSnapshot.selectedTotalSeconds / 3600
    }

    var selectedMinutesComponent: Int {
        (currentSnapshot.selectedTotalSeconds % 3600) / 60
    }

    var selectedSecondsComponent: Int {
        currentSnapshot.selectedTotalSeconds % 60
    }

    var selectedDurationText: String {
        if currentSnapshot.state == .breaking {
            return "休息 \(formatDuration(seconds: currentSnapshot.breakTotalSeconds))"
        }

        return formatDuration(seconds: TimeInterval(currentSnapshot.selectedTotalSeconds))
    }

    var progress: Double {
        let snapshot = currentSnapshot
        if snapshot.state == .breaking {
            guard snapshot.breakTotalSeconds > 0 else { return 0 }
            return min(1, max(0, 1 - snapshot.breakRemainingSeconds / snapshot.breakTotalSeconds))
        }

        guard snapshot.sessionTotalSeconds > 0 else { return 0 }
        return min(1, max(0, 1 - snapshot.remainingSeconds / snapshot.sessionTotalSeconds))
    }

    var remainingTimeText: String {
        let snapshot = currentSnapshot
        if snapshot.state == .breaking {
            return formatClock(seconds: snapshot.breakRemainingSeconds, showsHours: false)
        }

        let shouldShowHours = snapshot.selectedTotalSeconds >= 3600 || snapshot.remainingSeconds >= 3600
        return formatClock(seconds: snapshot.remainingSeconds, showsHours: shouldShowHours)
    }

    var statusText: String {
        switch currentSnapshot.state {
        case .idle:
            return "未开始"
        case .running:
            return "进行中"
        case .paused:
            return "已暂停"
        case .breaking:
            return "休息中"
        }
    }

    var statusColor: Color {
        switch currentSnapshot.state {
        case .idle:
            return .secondary
        case .running:
            return .green
        case .paused:
            return .orange
        case .breaking:
            return .blue
        }
    }

    /// Absolute end instant of the active phase, or `nil` when idle/paused.
    /// Used purely as a cheap change signal to re-sync the Live Activity.
    var liveActivityEndDate: Date? {
        switch currentSnapshot.state {
        case .running:
            return endDate
        case .breaking:
            return breakEndDate
        case .idle, .paused:
            return nil
        }
    }

    /// Snapshot fed to the Live Activity. `nil` while idle (no activity shown).
    var liveActivitySnapshot: LiveActivitySnapshot? {
        let snapshot = currentSnapshot
        switch snapshot.state {
        case .idle:
            return nil
        case .running:
            guard let endDate else { return nil }
            let total = TimeInterval(snapshot.sessionTotalSeconds)
            return LiveActivitySnapshot(
                phase: "专注中",
                isBreak: false,
                isPaused: false,
                startDate: endDate.addingTimeInterval(-total),
                endDate: endDate,
                remainingSeconds: Int(snapshot.remainingSeconds)
            )
        case .paused:
            let remaining = snapshot.remainingSeconds
            let now = Date.now
            let elapsed = max(0, TimeInterval(snapshot.sessionTotalSeconds) - remaining)
            return LiveActivitySnapshot(
                phase: "已暂停",
                isBreak: false,
                isPaused: true,
                startDate: now.addingTimeInterval(-elapsed),
                endDate: now.addingTimeInterval(remaining),
                remainingSeconds: Int(remaining)
            )
        case .breaking:
            guard let breakEndDate else { return nil }
            let total = snapshot.breakTotalSeconds
            return LiveActivitySnapshot(
                phase: "休息中",
                isBreak: true,
                isPaused: false,
                startDate: breakEndDate.addingTimeInterval(-total),
                endDate: breakEndDate,
                remainingSeconds: Int(snapshot.breakRemainingSeconds)
            )
        }
    }

    func clearSystemNotice() {
        systemNoticeText = nil
    }

    func selectPreset(minutes: Int) {
        guard canEditDuration else { return }
        enqueueSelectedDuration(totalSeconds: minutes * 60, selectedPresetMinutes: minutes)
    }

    func setHours(_ hours: Int) {
        guard canEditDuration else { return }
        let clampedHours = min(23, max(0, hours))
        enqueueSelectedDuration(
            totalSeconds: clampedHours * 3600 + selectedMinutesComponent * 60 + selectedSecondsComponent
        )
    }

    func setMinutesComponent(_ minutes: Int) {
        guard canEditDuration else { return }
        let clampedMinutes = min(59, max(0, minutes))
        enqueueSelectedDuration(
            totalSeconds: selectedHours * 3600 + clampedMinutes * 60 + selectedSecondsComponent
        )
    }

    func setSecondsComponent(_ seconds: Int) {
        guard canEditDuration else { return }
        let clampedSeconds = min(59, max(0, seconds))
        enqueueSelectedDuration(
            totalSeconds: selectedHours * 3600 + selectedMinutesComponent * 60 + clampedSeconds
        )
    }

    func start() {
        flushPendingSnapshot()
        guard canStart else { return }

        speechNotifier.stop()
        clearSystemNotice()
        notificationScheduler.prepareForTimerUse()
        resetWorkSpeechState()

        let selectedTotal = TimeInterval(snapshot.selectedTotalSeconds)
        publish {
            $0.state = .running
            $0.remainingSeconds = selectedTotal
            $0.sessionTotalSeconds = selectedTotal
            $0.breakRemainingSeconds = breakTotalSeconds
            $0.breakTotalSeconds = breakTotalSeconds
        }

        endDate = Date.now.addingTimeInterval(selectedTotal)
        acquireDisplaySleepAssertion()
        scheduleRunningTimerNotifications()
        startTicking()
        speechNotifier.speak("加油,你就是下一个世界首富")
        tick()
        saveRestorationState()
    }

    func pause() {
        flushPendingSnapshot()
        guard snapshot.state == .running else { return }
        guard !updateRemainingFromClock() else { return }

        endDate = nil
        publish { $0.state = .paused }
        stopTicking()
        releaseDisplaySleepAssertionIfNeeded()
        notificationScheduler.cancelPendingTimerNotifications()
        saveRestorationState()
    }

    func resume() {
        flushPendingSnapshot()
        guard snapshot.state == .paused else { return }

        endDate = Date.now.addingTimeInterval(snapshot.remainingSeconds)
        publish { $0.state = .running }
        notificationScheduler.prepareForTimerUse()
        acquireDisplaySleepAssertion()
        scheduleRunningTimerNotifications()
        startTicking()
        tick()
        saveRestorationState()
    }

    func reset() {
        flushPendingSnapshot()
        if snapshot.state == .breaking {
            finishBreak(announcesCompletion: false, bringsWindowForward: false)
            return
        }

        stopTicking()
        releaseDisplaySleepAssertionIfNeeded()
        endBreakActivity()
        speechNotifier.stop()
        clearSystemNotice()
        notificationScheduler.cancelPendingTimerNotifications()
        endDate = nil
        breakEndDate = nil
        resetWorkSpeechState()

        let selectedTotal = TimeInterval(snapshot.selectedTotalSeconds)
        publish {
            $0.state = .idle
            $0.remainingSeconds = selectedTotal
            $0.sessionTotalSeconds = selectedTotal
            $0.breakRemainingSeconds = breakTotalSeconds
            $0.breakTotalSeconds = breakTotalSeconds
        }
        saveRestorationState()
    }

    func skipBreak() {
        flushPendingSnapshot()
        guard snapshot.state == .breaking else { return }
        finishBreak(announcesCompletion: false, bringsWindowForward: false)
    }

    func decreaseCountdown(by seconds: TimeInterval) {
        adjustCountdown(by: -abs(seconds))
    }

    func increaseCountdown(by seconds: TimeInterval) {
        adjustCountdown(by: abs(seconds))
    }

    private func adjustCountdown(by deltaSeconds: TimeInterval) {
        flushPendingSnapshot()
        guard canAdjustCountdown else { return }

        if snapshot.state == .running, updateRemainingFromClock() {
            return
        }

        let adjustedRemaining = snapshot.remainingSeconds + deltaSeconds

        if adjustedRemaining <= 0 {
            // Manual early finish: record the time actually focused so far, not the
            // full planned duration.
            let focused = max(0, Int((snapshot.sessionTotalSeconds - snapshot.remainingSeconds).rounded()))
            finish(completedFocusSecondsOverride: focused)
            return
        }

        // Adding time can push the remaining time past the original session total.
        // Keep the total at least as large as the remaining so progress and the
        // elapsed-based milestone math never go negative.
        publish {
            $0.remainingSeconds = adjustedRemaining
            $0.sessionTotalSeconds = Swift.max($0.sessionTotalSeconds, adjustedRemaining)
        }

        if snapshot.state == .running {
            endDate = Date.now.addingTimeInterval(adjustedRemaining)
            scheduleRunningTimerNotifications()
        }

        updateSpeechState(for: adjustedRemaining)
        saveRestorationState()
    }

    func handleSceneDidBecomeActive() {
        flushPendingSnapshot()
        tick()
        refreshScheduledTimerNotification()
    }

    func handleSceneDidEnterBackground() {
        flushPendingSnapshot()
        refreshScheduledTimerNotification()
        saveRestorationState()
    }

    private func startTicking() {
        stopTicking()

        let interval = desiredTickInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.queueTick()
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
        currentTickInterval = interval
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
        currentTickInterval = nil
        isTickQueued = false
    }

    private var desiredTickInterval: TimeInterval {
        #if os(macOS)
        NSApp.isActive ? foregroundTickInterval : backgroundTickInterval
        #else
        foregroundTickInterval
        #endif
    }

    private func handleAppActivityChange() {
        #if os(macOS)
        guard snapshot.state == .running || snapshot.state == .breaking else { return }

        let nextInterval = desiredTickInterval
        guard currentTickInterval != nextInterval else {
            if NSApp.isActive {
                tick()
            }
            return
        }

        startTicking()

        if NSApp.isActive {
            tick()
        }
        #endif
    }

    private func queueTick() {
        guard !isTickQueued else { return }
        isTickQueued = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isTickQueued = false
            self.tick()
        }
    }

    private func tick() {
        flushPendingSnapshot()

        switch snapshot.state {
        case .running:
            _ = updateRemainingFromClock()
        case .breaking:
            _ = updateBreakRemainingFromClock()
        default:
            return
        }
    }

    @discardableResult
    private func updateRemainingFromClock() -> Bool {
        guard snapshot.state == .running, let endDate else { return false }

        let rawRemaining = endDate.timeIntervalSinceNow
        let remaining = max(0, rawRemaining)

        if rawRemaining <= 0 {
            finish(workEndedAt: endDate)
            return true
        }

        publish { $0.remainingSeconds = remaining }
        updateSpeechState(for: remaining)
        return false
    }

    @discardableResult
    private func updateBreakRemainingFromClock() -> Bool {
        guard snapshot.state == .breaking, let breakEndDate else { return false }

        let rawRemaining = breakEndDate.timeIntervalSinceNow
        let remaining = max(0, rawRemaining)

        if rawRemaining <= 0 {
            finishBreak(announcesCompletion: true, bringsWindowForward: true)
            return true
        }

        publish { $0.breakRemainingSeconds = remaining }
        return false
    }

    private func updateSpeechState(for remaining: TimeInterval) {
        if remaining > 10 {
            hasSpokenReminder = false
        }

        if remaining <= 5 && !hasSpokenReminder {
            hasSpokenReminder = true
            speechNotifier.speakRestReminder()
            return
        }

        let total = snapshot.sessionTotalSeconds
        guard total >= progressSpeechMinimumDuration else { return }

        if remaining > 70 {
            hasSpokenFinalMinute = false
        }

        let elapsed = max(0, total - remaining)
        rearmProgressMilestones(elapsed: elapsed)

        if remaining <= 60 && remaining > 5 && !hasSpokenFinalMinute {
            hasSpokenFinalMinute = true
            speechNotifier.speak("还有最后一分钟")
            return
        }

        guard remaining > 75 else { return }
        speakProgressMilestoneIfNeeded(elapsed: elapsed, total: total)
    }

    private func rearmProgressMilestones(elapsed: TimeInterval) {
        spokenProgressMilestones = spokenProgressMilestones.filter { milestone in
            elapsed > TimeInterval(milestone - 5)
        }
    }

    private func speakProgressMilestoneIfNeeded(elapsed: TimeInterval, total: TimeInterval) {
        let latestMilestone = Int(elapsed / TimeInterval(progressMilestoneInterval)) * progressMilestoneInterval
        guard latestMilestone >= progressMilestoneInterval else { return }

        let maxMilestone = min(latestMilestone, Int(total) - 1)
        let crossedMilestones = stride(
            from: progressMilestoneInterval,
            through: maxMilestone,
            by: progressMilestoneInterval
        ).filter { milestone in
            TimeInterval(milestone) < total && !spokenProgressMilestones.contains(milestone)
        }

        guard let milestoneToSpeak = crossedMilestones.max() else { return }
        spokenProgressMilestones.formUnion(crossedMilestones)
        speechNotifier.speak("你努力了\(milestoneToSpeak / 60)分钟")
        speechNotifier.speak(nextProgressEncouragement())
    }

    private func resetWorkSpeechState() {
        hasSpokenReminder = false
        hasSpokenFinalMinute = false
        spokenProgressMilestones.removeAll()
        progressEncouragementIndex = 0
    }

    private func nextProgressEncouragement() -> String {
        let encouragement = progressEncouragements[progressEncouragementIndex % progressEncouragements.count]
        progressEncouragementIndex += 1
        return encouragement
    }

    private func beginBreakActivity() {
        #if os(macOS)
        guard breakActivity == nil else { return }
        breakActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: "Pomodoro break"
        )
        #endif
    }

    private func endBreakActivity() {
        #if os(macOS)
        guard let breakActivity else { return }
        ProcessInfo.processInfo.endActivity(breakActivity)
        self.breakActivity = nil
        #endif
    }

    private func startBreak(breakEndsAt: Date) -> Int {
        breakSessionID += 1
        let sessionID = breakSessionID

        breakEndDate = breakEndsAt
        beginBreakActivity()
        #if os(macOS)
        presentBreakAttention?()
        #endif
        startTicking()

        return sessionID
    }

    private func finishBreak(announcesCompletion: Bool, bringsWindowForward: Bool) {
        guard snapshot.state == .breaking else { return }

        breakSessionID += 1
        cancelPendingScreenSleepRequest()
        notificationScheduler.cancelPendingTimerNotifications()
        stopTicking()
        endBreakActivity()
        breakEndDate = nil
        clearScreenSleepNotice()

        if !announcesCompletion {
            speechNotifier.stop()
        }

        // Capture the message for the break that just ended, before the snapshot is
        // reset to the normal break length.
        let finishedMessage = breakFinishedMessage
        let willAutoStart = announcesCompletion && autoStartNextFocusEnabled

        let selectedTotal = TimeInterval(snapshot.selectedTotalSeconds)
        publish {
            $0.state = .idle
            $0.remainingSeconds = selectedTotal
            $0.sessionTotalSeconds = selectedTotal
            $0.breakRemainingSeconds = breakTotalSeconds
            $0.breakTotalSeconds = breakTotalSeconds
        }

        if bringsWindowForward {
            #if os(macOS)
            handleScreenSleepOutcome(screenSleeper.wakeDisplay(), action: "唤醒显示器")
            AppWindowPresenter.shared.present()
            #endif
        }

        // Skip the "已休息…" line when auto-starting so it flows straight into the
        // focus-start announcement instead of being cut off.
        if announcesCompletion, !willAutoStart {
            speechNotifier.speak(finishedMessage)
        }

        saveRestorationState()

        if willAutoStart {
            start()
        }
    }

    private func finish(workEndedAt: Date = Date.now, completedFocusSecondsOverride: Int? = nil) {
        flushPendingSnapshot()
        guard snapshot.state == .running || snapshot.state == .paused else { return }

        stopTicking()
        releaseDisplaySleepAssertionIfNeeded()
        notificationScheduler.cancelPendingTimerNotifications()
        endDate = nil

        // Every N completed focus sessions use a longer break (opt-in; interval 0 =
        // always the normal break).
        completedFocusCount += 1
        let isLongBreak = longBreakInterval > 0 && completedFocusCount.isMultiple(of: longBreakInterval)
        let effectiveBreakSeconds = isLongBreak ? longBreakSeconds : breakTotalSeconds

        let breakEndsAt = workEndedAt.addingTimeInterval(effectiveBreakSeconds)
        let breakRemaining = max(0, breakEndsAt.timeIntervalSinceNow)

        // A natural completion (timer reached its end, including expiry while
        // backgrounded) counts the full planned focus. A manual early finish passes
        // the actually-focused seconds instead.
        let completedFocusSeconds = completedFocusSecondsOverride ?? Int(snapshot.sessionTotalSeconds)

        publish {
            $0.remainingSeconds = 0
            $0.state = .breaking
            $0.breakRemainingSeconds = breakRemaining
            $0.breakTotalSeconds = effectiveBreakSeconds
        }

        onFocusSessionCompleted?(completedFocusSeconds)

        let sessionID = startBreak(breakEndsAt: breakEndsAt)
        guard breakRemaining > 0 else {
            finishBreak(announcesCompletion: true, bringsWindowForward: true)
            return
        }
        scheduleBreakFinishedNotification()

        if !hasSpokenReminder {
            hasSpokenReminder = true
            speechNotifier.speakRestReminder()
        }

        speechNotifier.runAfterCurrentSpeech { [weak self] in
            guard let self, self.snapshot.state == .breaking, self.breakSessionID == sessionID else { return }
            #if os(macOS)
            self.pendingScreenSleepRequest = self.screenSleeper.sleepDisplay { [weak self] outcome in
                guard let self, self.snapshot.state == .breaking, self.breakSessionID == sessionID else { return }
                self.pendingScreenSleepRequest = nil
                self.handleScreenSleepOutcome(outcome, action: "熄灭显示器")
            }
            #endif
        }

        saveRestorationState()
    }

    private func cancelPendingScreenSleepRequest() {
        pendingScreenSleepRequest?.cancel()
        pendingScreenSleepRequest = nil
    }

    private func clearScreenSleepNotice() {
        guard let systemNoticeText else { return }
        if systemNoticeText.hasPrefix("无法熄灭显示器") || systemNoticeText.hasPrefix("无法唤醒显示器") {
            clearSystemNotice()
        }
    }

    private func handleScreenSleepOutcome(_ outcome: ScreenSleepOutcome, action: String) {
        guard case .failed(let message) = outcome else {
            if systemNoticeText?.hasPrefix("无法\(action)") == true {
                clearSystemNotice()
            }
            return
        }

        publishSystemNotice("无法\(action): \(message)")
    }

    private func publishSystemNotice(_ text: String) {
        guard systemNoticeText != text else { return }
        systemNoticeText = text
    }

    private func acquireDisplaySleepAssertion() {
        guard !isDisplaySleepAssertionActive else { return }
        sleepAssertion.acquire()
        isDisplaySleepAssertionActive = true
    }

    private func releaseDisplaySleepAssertionIfNeeded() {
        guard isDisplaySleepAssertionActive else { return }
        sleepAssertion.release()
        isDisplaySleepAssertionActive = false
    }

    private func refreshScheduledTimerNotification() {
        switch snapshot.state {
        case .running:
            scheduleRunningTimerNotifications()
        case .breaking:
            scheduleBreakFinishedNotification()
        case .idle, .paused:
            notificationScheduler.cancelPendingTimerNotifications()
        }
    }

    private func scheduleRunningTimerNotifications() {
        guard snapshot.state == .running, let endDate else { return }
        let seconds = endDate.timeIntervalSinceNow
        guard seconds > 1 else { return }
        notificationScheduler.scheduleWorkFinished(after: seconds)
        notificationScheduler.scheduleBreakFinished(after: seconds + breakTotalSeconds, body: breakFinishedMessage)
    }

    private func scheduleBreakFinishedNotification() {
        guard snapshot.state == .breaking, let breakEndDate else { return }
        let seconds = breakEndDate.timeIntervalSinceNow
        guard seconds > 1 else { return }
        notificationScheduler.scheduleBreakFinished(after: seconds, body: breakFinishedMessage)
    }

    private func publish(_ update: (inout TimerSnapshot) -> Void) {
        var next = snapshot
        update(&next)

        guard next != snapshot else { return }
        snapshot = next
    }

    private var currentSnapshot: TimerSnapshot {
        pendingSnapshot ?? snapshot
    }

    let availableBreakMinutes = [3, 5, 10, 15]

    var breakMinutes: Int {
        max(1, Int((breakTotalSeconds / 60).rounded()))
    }

    /// Sets the break length (whole minutes). Only allowed while idle, mirroring
    /// how the focus duration is edited.
    func setBreakMinutes(_ minutes: Int) {
        guard canEditDuration else { return }
        let clamped = min(60, max(1, minutes))
        breakTotalSeconds = TimeInterval(clamped * 60)
        defaults.set(clamped * 60, forKey: Self.breakDurationDefaultsKey)
        publish {
            $0.breakTotalSeconds = breakTotalSeconds
            $0.breakRemainingSeconds = breakTotalSeconds
        }
    }

    /// Localized "已休息…,该继续了" message derived from the *active* break length
    /// (so long breaks read correctly). The 5-minute case keeps the exact wording of
    /// the bundled voice clip; other lengths fall back to synthesized speech.
    private var breakFinishedMessage: String {
        let totalSeconds = Int(currentSnapshot.breakTotalSeconds.rounded())
        if totalSeconds == 5 * 60 {
            return "已休息五分钟,该继续了"
        }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let phrase = seconds == 0 ? "\(minutes)分钟" : "\(minutes)分\(seconds)秒"
        return "已休息\(phrase),该继续了"
    }

    // MARK: - Cycle & auto-start (opt-in; all default to the original behavior)

    static let autoStartDefaultsKey = "autoStartNextFocus"
    static let longBreakIntervalDefaultsKey = "longBreakInterval"
    static let longBreakMinutesDefaultsKey = "longBreakMinutes"
    private static let completedFocusCountKey = "completedFocusCount"

    private var autoStartNextFocusEnabled: Bool {
        defaults.bool(forKey: Self.autoStartDefaultsKey)
    }

    /// 0 = long breaks disabled.
    private var longBreakInterval: Int {
        max(0, defaults.integer(forKey: Self.longBreakIntervalDefaultsKey))
    }

    private var longBreakSeconds: TimeInterval {
        let stored = defaults.integer(forKey: Self.longBreakMinutesDefaultsKey)
        let minutes = stored > 0 ? min(60, stored) : 15
        return TimeInterval(minutes * 60)
    }

    private var completedFocusCount: Int {
        get { defaults.integer(forKey: Self.completedFocusCountKey) }
        set { defaults.set(newValue, forKey: Self.completedFocusCountKey) }
    }

    private static let breakDurationDefaultsKey = "breakTotalSeconds"

    private func savedBreakDuration() -> TimeInterval {
        guard defaults.object(forKey: Self.breakDurationDefaultsKey) != nil else { return 5 * 60 }
        let value = defaults.integer(forKey: Self.breakDurationDefaultsKey)
        let clamped = min(60 * 60, max(60, value))
        return TimeInterval(clamped)
    }

    private static let selectedDurationDefaultsKey = "selectedTotalSeconds"

    private func savedSelectedDuration() -> Int? {
        guard defaults.object(forKey: Self.selectedDurationDefaultsKey) != nil else { return nil }
        let value = defaults.integer(forKey: Self.selectedDurationDefaultsKey)
        return value > 0 ? value : nil
    }

    private func enqueueSelectedDuration(totalSeconds: Int, selectedPresetMinutes explicitPreset: Int? = nil) {
        var next = currentSnapshot
        applySelectedDuration(totalSeconds: totalSeconds, selectedPresetMinutes: explicitPreset, to: &next)
        guard next != currentSnapshot else { return }

        defaults.set(next.selectedTotalSeconds, forKey: Self.selectedDurationDefaultsKey)
        pendingSnapshot = next
        enqueuePendingSnapshotPublish()
    }

    private func enqueuePendingSnapshotPublish() {
        guard !isSnapshotPublishQueued else { return }
        isSnapshotPublishQueued = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSnapshotPublishQueued = false
            self.flushPendingSnapshot()
        }
    }

    private func flushPendingSnapshot() {
        guard let pendingSnapshot else { return }
        self.pendingSnapshot = nil

        guard pendingSnapshot != snapshot else { return }
        snapshot = pendingSnapshot
    }

    private func applySelectedDuration(
        totalSeconds: Int,
        selectedPresetMinutes explicitPreset: Int?,
        to snapshot: inout TimerSnapshot
    ) {
        let clampedTotal = max(0, min(23 * 3600 + 59 * 60 + 59, totalSeconds))
        let preset = explicitPreset ?? availableMinutes.first { $0 * 60 == clampedTotal }
        let duration = TimeInterval(clampedTotal)

        snapshot.selectedTotalSeconds = clampedTotal
        snapshot.selectedPresetMinutes = preset
        snapshot.remainingSeconds = duration
        snapshot.sessionTotalSeconds = duration
    }

    private func formatClock(seconds: TimeInterval, showsHours: Bool) -> String {
        let totalSeconds = max(0, Int(ceil(seconds)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if showsHours {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatDuration(seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d小时 %02d分 %02d秒", hours, minutes, seconds)
        }

        if minutes > 0 {
            return String(format: "%d分 %02d秒", minutes, seconds)
        }

        return "\(seconds)秒"
    }

    isolated deinit {
        tickTimer?.invalidate()
        pendingScreenSleepRequest?.cancel()
        notificationScheduler.cancelPendingTimerNotifications()
        appActivityObservers.forEach(notificationCenter.removeObserver)
        #if os(macOS)
        if let breakActivity {
            ProcessInfo.processInfo.endActivity(breakActivity)
        }
        #endif
    }
}

/// Plain, platform-agnostic payload the view layer forwards to the Live Activity.
/// Kept free of any ActivityKit import so it also compiles for macOS.
struct LiveActivitySnapshot: Equatable, Sendable {
    var phase: String
    var isBreak: Bool
    var isPaused: Bool
    var startDate: Date
    var endDate: Date
    var remainingSeconds: Int
}

/// Persisted snapshot of the live timer, used to survive app termination.
struct TimerRestorationState: Codable, Equatable {
    var stateID: String
    var endDate: Date?
    var breakEndDate: Date?
    var remainingSeconds: Double
    var sessionTotalSeconds: Double
    var breakTotalSeconds: Double
}

/// What (if anything) to restore on launch. Pure/deterministic given `now`, so it
/// can be unit-tested without a running clock.
enum TimerRestorationOutcome: Equatable {
    case none
    case running(endDate: Date, sessionTotalSeconds: Double)
    case paused(remainingSeconds: Double, sessionTotalSeconds: Double)
    case breaking(breakEndDate: Date, breakTotalSeconds: Double)

    static func resolve(_ record: TimerRestorationState?, now: Date) -> TimerRestorationOutcome {
        guard let record else { return .none }
        switch record.stateID {
        case "running":
            guard let end = record.endDate, end > now else { return .none }
            return .running(endDate: end, sessionTotalSeconds: record.sessionTotalSeconds)
        case "paused":
            guard record.remainingSeconds > 0 else { return .none }
            return .paused(remainingSeconds: record.remainingSeconds, sessionTotalSeconds: record.sessionTotalSeconds)
        case "breaking":
            guard let end = record.breakEndDate, end > now else { return .none }
            return .breaking(breakEndDate: end, breakTotalSeconds: record.breakTotalSeconds)
        default:
            return .none
        }
    }
}
