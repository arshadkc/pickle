import AppKit

final class QuitConfirm {
    static func present(attachedTo window: NSWindow?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Quit Pickle?"
        alert.informativeText = "Are you sure you want to quit Pickle? Any ongoing uploads will be stopped."
        alert.addButton(withTitle: "Cancel")
        let quitBtn = alert.addButton(withTitle: "Quit")
        quitBtn.hasDestructiveAction = true
        
        // Make Cancel the default button (Return key)
        alert.buttons.first?.keyEquivalent = "\r"
        
        if let win = window {
            alert.beginSheetModal(for: win) { response in
                if response == .alertSecondButtonReturn { NSApp.terminate(nil) }
            }
        } else {
            // Fallback if no window available
            let response = alert.runModal()
            if response == .alertSecondButtonReturn { NSApp.terminate(nil) }
        }
    }
}
