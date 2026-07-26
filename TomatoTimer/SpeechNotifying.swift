import Foundation

@MainActor
protocol SpeechNotifying: AnyObject {
    func speak(_ text: String)
    func speakRestReminder()
    func playSelfIntro(gender: VoiceGender)
    func reloadVoicesAndLog()
    func runAfterCurrentSpeech(_ handler: @escaping @MainActor @Sendable () -> Void)
    func stop(preservingCompletionHandlers: Bool)
}

extension SpeechNotifying {
    func stop() {
        stop(preservingCompletionHandlers: false)
    }
}
