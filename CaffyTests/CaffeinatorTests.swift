import Foundation
import Testing
@testable import Caffy

@MainActor
final class FakeLauncher: ProcessLauncher {
    final class Process: LaunchedProcess {
        let arguments: [String]
        let onExit: @MainActor () -> Void
        var isRunning = true

        init(arguments: [String], onExit: @escaping @MainActor () -> Void) {
            self.arguments = arguments
            self.onExit = onExit
        }

        // Like the real process, the exit report arrives later, not inside stop().
        func stop() { isRunning = false }

        func exit() {
            isRunning = false
            reportExit()
        }

        func reportExit() { onExit() }
    }

    var launched: [Process] = []
    var current: Process? { launched.last }

    func launch(arguments: [String], onExit: @escaping @MainActor () -> Void) throws -> LaunchedProcess {
        let process = Process(arguments: arguments, onExit: onExit)
        launched.append(process)
        return process
    }
}

final class FakeClock {
    var now: Date
    init(_ now: Date) { self.now = now }
}

@MainActor
final class FakeSleepOverride: SleepOverride {
    var lidSleepDisabled = false

    func setLidSleepDisabled(_ disabled: Bool) { lidSleepDisabled = disabled }
}

@MainActor
struct CaffeinatorTests {
    let launcher = FakeLauncher()
    let sleepOverride = FakeSleepOverride()
    let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
    let clock: FakeClock

    init() { clock = FakeClock(start) }

    func makeCaffeinator(keepDisplayOn: Bool = true, stayAwakeWithLidClosed: Bool = false) -> Caffeinator {
        Caffeinator(
            launcher: launcher,
            sleepOverride: sleepOverride,
            pid: 4242,
            keepDisplayOn: keepDisplayOn,
            stayAwakeWithLidClosed: stayAwakeWithLidClosed,
            now: { [clock] in clock.now }
        )
    }

    @Test func lidOptionKeepsMacAwakeWithLidClosedOnlyDuringSession() {
        let caffeinator = makeCaffeinator(stayAwakeWithLidClosed: true)
        #expect(sleepOverride.lidSleepDisabled == false)

        caffeinator.start(.hour1)
        #expect(sleepOverride.lidSleepDisabled == true)

        caffeinator.stop()
        #expect(sleepOverride.lidSleepDisabled == false)
    }

    @Test func lidSleepReturnsWhenSessionEndsOnItsOwn() {
        let caffeinator = makeCaffeinator(stayAwakeWithLidClosed: true)
        caffeinator.start(.minutes15)

        launcher.current?.exit()

        #expect(sleepOverride.lidSleepDisabled == false)
    }

    @Test func togglingLidOptionMidSessionAppliesImmediately() {
        let caffeinator = makeCaffeinator()
        caffeinator.start(.indefinitely)

        caffeinator.stayAwakeWithLidClosed = true
        #expect(sleepOverride.lidSleepDisabled == true)

        caffeinator.stayAwakeWithLidClosed = false
        #expect(sleepOverride.lidSleepDisabled == false)
        #expect(caffeinator.state == .on(endsAt: nil))
    }

    @Test func clearsLidOverrideLeftByACrash() {
        sleepOverride.lidSleepDisabled = true

        _ = makeCaffeinator(stayAwakeWithLidClosed: true)

        #expect(sleepOverride.lidSleepDisabled == false)
    }

    @Test func lowBatteryEndsLidClosedSession() {
        let caffeinator = makeCaffeinator(stayAwakeWithLidClosed: true)
        caffeinator.start(.indefinitely)

        caffeinator.checkBattery(Battery(percent: 10, onBattery: true))

        #expect(caffeinator.state == .off)
        #expect(sleepOverride.lidSleepDisabled == false)
    }

    @Test func batteryCutoffOnlyGuardsLidClosedSessionsOnBattery() {
        let lidClosed = makeCaffeinator(stayAwakeWithLidClosed: true)
        lidClosed.start(.indefinitely)
        lidClosed.checkBattery(Battery(percent: 5, onBattery: false))
        lidClosed.checkBattery(Battery(percent: 11, onBattery: true))
        #expect(lidClosed.state == .on(endsAt: nil))

        let lidOpen = makeCaffeinator()
        lidOpen.start(.indefinitely)
        lidOpen.checkBattery(Battery(percent: 5, onBattery: true))
        #expect(lidOpen.state == .on(endsAt: nil))
    }

    @Test func startingIndefinitelyKeepsMacAwakeUntilStopped() {
        let caffeinator = makeCaffeinator()

        caffeinator.start(.indefinitely)

        #expect(launcher.current?.arguments == ["-w", "4242", "-d", "-i"])
        #expect(caffeinator.state == .on(endsAt: nil))
    }

    @Test func timedPresetEndsAfterItsDuration() {
        let caffeinator = makeCaffeinator()

        caffeinator.start(.minutes15)

        #expect(launcher.current?.arguments == ["-w", "4242", "-d", "-i", "-t", "900"])
        #expect(caffeinator.state == .on(endsAt: start.addingTimeInterval(900)))
    }

    @Test func displayCanSleepWhenKeepDisplayOnIsOff() {
        let caffeinator = makeCaffeinator(keepDisplayOn: false)

        caffeinator.start(.indefinitely)

        #expect(launcher.current?.arguments == ["-w", "4242", "-i"])
    }

    @Test func stoppingLetsMacSleepAgain() {
        let caffeinator = makeCaffeinator()
        caffeinator.start(.indefinitely)

        caffeinator.stop()

        #expect(launcher.current?.isRunning == false)
        #expect(caffeinator.state == .off)
    }

    @Test func turnsOffWhenCaffeinateExitsOnItsOwn() {
        let caffeinator = makeCaffeinator()
        caffeinator.start(.minutes15)

        launcher.current?.exit()

        #expect(caffeinator.state == .off)
    }

    @Test func choosingAnotherPresetReplacesTheSession() {
        let caffeinator = makeCaffeinator()
        caffeinator.start(.minutes15)
        let old = launcher.current!

        caffeinator.start(.hour1)
        old.reportExit()

        #expect(old.isRunning == false)
        #expect(launcher.current?.arguments == ["-w", "4242", "-d", "-i", "-t", "3600"])
        #expect(caffeinator.state == .on(endsAt: start.addingTimeInterval(3600)))
    }

    @Test func changingDisplaySettingMidSessionKeepsTheSameEndTime() {
        let caffeinator = makeCaffeinator()
        caffeinator.start(.minutes30)
        let old = launcher.current!
        clock.now = start.addingTimeInterval(10 * 60)

        caffeinator.keepDisplayOn = false
        old.reportExit()

        #expect(old.isRunning == false)
        #expect(launcher.current?.arguments == ["-w", "4242", "-i", "-t", "1200"])
        #expect(caffeinator.state == .on(endsAt: start.addingTimeInterval(30 * 60)))
    }

    @Test func reportsTimeRemainingOnlyForTimedSessions() {
        let caffeinator = makeCaffeinator()
        let eighteenMinutesIn = start.addingTimeInterval(18 * 60)
        #expect(caffeinator.remaining(at: eighteenMinutesIn) == nil)

        caffeinator.start(.hour1)
        #expect(caffeinator.remaining(at: eighteenMinutesIn) == TimeInterval(42 * 60))

        caffeinator.start(.indefinitely)
        #expect(caffeinator.remaining(at: eighteenMinutesIn) == nil)
    }
}
