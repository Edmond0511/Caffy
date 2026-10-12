import Foundation
import Testing
@testable import Caffy

// Runs real caffeinate and reads the system's sleep assertions, so these take a few seconds.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct CaffeineSessionTests {
    let pid = ProcessInfo.processInfo.processIdentifier

    func makeCaffeinator() -> Caffeinator {
        Caffeinator(
            launcher: CaffeinateLauncher(),
            sleepOverride: FakeSleepOverride(),
            pid: pid,
            keepDisplayOn: false,
            stayAwakeWithLidClosed: false
        )
    }

    func macIsHeldAwake() throws -> Bool {
        let pmset = Process()
        pmset.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        pmset.arguments = ["-g", "assertions"]
        let output = Pipe()
        pmset.standardOutput = output
        try pmset.run()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        pmset.waitUntilExit()
        return text.contains("caffeinate asserting on behalf of Process ID \(pid) ")
    }

    @Test func timedSessionHoldsMacAwake() async throws {
        let caffeinator = makeCaffeinator()

        caffeinator.start(for: 2)
        try await Task.sleep(for: .milliseconds(300))

        #expect(try macIsHeldAwake())
        caffeinator.stop()
    }

    @Test func timedSessionEndsAndLetsMacSleepWhenTimeRunsOut() async throws {
        let caffeinator = makeCaffeinator()

        caffeinator.start(for: 2)
        try await Task.sleep(for: .seconds(3))

        #expect(caffeinator.state == .off)
        #expect(try !macIsHeldAwake())
    }

    @Test func turningOffLetsMacSleepRightAway() async throws {
        let caffeinator = makeCaffeinator()
        caffeinator.start(for: 60)
        try await Task.sleep(for: .milliseconds(300))

        caffeinator.stop()
        try await Task.sleep(for: .milliseconds(300))

        #expect(try !macIsHeldAwake())
    }
}
