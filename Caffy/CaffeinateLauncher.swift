import Foundation

struct CaffeinateLauncher: ProcessLauncher {
    func launch(arguments: [String], onExit: @escaping @MainActor () -> Void) throws -> LaunchedProcess {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = arguments
        process.terminationHandler = { _ in
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
