import Foundation
import os

struct CaffeinateLauncher: ProcessLauncher {
    func launch(arguments: [String], onExit: @escaping @MainActor () -> Void) throws -> LaunchedProcess {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = arguments
        process.terminationHandler = { process in
            Logger(subsystem: "com.edmondyang.caffy", category: "session").notice(
                "caffeinate \(process.processIdentifier) exited: status \(process.terminationStatus), \(process.terminationReason == .uncaughtSignal ? "signal" : "exit", privacy: .public)"
            )
            Task { @MainActor in onExit() }
        }
        try process.run()
        return RunningCaffeinate(process: process)
    }
}

private struct RunningCaffeinate: LaunchedProcess {
    let process: Process

    func stop() { process.terminate() }
}
