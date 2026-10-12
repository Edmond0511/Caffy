import AppKit
import SwiftUI

// Ported from clipq's shadcn/ui pieces so both apps share a look.
enum Theme {
    static let background = dynamic(light: 0xFFFFFF, dark: 0x18181B)
    static let foreground = dynamic(light: 0x09090B, dark: 0xFAFAFA)
    static let muted = dynamic(light: 0xF4F4F5, dark: 0x27272A)
    static let mutedForeground = dynamic(light: 0x71717A, dark: 0xA1A1AA)
    static let border = dynamic(light: 0xE4E4E7, dark: 0x27272A)
    static let ring = dynamic(light: 0xA1A1AA, dark: 0x52525B)
    static let destructive = dynamic(light: 0xDC2626, dark: 0xF87171)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

struct ShadButtonStyle: ButtonStyle {
    enum Variant { case primary, outline }
    var variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        ShadButton(configuration: configuration, variant: variant)
    }

    private struct ShadButton: View {
        let configuration: Configuration
        let variant: Variant
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .foregroundStyle(variant == .primary ? Theme.background : Theme.foreground)
                .background(RoundedRectangle(cornerRadius: 6).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(variant == .outline ? Theme.border : .clear))
                .opacity(configuration.isPressed ? 0.8 : 1)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }

        private var fill: Color {
            switch variant {
            case .primary: Theme.foreground.opacity(hovering ? 0.9 : 1)
            case .outline: hovering ? Theme.muted : .clear
            }
        }
    }
}

extension ButtonStyle where Self == ShadButtonStyle {
    static var primary: ShadButtonStyle { ShadButtonStyle(variant: .primary) }
    static var outline: ShadButtonStyle { ShadButtonStyle(variant: .outline) }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        IconButton(configuration: configuration)
    }

    private struct IconButton: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hovering ? Theme.foreground : Theme.mutedForeground)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Theme.muted : .clear))
                .opacity(configuration.isPressed ? 0.7 : 1)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var icon: IconButtonStyle { IconButtonStyle() }
}

// SwiftUI's own window drag gesture needs macOS 15.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

extension View {
    func inputChrome(focused: Bool, invalid: Bool = false) -> some View {
        font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.background))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(
                invalid ? Theme.destructive : focused ? Theme.ring : Theme.border
            ))
    }
}
