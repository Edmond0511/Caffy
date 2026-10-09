import AppKit
import IOKit.ps

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

    /// Shows the macOS admin prompt once, then lets this user toggle disablesleep without a password.
    static func install() -> Bool {
        let user = NSUserName()
        guard user.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else { return false }
        let rule = "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
        // Built and validated entirely as root so nothing user-writable can swap the file before install.
        let script = """
        t=$(/usr/bin/mktemp) && /bin/echo '\(rule)' > "$t" && /usr/sbin/visudo -cf "$t" && \
        /usr/bin/install -m 0440 -o root -g wheel "$t" \(rulePath); s=$?; /bin/rm -f "$t"; exit $s
        """
        return runAsAdmin(script) && isInstalled
    }

    static func remove() {
        runAsAdmin("/usr/bin/pmset -a disablesleep 0; /bin/rm -f \(rulePath)")
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

    @discardableResult
    private static func runAsAdmin(_ shell: String) -> Bool {
        let escaped = shell.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")?.executeAndReturnError(&error)
        return error == nil
    }
}

extension Battery {
    /// nil on Macs without a battery.
    static func current() -> Battery? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let capacity = description[kIOPSCurrentCapacityKey] as? Int,
                  let maxCapacity = description[kIOPSMaxCapacityKey] as? Int, maxCapacity > 0
            else { continue }
            return Battery(
                percent: capacity * 100 / maxCapacity,
                onBattery: description[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue
            )
        }
        return nil
    }
}
