import Foundation

#if os(iOS)
@preconcurrency import UserNotifications
#endif

@MainActor
protocol TimerNotificationControlling: AnyObject {
    func prepareForTimerUse()
    func scheduleWorkFinished(after seconds: TimeInterval)
    func scheduleBreakFinished(after seconds: TimeInterval, body: String)
    func cancelPendingTimerNotifications()
}

@MainActor
final class TimerNotificationScheduler: TimerNotificationControlling {
    #if os(iOS)
    private let center = UNUserNotificationCenter.current()
    private let foregroundPresenter = ForegroundNotificationPresenter()
    private var authorizationTask: Task<Bool, Never>?
    private var cancelGeneration = 0
    private var requestVersions: [String: Int] = [:]
    private var scheduleTasks: [String: Task<Void, Never>] = [:]

    init() {
        center.delegate = foregroundPresenter
    }
    #endif

    func prepareForTimerUse() {
        #if os(iOS)
        Task { @MainActor in
            _ = await authorizationGranted()
        }
        #endif
    }

    func scheduleWorkFinished(after seconds: TimeInterval) {
        schedule(
            identifier: Self.workFinishedIdentifier,
            title: "番茄钟结束",
            body: "去休息吧,下一个世界首富",
            after: seconds
        )
    }

    func scheduleBreakFinished(after seconds: TimeInterval, body: String) {
        schedule(
            identifier: Self.breakFinishedIdentifier,
            title: "休息结束",
            body: body,
            after: seconds
        )
    }

    func cancelPendingTimerNotifications() {
        #if os(iOS)
        cancelGeneration += 1
        scheduleTasks.values.forEach { $0.cancel() }
        scheduleTasks.removeAll()
        requestVersions.removeAll()
        center.removePendingNotificationRequests(withIdentifiers: Self.timerNotificationIdentifiers)
        #endif
    }

    private func schedule(identifier: String, title: String, body: String, after seconds: TimeInterval) {
        #if os(iOS)
        guard seconds > 1 else { return }

        let version = (requestVersions[identifier] ?? 0) + 1
        let cancelGeneration = cancelGeneration
        requestVersions[identifier] = version
        scheduleTasks[identifier]?.cancel()

        let task = Task { @MainActor [weak self] in
            guard let self, self.isCurrentSchedule(
                identifier: identifier, version: version, generation: cancelGeneration
            ) else {
                return
            }
            guard await authorizationGranted() else { return }
            guard isCurrentSchedule(identifier: identifier, version: version, generation: cancelGeneration) else {
                return
            }

            center.removePendingNotificationRequests(withIdentifiers: [identifier])

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
            } catch {
                NSLog("Failed to schedule timer notification: %@", error.localizedDescription)
            }

            if isCurrentSchedule(identifier: identifier, version: version, generation: cancelGeneration) {
                scheduleTasks[identifier] = nil
            } else {
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
            }
        }
        scheduleTasks[identifier] = task
        #endif
    }

    #if os(iOS)
    deinit {
        scheduleTasks.values.forEach { $0.cancel() }
        authorizationTask?.cancel()
    }

    private func isCurrentSchedule(identifier: String, version: Int, generation: Int) -> Bool {
        !Task.isCancelled && cancelGeneration == generation && requestVersions[identifier] == version
    }

    private func authorizationGranted() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            if let authorizationTask {
                return await authorizationTask.value
            }

            let task = Task { @MainActor in
                do {
                    return try await center.requestAuthorization(options: [.alert, .sound])
                } catch {
                    NSLog("Failed to request notification authorization: %@", error.localizedDescription)
                    return false
                }
            }
            authorizationTask = task
            let granted = await task.value
            authorizationTask = nil
            return granted
        @unknown default:
            return false
        }
    }
    #endif

    private static let workFinishedIdentifier = "TomatoTimer.workFinished"
    private static let breakFinishedIdentifier = "TomatoTimer.breakFinished"
    private static let timerNotificationIdentifiers = [workFinishedIdentifier, breakFinishedIdentifier]
}

#if os(iOS)
/// Presents timer notifications as a banner + sound even while the app is in the
/// foreground (iOS otherwise suppresses them by default).
private final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
#endif
