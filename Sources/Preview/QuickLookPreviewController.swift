import AppKit
import Quartz

final class QuickLookPreviewController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookPreviewController()

    private var urls: [URL] = []
    private var currentIndex = 0

    /// Show one or many items in Quick Look using QLPreviewPanel.
    func show(urls: [URL], startAt index: Int = 0) {
        guard !urls.isEmpty else { return }
        self.urls = urls
        self.currentIndex = max(0, min(index, urls.count - 1))
        
        // Get the shared Quick Look panel
        guard let panel = QLPreviewPanel.shared() else { return }
        
        // Set ourselves as the data source and delegate
        panel.dataSource = self
        panel.delegate = self
        
        // Set the current index BEFORE showing the panel to avoid showing previous image
        panel.currentPreviewItemIndex = self.currentIndex
        
        // Activate the app first to ensure it's in the foreground
        NSApp.activate(ignoringOtherApps: true)
        
        // Show the panel first
        panel.makeKeyAndOrderFront(nil)
        
        // Force the panel to be on top with multiple approaches
        DispatchQueue.main.async {
            // Try different window level approaches
            panel.level = .screenSaver
            panel.orderFrontRegardless()
            
            // Also try making it key and front
            panel.makeKeyAndOrderFront(nil)
            
            // Additional delay to ensure it stays on top
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                panel.level = .screenSaver
                panel.orderFrontRegardless()
                panel.makeKeyAndOrderFront(nil)
            }
        }
    }

    /// Convenience for a single file
    func showSingle(url: URL) {
        show(urls: [url], startAt: 0)
    }
    
    // MARK: - QLPreviewPanelDataSource
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return urls.count
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return urls[index] as NSURL
    }
    
    // MARK: - QLPreviewPanelDelegate
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        // Handle keyboard events for navigation
        if event.type == .keyDown {
            switch event.keyCode {
            case 123: // Left arrow
                if currentIndex > 0 {
                    currentIndex -= 1
                    panel.currentPreviewItemIndex = currentIndex
                }
                return true
            case 124: // Right arrow
                if currentIndex < urls.count - 1 {
                    currentIndex += 1
                    panel.currentPreviewItemIndex = currentIndex
                }
                return true
            case 53: // ESC key
                panel.orderOut(nil)
                return true
            default:
                break
            }
        }
        return false
    }
}