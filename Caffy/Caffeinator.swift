import Foundation
import Observation

@MainActor
protocol LaunchedProcess {
    func stop()
}

@MainActor
protocol ProcessLauncher {
    func launch(arguments: [String], onExit: @escaping @MainActor () -> Void) throws -> LaunchedProcess
}

enum Preset: CaseIterable, Hashable {
    case indefinitely, minutes15, minutes30, hour1, hours2, hours4

    var duration: TimeInterval? {
        switch self {
        case .indefinitely: nil
        case .minutes15: 15 * 60
        case .minutes30: 30 * 60
        case .hour1: 60 * 60
        case .hours2: 2 * 60 * 60
        case .hours4: 4 * 60 * 60
        }
    }
}

enum CaffeineState: Equatable {
    case off
    case on(endsAt: Date?)
}

@MainActor
@Observable
final class Caffeinator {
    private(set) var state: CaffeineState = .off
    var keepDisplayOn: Bool {
        didSet {
            // caffeinate's flags are fixed at launch, so relaunch with the same end time.
            if case .on(let endsAt) = state { launch(until: endsAt) }
        }
    }

    private let launcher: ProcessLauncher
    private let pid: Int32
    private let now: () -> Date
    private var process: LaunchedProcess?
    private var session = 0

    init(launcher: ProcessLauncher, pid: Int32, keepDisplayOn: Bool, now: @escaping () -> Date = Date.init) {
        self.launcher = launcher
        self.pid = pid
        self.keepDisplayOn = keepDisplayOn
        self.now = now
    }

    func start(_ preset: Preset) {
        launch(until: preset.duration.map { now().addingTimeInterval($0) })
    }

    func remaining(at date: Date) -> TimeInterval? {
        guard case .on(let endsAt?) = state else { return nil }
        return max(0, endsAt.timeIntervalSince(date))
    }

    func stop() {
        process?.stop()
        process = nil
        state = .off
    }

    private func launch(until endsAt: Date?) {
        var arguments = ["-w", String(pid)] + (keepDisplayOn ? ["-d", "-i"] : ["-i"])
        if let endsAt {
            arguments += ["-t", String(Int(endsAt.timeIntervalSince(now()).rounded(.up)))]
        }
        stop()
        session += 1
        let session = session
        process = try? launcher.launch(arguments: arguments, onExit: { [weak self] in
            // A stopped process reports its exit late; ignore it once replaced.
            guard let self, self.session == session else { return }
            self.process = nil
            self.state = .off
        })
        state = .on(endsAt: endsAt)
    }
}
