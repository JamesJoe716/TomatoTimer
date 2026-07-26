import Foundation

#if os(macOS)
import IOKit.pwr_mgt
#endif

@MainActor
enum ScreenSleeper {
    @discardableResult
    static func sleepDisplay(completion: @escaping ScreenSleepCompletion = { _ in }) -> ScreenSleepRequest {
        #if os(macOS)
        let request = ProcessScreenSleepRequest()
        request.start(completion: completion)
        return request
        #else
        return CompletedScreenSleepRequest(completion: completion)
        #endif
    }

    static func wakeDisplay() -> ScreenSleepOutcome {
        #if os(macOS)
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionDeclareUserActivity(
            "Pomodoro break finished" as CFString,
            kIOPMUserActiveLocal,
            &assertionID
        )

        if result != kIOReturnSuccess {
            let message = "Failed to wake display: IOReturn \(result)"
            NSLog("%@", message)
            return .failed(message)
        }

        if assertionID != 0 {
            let releaseResult = IOPMAssertionRelease(assertionID)
            if releaseResult != kIOReturnSuccess {
                let message = "Failed to release wake display assertion: IOReturn \(releaseResult)"
                NSLog("%@", message)
                return .failed(message)
            }
        }

        return .succeeded
        #else
        return .succeeded
        #endif
    }
}
