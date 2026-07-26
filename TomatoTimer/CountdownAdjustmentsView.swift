import SwiftUI

struct CountdownAdjustmentsView: View {
    @EnvironmentObject private var timer: PomodoroTimerViewModel
    let metrics: AdaptiveLayoutMetrics

    var body: some View {
        Group {
            if metrics.isCompact {
                if metrics.usesSingleColumnCountdownAdjustments {
                    VStack(spacing: 8) {
                        TimerAdjustmentButton(title: "-1分", systemImage: "minus.circle") {
                            timer.decreaseCountdown(by: 60)
                        }

                        TimerAdjustmentButton(title: "-30秒", systemImage: "minus.circle") {
                            timer.decreaseCountdown(by: 30)
                        }

                        TimerAdjustmentButton(title: "+30秒", systemImage: "plus.circle") {
                            timer.increaseCountdown(by: 30)
                        }

                        TimerAdjustmentButton(title: "+1分", systemImage: "plus.circle") {
                            timer.increaseCountdown(by: 60)
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            TimerAdjustmentButton(title: "-1分", systemImage: "minus.circle") {
                                timer.decreaseCountdown(by: 60)
                            }

                            TimerAdjustmentButton(title: "-30秒", systemImage: "minus.circle") {
                                timer.decreaseCountdown(by: 30)
                            }
                        }

                        HStack(spacing: 8) {
                            TimerAdjustmentButton(title: "+30秒", systemImage: "plus.circle") {
                                timer.increaseCountdown(by: 30)
                            }

                            TimerAdjustmentButton(title: "+1分", systemImage: "plus.circle") {
                                timer.increaseCountdown(by: 60)
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    TimerAdjustmentButton(title: "-1分", systemImage: "minus.circle") {
                        timer.decreaseCountdown(by: 60)
                    }

                    TimerAdjustmentButton(title: "-30秒", systemImage: "minus.circle") {
                        timer.decreaseCountdown(by: 30)
                    }

                    TimerAdjustmentButton(title: "+30秒", systemImage: "plus.circle") {
                        timer.increaseCountdown(by: 30)
                    }

                    TimerAdjustmentButton(title: "+1分", systemImage: "plus.circle") {
                        timer.increaseCountdown(by: 60)
                    }
                }
            }
        }
        .frame(maxWidth: metrics.timerColumnWidth)
        .disabled(!timer.canAdjustCountdown)
    }
}
