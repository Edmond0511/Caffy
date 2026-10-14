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

@MainActor
protocol SleepOverride {
    func setLidSleepDisabled(_ disabled: Bool)
}

enum Preset: CaseIterable, Hashable {
    case indefinitely, minutes30, hour1, hours2

    var duration: TimeInterval? {
        switch self {
        case .indefinitely: nil
        case .minutes30: 30 * 60
        case .hour1: 60 * 60
        case .hours2: 2 * 60 * 60
        }
    }
}

struct Battery: Equatable {
    let percent: Int
    let onBattery: Bool
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

    var stayAwakeWithLidClosed: Bool {
        didSet {
            if state != .off { sleepOverride.setLidSleepDisabled(stayAwakeWithLidClosed) }
        }
    }

    private let launcher: ProcessLauncher
    private let sleepOverride: SleepOverride
    private let pid: Int32
    private let now: () -> Date
    private var process: LaunchedProcess?
    private var session = 0

    init(
        launcher: ProcessLauncher,
        sleepOverride: SleepOverride,
        pid: Int32,
        keepDisplayOn: Bool,
        stayAwakeWithLidClosed: Bool,
        now: @escaping () -> Date = Date.init
    ) {
        self.launcher = launcher
        self.sleepOverride = sleepOverride
        self.pid = pid
        self.keepDisplayOn = keepDisplayOn
        self.stayAwakeWithLidClosed = stayAwakeWithLidClosed
        self.now = now
        // disablesleep outlives the app, so undo anything a crash left behind.
        if stayAwakeWithLidClosed { sleepOverride.setLidSleepDisabled(false) }
    }

    func start(_ preset: Preset) {
        start(for: preset.duration)
    }

    func start(for duration: TimeInterval?) {
        launch(until: duration.map { now().addingTimeInterval($0) })
    }

    func remaining(at date: Date) -> TimeInterval? {
        guard case .on(let endsAt?) = state else { return nil }
        return max(0, endsAt.timeIntervalSince(date))
    }

    func menuBarTimer(at date: Date) -> String? {
        guard state != .off else { return nil }
        guard let remaining = remaining(at: date) else { return "∞" }
        let seconds = Int(remaining.rounded(.up))
        let (h, m, s) = (seconds / 3600, seconds / 60 % 60, seconds % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    // A closed MacBook kept awake on battery can run flat in a bag.
    func checkBattery(_ battery: Battery) {
        if stayAwakeWithLidClosed, state != .off, battery.onBattery, battery.percent <= 10 {
            stop()
        }
    }

    // At .serious macOS is already throttling; a closed lid traps that heat.
    func checkThermal(_ thermalState: ProcessInfo.ThermalState) {
        if stayAwakeWithLidClosed, state != .off, thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            stop()
        }
    }

    func stop() {
        process?.stop()
        process = nil
        state = .off
        if stayAwakeWithLidClosed { sleepOverride.setLidSleepDisabled(false) }
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
            self.stop()
        })
        state = .on(endsAt: endsAt)
        if stayAwakeWithLidClosed { sleepOverride.setLidSleepDisabled(true) }
    }
}
