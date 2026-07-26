#if !os(macOS)
@MainActor
final class CompletedScreenSleepRequest: ScreenSleepRequest {
    private var isCancelled = false
    private var task: Task<Void, Never>?

    init(completion: @escaping ScreenSleepCompletion) {
        task = Task { @MainActor [weak self] in
            guard self?.isCancelled == false else { return }
            completion(.succeeded)
        }
    }

    func cancel() {
        isCancelled = true
        task?.cancel()
        task = nil
    }
}
#endif
