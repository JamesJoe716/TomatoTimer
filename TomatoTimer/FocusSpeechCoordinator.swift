import Foundation

/// Decides *when* the timer speaks during a focus session, and tracks what has
/// already been said so nothing repeats.
///
/// Split out of the view model because this is the one piece of timer behavior
/// with meaningful state of its own — which milestones have been announced, where
/// the encouragement rotation is — that the state machine never needs to inspect.
@MainActor
final class FocusSpeechCoordinator {
    /// Sessions shorter than this get no progress chatter; only the closing lines.
    private let progressSpeechMinimumDuration: TimeInterval = 10 * 60
    private let progressMilestoneInterval = 5 * 60

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

    private let speechNotifier: SpeechNotifying

    private var hasSpokenReminder = false
    private var hasSpokenFinalMinute = false
    private var spokenProgressMilestones: Set<Int> = []
    private var progressEncouragementIndex = 0

    init(speechNotifier: SpeechNotifying) {
        self.speechNotifier = speechNotifier
    }

    func reset() {
        hasSpokenReminder = false
        hasSpokenFinalMinute = false
        spokenProgressMilestones.removeAll()
        progressEncouragementIndex = 0
    }

    /// Speaks the rest reminder if it has not played yet for this session.
    func announceRestReminderIfNeeded() {
        guard !hasSpokenReminder else { return }
        hasSpokenReminder = true
        speechNotifier.speakRestReminder()
    }

    /// Drives all mid-session speech from the current countdown.
    ///
    /// `sessionTotalSeconds` is passed in rather than stored because adding time
    /// mid-session can grow it.
    func update(remaining: TimeInterval, sessionTotalSeconds total: TimeInterval) {
        // Re-arm the reminder if time was added back above the trigger window.
        if remaining > 10 {
            hasSpokenReminder = false
        }

        if remaining <= 5 && !hasSpokenReminder {
            hasSpokenReminder = true
            speechNotifier.speakRestReminder()
            return
        }

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

    /// Drops milestones the countdown has been rewound past, so they can announce
    /// again if the user adds time back.
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

    private func nextProgressEncouragement() -> String {
        let encouragement = progressEncouragements[progressEncouragementIndex % progressEncouragements.count]
        progressEncouragementIndex += 1
        return encouragement
    }
}
