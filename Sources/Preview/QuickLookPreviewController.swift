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
        
        // Set window level to floating panel (above normal windows)
        panel.level = .floating
        
        // Force the panel to appear on top regardless of other windows
        panel.orderFrontRegardless()
        
        // Make it key window to receive keyboard events
        panel.makeKey()
        
        // Center and size the panel appropriately
        DispatchQueue.main.async {
            // Update the current index after panel is shown to ensure correct image
            panel.currentPreviewItemIndex = self.currentIndex
            
            // Ensure the panel refreshes to show the correct item
            panel.reloadData()
            
            // Get the current item's image size to calculate appropriate panel size
            var imageSize: NSSize?
            if self.currentIndex < self.urls.count {
                let image = NSImage(contentsOf: self.urls[self.currentIndex])
                imageSize = image?.size
            }
            self.centerPanelWithSize(panel: panel, imageSize: imageSize)
            
            // Make sure it stays on top
            panel.makeKeyAndOrderFront(nil)
        }
    }
    
    /// Center the panel on screen with appropriate size
    private func centerPanelWithSize(panel: QLPreviewPanel, imageSize: NSSize?) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let maxWidth = screenFrame.width * 0.9  // Use 90% of screen width
        let maxHeight = screenFrame.height * 0.9  // Use 90% of screen height
        
        var panelWidth: CGFloat
        var panelHeight: CGFloat
        
        if let imgSize = imageSize, imgSize.width > 0 && imgSize.height > 0 {
            // Calculate size maintaining aspect ratio
            let aspectRatio = imgSize.width / imgSize.height
            
            if aspectRatio > 1 {
                // Landscape: fit to width
                panelWidth = min(maxWidth, imgSize.width)
                panelHeight = panelWidth / aspectRatio
            } else {
                // Portrait: fit to height
                panelHeight = min(maxHeight, imgSize.height)
                panelWidth = panelHeight * aspectRatio
            }
            
            // Ensure it doesn't exceed screen bounds
            if panelWidth > maxWidth {
                panelWidth = maxWidth
                panelHeight = panelWidth / aspectRatio
            }
            if panelHeight > maxHeight {
                panelHeight = maxHeight
                panelWidth = panelHeight * aspectRatio
            }
            
            // Minimum size
            panelWidth = max(panelWidth, 400)
            panelHeight = max(panelHeight, 300)
        } else {
            // Default size if we can't determine image size
            panelWidth = min(maxWidth, 800)
            panelHeight = min(maxHeight, 600)
        }
        
        // Center on screen
        let x = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        let y = screenFrame.origin.y + (screenFrame.height - panelHeight) / 2
        
        let frame = NSRect(x: x, y: y, width: panelWidth, height: panelHeight)
        panel.setFrame(frame, display: true, animate: true)
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
            case 49: // Spacebar
                panel.orderOut(nil)
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
    
    
    func previewPanel(_ panel: QLPreviewPanel!, transitionImageFor item: QLPreviewItem!, contentRect: UnsafeMutablePointer<NSRect>!) -> NSImage! {
        // Provide transition image if needed, otherwise return nil for default behavior
        return nil
    }
}