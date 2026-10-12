import AppKit
import SwiftUI

// Borderless panels can't become key by default, and the field needs typing.
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class CustomDurationPanel {
    private lazy var panel: KeyPanel = {
        // Non-activating, so the app you were in stays frontmost.
        let panel = KeyPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        // Clicking away to check something shouldn't lose what was typed.
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        return panel
    }()

    func show(initialText: String, onStart: @escaping (TimeInterval) -> Void) {
        let host = NSHostingView(rootView: CustomDurationForm(
            text: initialText,
            onStart: { [weak self] duration in
                self?.panel.orderOut(nil)
                onStart(duration)
            },
            onClose: { [weak self] in self?.panel.orderOut(nil) }
        ))
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        positionBelowPointer()
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
    }

    // The pointer is on the Custom… item, so this drops the panel just under Caffy's icon.
    private func positionBelowPointer() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = min(max(mouse.x - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: visible.maxY - size.height - 8))
    }
}

private struct CustomDurationForm: View {
    @State var text: String
    let onStart: (TimeInterval) -> Void
    let onClose: () -> Void
    @State private var showsError = false
    @FocusState private var focused: Bool

    private var duration: TimeInterval? { CustomDuration.parse(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom duration")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.foreground)
                    Text("How long to keep your Mac awake.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mutedForeground)
                }
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.icon)
                    .offset(x: 6, y: -6)
            }

            // The readout and the error share the input's trailing edge, so the panel never changes height.
            HStack(spacing: 8) {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    // AppKit ignores a styled prompt's color, so draw the placeholder ourselves.
                    .background(alignment: .leading) {
                        if text.isEmpty {
                            Text("45m, 1h30, 2h").foregroundStyle(Theme.mutedForeground.opacity(0.7))
                        }
                    }
                if showsError {
                    Text("1 min to 24 hr")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.destructive)
                } else if let duration {
                    Text(durationTitle(duration))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mutedForeground)
                }
            }
            .inputChrome(focused: focused, invalid: showsError)
            .onChange(of: text) { showsError = false }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onClose)
                    .buttonStyle(.outline)
                    .keyboardShortcut(.cancelAction)
                Button("Start", action: start)
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(width: 300)
        .background {
            ZStack {
                Theme.background.allowsHitTesting(false)
                WindowDragArea()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border).allowsHitTesting(false))
        .onAppear { DispatchQueue.main.async { focused = true } }
    }

    private func start() {
        if let duration { onStart(duration) } else { showsError = true }
    }
}
