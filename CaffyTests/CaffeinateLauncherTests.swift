import Foundation
import Testing
@testable import Caffy

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CaffeinateLauncherTests {
    func launchAndAwaitExit(_ arguments: [String], then action: (LaunchedProcess) -> Void = { _ in }) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                let process = try CaffeinateLauncher().launch(arguments: arguments, onExit: { continuation.resume() })
                action(process)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    @Test func stoppingRealCaffeinateReportsItsExit() async throws {
        let clock = ContinuousClock()
        let started = clock.now

        try await launchAndAwaitExit(["-t", "60"], then: { $0.stop() })

        #expect(clock.now - started < .seconds(5))
    }

    @Test func realCaffeinateReportsWhenItsTimerEnds() async throws {
        try await launchAndAwaitExit(["-t", "1"])
    }
}
