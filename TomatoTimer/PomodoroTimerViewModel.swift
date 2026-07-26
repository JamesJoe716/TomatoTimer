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
    private let preferences: TimerPreferences

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
        self.preferences = TimerPreferences(defaults: userDefaults)
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
        if let saved = preferences.selectedDuration {
            applySelectedDuration(totalSeconds: saved, selectedPresetMinutes: nil, to: &snapshot)
        }

        // Restore the configured break length and reflect it in the idle snapshot.
        breakTotalSeconds = preferences.breakDuration
        snapshot.breakTotalSeconds = breakTotalSeconds
        snapshot.breakRemainingSeconds = breakTotalSeconds

        // Restore a live session that survived app termination, so the UI matches
        // reality (and any pending notifications) instead of showing idle.
        applyRestorationIfNeeded()
    }

    private func saveRestorationState() {
        let stateID: String?
        switch snapshot.state {
        case .running: stateID = "running"
        case .paused: stateID = "paused"
        case .breaking: stateID = "breaking"
        case .idle: stateID = nil
        }

        guard let stateID else {
            preferences.restorationState = nil
            return
        }

        preferences.restorationState = TimerRestorationState(
            stateID: stateID,
            endDate: endDate,
            breakEndDate: breakEndDate,
            remainingSeconds: snapshot.remainingSeconds,
            sessionTotalSeconds: snapshot.sessionTotalSeconds,
            breakTotalSeconds: snapshot.breakTotalSeconds
        )
    }

    private func applyRestorationIfNeeded() {
        switch TimerRestorationOutcome.resolve(preferences.restorationState, now: Date.now) {
        case .none:
            preferences.restorationState = nil
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

    // Derived presentation lives on TimerSnapshot; these forward the pending-aware
    // snapshot so the UI sees in-flight duration edits immediately.
    var canEditDuration: Bool { currentSnapshot.canEditDuration }
    var canStart: Bool { currentSnapshot.canStart }
    var canAdjustCountdown: Bool { currentSnapshot.canAdjustCountdown }
    var canSkipBreak: Bool { currentSnapshot.canSkipBreak }
    var selectedPresetMinutes: Int? { currentSnapshot.selectedPresetMinutes }
    var selectedHours: Int { currentSnapshot.selectedHours }
    var selectedMinutesComponent: Int { currentSnapshot.selectedMinutesComponent }
    var selectedSecondsComponent: Int { currentSnapshot.selectedSecondsComponent }
    var selectedDurationText: String { currentSnapshot.selectedDurationText }
    var progress: Double { currentSnapshot.progress }
    var remainingTimeText: String { currentSnapshot.remainingTimeText }
    var statusText: String { currentSnapshot.statusText }
    var statusColor: Color { currentSnapshot.statusColor }

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
        let willAutoStart = announcesCompletion && preferences.autoStartNextFocus

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
        preferences.completedFocusCount += 1
        let longBreakInterval = preferences.longBreakInterval
        let isLongBreak = longBreakInterval > 0
            && preferences.completedFocusCount.isMultiple(of: longBreakInterval)
        let effectiveBreakSeconds = isLongBreak ? preferences.longBreakSeconds : breakTotalSeconds

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
        preferences.breakDuration = breakTotalSeconds
        publish {
            $0.breakTotalSeconds = breakTotalSeconds
            $0.breakRemainingSeconds = breakTotalSeconds
        }
    }

    private var breakFinishedMessage: String { currentSnapshot.breakFinishedMessage }

    private func enqueueSelectedDuration(totalSeconds: Int, selectedPresetMinutes explicitPreset: Int? = nil) {
        var next = currentSnapshot
        applySelectedDuration(totalSeconds: totalSeconds, selectedPresetMinutes: explicitPreset, to: &next)
        guard next != currentSnapshot else { return }

        preferences.selectedDuration = next.selectedTotalSeconds
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
