import Foundation

#if os(macOS)
@MainActor
final class ProcessScreenSleepRequest: ScreenSleepRequest {
    private let state = State()
    private var task: Task<Void, Never>?

    func start(completion: @escaping ScreenSleepCompletion) {
        task = Task.detached(priority: .utility) { [state] in
            let outcome = state.run()
            guard !Task.isCancelled, !state.isCancelled else { return }
            await completion(outcome)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        state.cancel()
    }

    deinit {
        state.cancel()
    }
}

private extension ProcessScreenSleepRequest {
    // Shared between the main actor and a detached task; every mutable field is
    // protected by lock, including process startup and cancellation.
    final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var cancelled = false

        var isCancelled: Bool {
            lock.lock()
            let value = cancelled
            lock.unlock()
            return value
        }

        func run() -> ScreenSleepOutcome {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["displaysleepnow"]

            do {
                lock.lock()
                if cancelled {
                    lock.unlock()
                    return .succeeded
                }
                self.process = process
                try process.run()
                lock.unlock()

                defer {
                    lock.lock()
                    self.process = nil
                    lock.unlock()
                }

                process.waitUntilExit()

                if isCancelled {
                    return .succeeded
                }

                if process.terminationStatus != 0 {
                    let message = "pmset displaysleepnow exited with status \(process.terminationStatus)"
                    NSLog("%@", message)
                    return .failed(message)
                }
            } catch {
                self.process = nil
                lock.unlock()
                if isCancelled {
                    return .succeeded
                }

                let message = "Failed to run pmset displaysleepnow: \(error.localizedDescription)"
                NSLog("%@", message)
                return .failed(message)
            }

            return .succeeded
        }

        func cancel() {
            lock.lock()
            cancelled = true
            let process = process
            lock.unlock()

            if process?.isRunning == true {
                process?.terminate()
            }
        }
    }
}
#endif
