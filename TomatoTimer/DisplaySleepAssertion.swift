import Foundation

#if os(macOS)
import IOKit.pwr_mgt
#elseif os(iOS)
import UIKit
#endif

@MainActor
protocol DisplaySleepControlling: AnyObject {
    func acquire()
    func release()
}

@MainActor
final class DisplaySleepAssertion: DisplaySleepControlling {
    #if os(macOS)
    private var assertionID = IOPMAssertionID(0)
    private var isActive = false
    #endif

    func acquire() {
        #if os(macOS)
        guard !isActive else { return }

        let reason = "Pomodoro timer is running" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        isActive = result == kIOReturnSuccess
        if !isActive {
            NSLog("Failed to prevent display sleep: IOReturn \(result)")
        }
        #elseif os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }

    func release() {
        #if os(macOS)
        guard isActive else { return }
        let result = IOPMAssertionRelease(assertionID)
        if result != kIOReturnSuccess {
            NSLog("Failed to release display sleep assertion: IOReturn \(result)")
        }
        assertionID = 0
        isActive = false
        #elseif os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
    }

    deinit {
        #if os(macOS)
        guard isActive else { return }
        let result = IOPMAssertionRelease(assertionID)
        if result != kIOReturnSuccess {
            NSLog("Failed to release display sleep assertion during deinit: IOReturn \(result)")
        }
        #endif
    }
}
