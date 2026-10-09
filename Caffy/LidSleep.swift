import Foundation

// Needs the sudoers rule from LidSleepPermission; `sudo -n` fails instead of prompting.
struct PmsetSleepOverride: SleepOverride {
    func setLidSleepDisabled(_ disabled: Bool) {
        LidSleepPermission.runSudo(["/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0"])
    }
}

enum LidSleepPermission {
    static let rulePath = "/etc/sudoers.d/caffy"

    static var isInstalled: Bool {
        runSudo(["-l", "/usr/bin/pmset", "-a", "disablesleep", "1"])
    }

    @discardableResult
    static func runSudo(_ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n"] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
