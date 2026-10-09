import SwiftUI

@main
struct CaffyApp: App {
    var body: some Scene {
        MenuBarExtra("Caffy", systemImage: "cup.and.saucer") {
            Button("Quit Caffy") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
