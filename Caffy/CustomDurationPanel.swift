import AppKit
import SwiftUI

@MainActor
final class CustomDurationPanel {
    private lazy var panel: NSPanel = {
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
        panel.title = "Custom Duration"
        panel.isFloatingPanel = true
        // Clicking away to check something shouldn't lose what was typed.
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        return panel
    }()

    func show(initialText: String, onStart: @escaping (TimeInterval) -> Void) {
        panel.contentView = NSHostingView(rootView: CustomDurationForm(
            text: initialText,
            onStart: { [weak self] duration in
                self?.panel.close()
                onStart(duration)
            },
            onCancel: { [weak self] in self?.panel.close() }
        ))
        panel.setContentSize(panel.contentView!.fittingSize)
        panel.center()
        // A menu bar app isn't active, so the panel can't take typing until it is.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}

private struct CustomDurationForm: View {
    @State var text: String
    let onStart: (TimeInterval) -> Void
    let onCancel: () -> Void
    @FocusState private var focused: Bool

    private var duration: TimeInterval? { CustomDuration.parse(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("45, 1h30, 2h", text: $text)
                .focused($focused)
                .frame(width: 220)
            Text(duration.map { "→ \(durationTitle($0))" } ?? "1 min to 24 hr, like 45, 1h30 or 2h")
                .font(.callout)
                .foregroundStyle(duration == nil && !text.isEmpty ? .red : .secondary)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Start") { if let duration { onStart(duration) } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(duration == nil)
            }
        }
        .padding()
        .onAppear { focused = true }
    }
}
