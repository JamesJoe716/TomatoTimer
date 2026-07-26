@preconcurrency import AVFoundation
import Foundation

@MainActor
final class SpeechNotifier: NSObject, SpeechNotifying, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private enum SpeechItem {
        case audio(resourceName: String, url: URL)
        case fallbackUtterance(AVSpeechUtterance)
    }

    private enum SpeechResolution {
        case audio(resourceName: String, url: URL)
        case fallback(AVSpeechUtterance)
        case skip(reason: String)
    }

    private struct VoiceChoice {
        let voice: AVSpeechSynthesisVoice?
        let tier: String
        let pitchMultiplier: Float
        let rate: Float
        let volume: Float

        var logDescription: String {
            tier
        }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var speechQueue: [SpeechItem] = []
    private var activeSpeechItem: SpeechItem?
    private var completionHandlers: [@MainActor @Sendable () -> Void] = []
    private var fallbackVoice: VoiceChoice
    private var loggedGender: VoiceGender?

    override init() {
        fallbackVoice = SpeechNotifier.selectFallbackVoice()
        super.init()
        Self.configureAudioSessionCategory()
        synthesizer.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceGenderDidChange),
            name: .voiceGenderDidChange,
            object: nil
        )
        logVoiceConfiguration(currentGender: VoiceGender.current)
    }

    static let mutedDefaultsKey = "speechMuted"

    private static var isMuted: Bool {
        UserDefaults.standard.bool(forKey: mutedDefaultsKey)
    }

    func speak(_ text: String) {
        guard !SpeechNotifier.isMuted else { return }

        let gender = VoiceGender.current
        if loggedGender != gender {
            logVoiceConfiguration(currentGender: gender)
        }

        switch SpeechNotifier.resolveSpeechItem(for: text, gender: gender, fallbackVoice: fallbackVoice) {
        case .audio(let resourceName, let url):
            SpeechNotifier.emitVoiceLog(
                "TTS speak=\(text); gender=\(gender.rawValue); "
                    + "voice=\(gender.voiceModeDescription); "
                    + "file=\(gender.clipSubdirectory)/\(resourceName).mp3"
            )
            enqueueSpeechItem(.audio(resourceName: resourceName, url: url))

        case .fallback(let utterance):
            SpeechNotifier.emitVoiceLog(
                "TTS speak=\(text); gender=\(gender.rawValue); voice=fallback \(fallbackVoice.logDescription)"
            )
            enqueueSpeechItem(.fallbackUtterance(utterance))

        case .skip(let reason):
            SpeechNotifier.emitVoiceLog("TTS skip=\(text); gender=\(gender.rawValue); reason=\(reason)")
        }
    }

    func speakRestReminder() {
        speak("去休息吧,下一个世界首富")
    }

    func playSelfIntro(gender: VoiceGender) {
        stop()

        guard !SpeechNotifier.isMuted else { return }

        if let url = Bundle.main.url(
            forResource: "intro", withExtension: "mp3", subdirectory: gender.clipSubdirectory
        ) {
            SpeechNotifier.emitVoiceLog(
                "TTS selfIntro; gender=\(gender.rawValue); "
                    + "voice=\(gender.voiceModeDescription); "
                    + "file=\(gender.clipSubdirectory)/intro.mp3"
            )
            enqueueSpeechItem(.audio(resourceName: "intro", url: url))
        } else {
            SpeechNotifier.emitVoiceLog(
                "TTS selfIntro missing intro.mp3; gender=\(gender.rawValue); fallback=\(fallbackVoice.logDescription)"
            )
            enqueueSpeechItem(.fallbackUtterance(
                Self.makeFallbackUtterance(gender.selfIntroText, fallbackVoice: fallbackVoice)
            ))
        }
    }

    func reloadVoicesAndLog() {
        fallbackVoice = SpeechNotifier.selectFallbackVoice()
        logVoiceConfiguration(currentGender: VoiceGender.current)
    }

    static func logConfiguredVoices() {
        let gender = VoiceGender.current
        emitVoiceLog("voice mode = \(gender.voiceModeDescription)")
    }

    func runAfterCurrentSpeech(_ handler: @escaping @MainActor @Sendable () -> Void) {
        if hasPendingSpeech {
            completionHandlers.append(handler)
        } else {
            Task { @MainActor in
                handler()
            }
        }
    }

    func stop(preservingCompletionHandlers: Bool = false) {
        if !preservingCompletionHandlers {
            completionHandlers.removeAll()
        }

        stopClipPlayback()

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        if preservingCompletionHandlers {
            flushCompletionHandlersWhenIdle()
        } else {
            Self.setAudioSessionActive(false)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.handleSpeechDidFinishOrCancel()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.handleSpeechDidFinishOrCancel()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.handleAudioPlayerStopped()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let message = error?.localizedDescription ?? "unknown"
        Task { @MainActor [weak self] in
            SpeechNotifier.emitVoiceLog("TTS audio error=\(message)")
            self?.handleAudioPlayerStopped()
        }
    }

    private func handleSpeechDidFinishOrCancel() {
        if case .fallbackUtterance = activeSpeechItem {
            activeSpeechItem = nil
            playNextSpeechItem()
            return
        }

        flushCompletionHandlersWhenIdle()
    }

    private func handleAudioPlayerStopped() {
        audioPlayer = nil
        activeSpeechItem = nil
        playNextSpeechItem()
    }

    private func flushCompletionHandlersWhenIdle() {
        Task { @MainActor [weak self] in
            guard let self, !self.hasPendingSpeech else { return }
            Self.setAudioSessionActive(false)
            self.flushCompletionHandlers()
        }
    }

    private func flushCompletionHandlers() {
        let handlers = completionHandlers
        completionHandlers.removeAll()
        handlers.forEach { $0() }
    }

    private func logVoiceConfiguration(currentGender: VoiceGender) {
        loggedGender = currentGender
        SpeechNotifier.emitVoiceLog("voice mode = \(currentGender.voiceModeDescription)")
    }

    @objc private func voiceGenderDidChange() {
        stop(preservingCompletionHandlers: true)
        reloadVoicesAndLog()
    }

    private var hasPendingSpeech: Bool {
        synthesizer.isSpeaking || audioPlayer != nil || activeSpeechItem != nil || !speechQueue.isEmpty
    }

    private func enqueueSpeechItem(_ item: SpeechItem) {
        speechQueue.append(item)
        guard activeSpeechItem == nil, audioPlayer == nil else { return }
        playNextSpeechItem()
    }

    private func playNextSpeechItem() {
        guard activeSpeechItem == nil, audioPlayer == nil else { return }
        guard !speechQueue.isEmpty else {
            flushCompletionHandlersWhenIdle()
            return
        }

        let item = speechQueue.removeFirst()
        activeSpeechItem = item
        Self.setAudioSessionActive(true)

        switch item {
        case .audio(_, let url):
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.prepareToPlay()
                audioPlayer = player

                if !player.play() {
                    SpeechNotifier.emitVoiceLog("TTS audio failed to start=\(url.lastPathComponent)")
                    audioPlayer = nil
                    activeSpeechItem = nil
                    playNextSpeechItem()
                }
            } catch {
                SpeechNotifier.emitVoiceLog("TTS audio error=\(error.localizedDescription)")
                audioPlayer = nil
                activeSpeechItem = nil
                playNextSpeechItem()
            }

        case .fallbackUtterance(let utterance):
            synthesizer.speak(utterance)
        }
    }

    private func stopClipPlayback() {
        speechQueue.removeAll()
        activeSpeechItem = nil

        if let audioPlayer {
            audioPlayer.stop()
            self.audioPlayer = nil
        }
    }

    private static func emitVoiceLog(_ message: String) {
        #if DEBUG
        NSLog("%@", message)
        FileHandle.standardError.write(Data((message + "\n").utf8))
        #endif
    }

    /// Sets the category only. Activation is deferred to actual playback so we do
    /// not duck the user's other audio for the whole app lifetime.
    private static func configureAudioSessionCategory() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance()
                .setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        } catch {
            emitVoiceLog("TTS audio session category error=\(error.localizedDescription)")
        }
        #endif
    }

    /// Activates the session right before speaking and deactivates it (restoring
    /// other apps' volume) once the queue drains, so ducking lasts only as long as
    /// a clip is actually playing.
    private static func setAudioSessionActive(_ active: Bool) {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            if active {
                try session.setActive(true)
            } else {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        } catch {
            emitVoiceLog("TTS audio session setActive(\(active)) error=\(error.localizedDescription)")
        }
        #endif
    }

    private static func resolveSpeechItem(
        for text: String,
        gender: VoiceGender,
        fallbackVoice: VoiceChoice
    ) -> SpeechResolution {
        let normalizedText = normalizeSpeechText(text)

        if let resourceName = fixedClipNames[normalizedText] ?? encouragementClipNames[normalizedText] {
            return audioResolution(
                resourceName: resourceName,
                gender: gender,
                fallbackVoice: fallbackVoice,
                fallbackText: text
            )
        }

        if normalizedText.hasPrefix("你努力了"), normalizedText.hasSuffix("分钟") {
            let minuteText = normalizedText
                .replacingOccurrences(of: "你努力了", with: "")
                .replacingOccurrences(of: "分钟", with: "")

            guard let minutes = Int(minuteText) else {
                return .fallback(makeFallbackUtterance(text, fallbackVoice: fallbackVoice))
            }

            guard minutes >= 5, minutes.isMultiple(of: 5) else {
                return .skip(reason: "effort milestone \(minutes) has no bundled clip")
            }

            return audioResolution(
                resourceName: "effort_\(minutes)",
                gender: gender,
                fallbackVoice: fallbackVoice,
                fallbackText: text
            )
        }

        return .fallback(makeFallbackUtterance(text, fallbackVoice: fallbackVoice))
    }

    private static func audioResolution(
        resourceName: String,
        gender: VoiceGender,
        fallbackVoice: VoiceChoice,
        fallbackText: String
    ) -> SpeechResolution {
        if let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "mp3",
            subdirectory: gender.clipSubdirectory
        ) {
            return .audio(resourceName: resourceName, url: url)
        }

        return .fallback(makeFallbackUtterance(fallbackText, fallbackVoice: fallbackVoice))
    }

    private static func makeFallbackUtterance(_ text: String, fallbackVoice: VoiceChoice) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = fallbackVoice.voice
        utterance.pitchMultiplier = fallbackVoice.pitchMultiplier
        utterance.rate = fallbackVoice.rate
        utterance.volume = fallbackVoice.volume
        return utterance
    }

    private static func normalizeSpeechText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "，", with: ",")
    }

    private static func selectFallbackVoice() -> VoiceChoice {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "zh-CN" }

        if let voice = voices.first(where: { $0.quality == .premium && matchesNameOrIdentifier($0, "Yue") }) {
            return VoiceChoice(
                voice: voice, tier: "Yue premium",
                pitchMultiplier: 1.05, rate: AVSpeechUtteranceDefaultSpeechRate, volume: 1
            )
        }
        if let voice = voices.first(where: { $0.quality == .premium }) {
            return VoiceChoice(
                voice: voice, tier: "\(displayName(for: voice)) premium",
                pitchMultiplier: 1.05, rate: AVSpeechUtteranceDefaultSpeechRate, volume: 1
            )
        }
        if let voice = voices.first(where: { $0.quality == .enhanced }) {
            return VoiceChoice(
                voice: voice, tier: "\(displayName(for: voice)) enhanced",
                pitchMultiplier: 1.05, rate: AVSpeechUtteranceDefaultSpeechRate, volume: 1
            )
        }
        if let voice = voices.first(where: {
            matchesNameOrIdentifier($0, "Ting") || matchesNameOrIdentifier($0, "婷婷")
        }) {
            return VoiceChoice(
                voice: voice, tier: "\(displayName(for: voice)) standard",
                pitchMultiplier: 1.3, rate: AVSpeechUtteranceDefaultSpeechRate * 1.05, volume: 1
            )
        }
        return VoiceChoice(
            voice: nil, tier: "system default",
            pitchMultiplier: 1.3, rate: AVSpeechUtteranceDefaultSpeechRate * 1.05, volume: 1
        )
    }

    private static func displayName(for voice: AVSpeechSynthesisVoice) -> String {
        voice.name.isEmpty ? voice.identifier : voice.name
    }

    private static func matchesNameOrIdentifier(_ voice: AVSpeechSynthesisVoice, _ text: String) -> Bool {
        voice.name.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil ||
            voice.identifier.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private static let fixedClipNames = [
        "加油,你就是下一个世界首富": "start",
        "还有最后一分钟": "final_minute",
        "去休息吧,下一个世界首富": "rest",
        "已休息五分钟,该继续了": "resume"
    ]

    private static let encouragementClipNames = [
        "太厉害啦,这个节奏世界首富稳了": "enc_1",
        "好棒好棒,首富宝座在向你招手哦": "enc_2",
        "专注的你最有魅力,继续冲呀未来首富": "enc_3",
        "稳住稳住,离世界首富又近一步啦": "enc_4",
        "哇你也太能扛了,亿万身家等着你呢": "enc_5",
        "再加把劲,未来首富我可看好你哦": "enc_6",
        "你已经超神啦,首富不是你还能是谁": "enc_7",
        "继续保持,小钱钱正在向你飞来呀": "enc_8"
    ]
}
