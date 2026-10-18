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
            // Tests run inside this app with the user's defaults; keep them away from real sleep settings.
            sleepOverride: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
                ? PmsetSleepOverride() : NoSleepOverride(),
            notifier: UserGuardNotifier(),
            pid: ProcessInfo.processInfo.processIdentifier,
            keepDisplayOn: UserDefaults.standard.object(forKey: "keepDisplayOn") as? Bool ?? true,
            stayAwakeWithLidClosed: UserDefaults.standard.bool(forKey: "stayAwakeWithLidClosed")
        )
        _caffeinator = State(initialValue: caffeinator)
        _ticker = State(initialValue: Ticker {
            let lidClosed = Lid.isClosed
            if let battery = Battery.current() { caffeinator.checkBattery(battery, lidClosed: lidClosed) }
            caffeinator.checkThermal(ProcessInfo.processInfo.thermalState, lidClosed: lidClosed)
        })
        // caffeinate dies with the app via -w, but disablesleep has to be undone explicitly.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { caffeinator.stop(.quit) }
        }
        // Without the lid override, caffeinate can't hold the Mac awake through a lid close, so end the session.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                if !caffeinator.stayAwakeWithLidClosed { caffeinator.stop(.systemSleep) }
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            CaffyMenu(caffeinator: caffeinator, ticker: ticker, lidPermissionInstalled: $lidPermissionInstalled)
        } label: {
            if let timer = caffeinator.menuBarTimer(at: ticker.now) {
                Image(nsImage: menuBarImage(timer))
            } else {
                Image(systemName: "cup.and.saucer")
            }
        }
    }

    // The status item drops either the icon or the text when given both, so draw them as one image.
    private func menuBarImage(_ timer: String) -> NSImage {
        let renderer = ImageRenderer(content: HStack(spacing: 4) {
            Image(systemName: "cup.and.saucer.fill")
            Text(timer).monospacedDigit()
        }.font(.system(size: 13)))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }
}

struct CaffyMenu: View {
    let caffeinator: Caffeinator
    let ticker: Ticker
    @Binding var lidPermissionInstalled: Bool
    @State private var chosen: MenuChoice?
    @State private var durationMenu = DurationMenu(
        rememberedCustom: UserDefaults.standard.object(forKey: "customDuration") as? TimeInterval
    )
    @State private var customPanel = CustomDurationPanel()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        ForEach(durationMenu.choices, id: \.self) { choice in
            Toggle(choice.title, isOn: Binding(
                get: { caffeinator.state != .off && chosen == choice },
                set: { isOn in isOn ? start(choice) : caffeinator.stop() }
            ))
        }
        Button("Custom…") {
            let initialText = durationMenu.rememberedCustom.map { String(Int($0 / 60)) } ?? ""
            customPanel.show(initialText: initialText) { duration in
                start(durationMenu.choose(custom: duration))
                UserDefaults.standard.set(durationMenu.rememberedCustom, forKey: "customDuration")
            }
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
                // macOS only prompts once, so this also reaches users who installed the rule earlier.
                if isOn { UserGuardNotifier.requestPermission() }
                setStayAwakeWithLidClosed(isOn)
            }
        ))
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

    private func start(_ choice: MenuChoice) {
        chosen = choice
        caffeinator.start(for: choice.duration)
        ticker.restart()
    }

    private func setStayAwakeWithLidClosed(_ isOn: Bool) {
        caffeinator.stayAwakeWithLidClosed = isOn
        UserDefaults.standard.set(isOn, forKey: "stayAwakeWithLidClosed")
    }
}

// Menu contents only re-render on observed changes, so tick the clock for the countdown.
@MainActor
@Observable
final class Ticker {
    private(set) var now = Date()
    private var timer: Timer?

    private let onTick: @MainActor () -> Void

    init(onTick: @escaping @MainActor () -> Void) {
        self.onTick = onTick
        restart()
    }

    // Restarted on each session start so ticks land on the countdown's second boundaries.
    func restart() {
        timer?.invalidate()
        now = Date()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.now = Date()
                self?.onTick()
            }
        }
        // .common keeps it firing while the menu is open, so `now` isn't stale when a preset is picked.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}

extension MenuChoice {
    var title: String {
        switch self {
        case .preset(let preset): preset.title
        case .custom(let duration): durationTitle(duration)
        }
    }
}

extension Preset {
    var title: String {
        switch self {
        case .indefinitely: "Indefinitely"
        case .minutes30: "30 Minutes"
        case .hour1: "1 Hour"
        case .hours2: "2 Hours"
        }
    }
}
