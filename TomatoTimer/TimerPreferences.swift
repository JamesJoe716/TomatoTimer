import Foundation

/// Everything the timer persists, in one place.
///
/// The key strings are an on-disk storage format, not an implementation detail:
/// renaming one silently discards whatever the user had configured. The clamping
/// on read is deliberate too — it keeps a hand-edited or corrupted defaults
/// value from putting the timer into a nonsensical state.
struct TimerPreferences {
    // Read by SettingsView through @AppStorage, so these stay internal.
    static let autoStartKey = "autoStartNextFocus"
    static let longBreakIntervalKey = "longBreakInterval"
    static let longBreakMinutesKey = "longBreakMinutes"

    private static let completedFocusCountKey = "completedFocusCount"
    private static let breakDurationKey = "breakTotalSeconds"
    private static let selectedDurationKey = "selectedTotalSeconds"
    private static let restorationStateKey = "timerRestorationState.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - Durations

    /// Last focus duration the user picked, so the app doesn't reset to 25:00 on
    /// every launch. `nil` when never set.
    var selectedDuration: Int? {
        get {
            guard defaults.object(forKey: Self.selectedDurationKey) != nil else { return nil }
            let value = defaults.integer(forKey: Self.selectedDurationKey)
            return value > 0 ? value : nil
        }
        nonmutating set {
            guard let newValue else {
                defaults.removeObject(forKey: Self.selectedDurationKey)
                return
            }
            defaults.set(newValue, forKey: Self.selectedDurationKey)
        }
    }

    /// Configured break length in seconds. Defaults to 5 minutes, clamped to
    /// 1...60 minutes on read.
    var breakDuration: TimeInterval {
        get {
            guard defaults.object(forKey: Self.breakDurationKey) != nil else { return 5 * 60 }
            let value = defaults.integer(forKey: Self.breakDurationKey)
            return TimeInterval(min(60 * 60, max(60, value)))
        }
        nonmutating set {
            defaults.set(Int(newValue), forKey: Self.breakDurationKey)
        }
    }

    // MARK: - Cycle & auto-start (opt-in; all default to the original behavior)

    var autoStartNextFocus: Bool {
        defaults.bool(forKey: Self.autoStartKey)
    }

    /// Number of focus sessions between long breaks. 0 = long breaks disabled.
    var longBreakInterval: Int {
        max(0, defaults.integer(forKey: Self.longBreakIntervalKey))
    }

    /// Long-break length in seconds; 15 minutes unless configured, capped at 60.
    var longBreakSeconds: TimeInterval {
        let stored = defaults.integer(forKey: Self.longBreakMinutesKey)
        let minutes = stored > 0 ? min(60, stored) : 15
        return TimeInterval(minutes * 60)
    }

    /// Running tally used to decide when the next break is a long one.
    var completedFocusCount: Int {
        get { defaults.integer(forKey: Self.completedFocusCountKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.completedFocusCountKey) }
    }

    // MARK: - Restoration

    /// Live-timer record used to survive app termination. Setting `nil` clears it.
    var restorationState: TimerRestorationState? {
        get {
            defaults.data(forKey: Self.restorationStateKey).flatMap {
                try? JSONDecoder().decode(TimerRestorationState.self, from: $0)
            }
        }
        nonmutating set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                defaults.removeObject(forKey: Self.restorationStateKey)
                return
            }
            defaults.set(data, forKey: Self.restorationStateKey)
        }
    }
}
