import ServiceManagement
import SwiftUI

@main
struct CaffyApp: App {
    @State private var caffeinator: Caffeinator
    @State private var ticker: Ticker
    @State private var lidPermissionInstalled = LidSleepPermission.isInstalled

    init() {
        let caffeinator = Caffeinator(
            launcher: CaffeinateLauncher(),
            sleepOverride: PmsetSleepOverride(),
            pid: ProcessInfo.processInfo.processIdentifier,
            keepDisplayOn: UserDefaults.standard.object(forKey: "keepDisplayOn") as? Bool ?? true,
            stayAwakeWithLidClosed: UserDefaults.standard.bool(forKey: "stayAwakeWithLidClosed")
        )
        _caffeinator = State(initialValue: caffeinator)
        _ticker = State(initialValue: Ticker {
            if let battery = Battery.current() { caffeinator.checkBattery(battery) }
        })
        // caffeinate dies with the app via -w, but disablesleep has to be undone explicitly.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { caffeinator.stop() }
        }
    }

    var body: some Scene {
        MenuBarExtra("Caffy", systemImage: caffeinator.state == .off ? "cup.and.saucer" : "cup.and.saucer.fill") {
            CaffyMenu(caffeinator: caffeinator, ticker: ticker, lidPermissionInstalled: $lidPermissionInstalled)
        }
    }
}

struct CaffyMenu: View {
    let caffeinator: Caffeinator
    let ticker: Ticker
    @Binding var lidPermissionInstalled: Bool
    @State private var chosenPreset: Preset?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Text(statusText)

        Divider()

        ForEach(Preset.allCases, id: \.self) { preset in
            Toggle(preset.title, isOn: Binding(
                get: { caffeinator.state != .off && chosenPreset == preset },
                set: { isOn in
                    if isOn {
                        chosenPreset = preset
                        caffeinator.start(preset)
                    } else {
                        caffeinator.stop()
                    }
                }
            ))
        }

        if caffeinator.state != .off {
            Divider()
            Button("Turn Off") { caffeinator.stop() }
        }

        Divider()

        Toggle("Keep Display On", isOn: Binding(
            get: { caffeinator.keepDisplayOn },
            set: {
                caffeinator.keepDisplayOn = $0
                UserDefaults.standard.set($0, forKey: "keepDisplayOn")
            }
        ))
        Toggle("Stay Awake with Lid Closed", isOn: Binding(
            get: { lidPermissionInstalled && caffeinator.stayAwakeWithLidClosed },
            set: { isOn in
                if isOn && !lidPermissionInstalled {
                    lidPermissionInstalled = LidSleepPermission.install()
                    guard lidPermissionInstalled else { return }
                }
                setStayAwakeWithLidClosed(isOn)
            }
        ))
        if lidPermissionInstalled {
            Button("Remove Lid-Closed Permission…") {
                setStayAwakeWithLidClosed(false)
                LidSleepPermission.remove()
                lidPermissionInstalled = LidSleepPermission.isInstalled
            }
        }
        Toggle("Launch at Login", isOn: Binding(
            get: { launchAtLogin },
            set: { enable in
                try? enable ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        ))

        Divider()

        Button("Quit Caffy") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func setStayAwakeWithLidClosed(_ isOn: Bool) {
        caffeinator.stayAwakeWithLidClosed = isOn
        UserDefaults.standard.set(isOn, forKey: "stayAwakeWithLidClosed")
    }

    private var statusText: String {
        switch caffeinator.state {
        case .off:
            return "Caffy: Off"
        case .on(endsAt: nil):
            return "Caffy: On · Indefinitely"
        case .on:
            let minutes = Int(((caffeinator.remaining(at: ticker.now) ?? 0) / 60).rounded(.up))
            let left = minutes >= 60 ? "\(minutes / 60) hr \(minutes % 60) min" : "\(minutes) min"
            return "Caffy: On · \(left) left"
        }
    }
}

// Menu contents only re-render on observed changes, so tick the clock for the countdown.
@MainActor
@Observable
final class Ticker {
    private(set) var now = Date()
    private var timer: Timer?

    init(onTick: @escaping @MainActor () -> Void) {
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.now = Date()
                onTick()
            }
        }
    }
}

extension Preset {
    var title: String {
        switch self {
        case .indefinitely: "Indefinitely"
        case .minutes15: "15 Minutes"
        case .minutes30: "30 Minutes"
        case .hour1: "1 Hour"
        case .hours2: "2 Hours"
        case .hours4: "4 Hours"
        }
    }
}
