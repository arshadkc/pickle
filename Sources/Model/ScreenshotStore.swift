import Foundation
import SwiftUI

struct ScreenshotItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let date: Date
    
    static func == (lhs: ScreenshotItem, rhs: ScreenshotItem) -> Bool {
        return lhs.url == rhs.url
    }
}

class ScreenshotStore: ObservableObject {
    static let shared = ScreenshotStore()
    
    @Published var items: [ScreenshotItem] = []
    @Published var permissionDenied: Bool = false
    @Published var permissionDeniedFolder: String? = nil
    
    // Debouncing mechanism for batch updates
    private var pendingUpdates: [ScreenshotItem] = []
    private var updateTimer: Timer?
    
    private init() {}
    
    func reload(from url: URL) {
        // Reset permission error state
        DispatchQueue.main.async {
            self.permissionDenied = false
            self.permissionDeniedFolder = nil
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.creationDateKey])
            
            let imageExtensions = ["png", "jpg", "jpeg", "heic", "tiff"]
            let imageFiles = contents.filter { url in
                let ext = url.pathExtension.lowercased()
                let fileName = url.lastPathComponent
                return imageExtensions.contains(ext) && !fileName.hasPrefix(".")
            }
            
                let screenshotItems = imageFiles.compactMap { url -> ScreenshotItem? in
                    guard let date = url.creationDate else { return nil }
                    return ScreenshotItem(url: url, date: date)
                }
            
            items = Array(screenshotItems.sorted { $0.date > $1.date }.prefix(50))
            
        } catch {
            print("Error reloading screenshots: \(error)")
            items = []
            
            // Check if this is a permission error
            let nsError = error as NSError
            if nsError.domain == NSPOSIXErrorDomain && (nsError.code == EACCES || nsError.code == EPERM) {
                DispatchQueue.main.async {
                    self.permissionDenied = true
                    self.permissionDeniedFolder = url.lastPathComponent
                    AnalyticsService.shared.trackPermissionDenied(folder: url.lastPathComponent)
                }
            }
        }
    }
    
    func insertIfNew(_ url: URL) {
        guard let date = url.creationDate else { return }
        
        let newItem = ScreenshotItem(url: url, date: date)
        
        // Check if item already exists
        if !items.contains(newItem) && !pendingUpdates.contains(newItem) {
            // Add to pending updates instead of immediately updating UI
            pendingUpdates.append(newItem)
            
            // Cancel existing timer
            updateTimer?.invalidate()
            
            // Set new timer to batch process updates
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                self?.processPendingUpdates()
            }
        }
    }
    
    /// Immediately inserts a new screenshot item into the store for instant UI updates
    func insertImmediately(_ url: URL) {
        guard let date = url.creationDate else { return }
        
        let newItem = ScreenshotItem(url: url, date: date)
        
        // Check if item already exists
        if !items.contains(newItem) {
            DispatchQueue.main.async {
                // Insert at the beginning (newest first)
                self.items.insert(newItem, at: 0)
                
                // Sort by date (newest first) and trim to 50 items
                self.items = Array(self.items.sorted { $0.date > $1.date }.prefix(50))
            }
        }
    }
    
    private func processPendingUpdates() {
        guard !pendingUpdates.isEmpty else { return }
        
        DispatchQueue.main.async {
            // Track new screenshots
            for item in self.pendingUpdates {
                if !self.items.contains(item) {
                    self.items.insert(item, at: 0)
                    AnalyticsService.shared.trackScreenshotDetected()
                }
            }
            
            // Sort by date (newest first) and trim to 50 items
            self.items = Array(self.items.sorted { $0.date > $1.date }.prefix(50))
            
            // Clear pending updates
            self.pendingUpdates.removeAll()
        }
    }
    
    func updateItem(oldURL: URL, newURL: URL) {
        if let index = items.firstIndex(where: { $0.url == oldURL }) {
            let updatedItem = ScreenshotItem(url: newURL, date: items[index].date)
            items[index] = updatedItem
        }
    }
    
    // Track files that are being renamed to prevent notifications
    private var renamedFiles: Set<String> = []
    
    func markAsRenamed(_ url: URL) {
        renamedFiles.insert(url.lastPathComponent)
        
        // Remove from tracking after a delay to allow for file system operations
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.renamedFiles.remove(url.lastPathComponent)
        }
    }
    
    func isRenamedFile(_ url: URL) -> Bool {
        return renamedFiles.contains(url.lastPathComponent)
    }
    
    func removeItem(with url: URL) {
        items.removeAll { $0.url == url }
        AnalyticsService.shared.trackScreenshotDeleted()
    }
}
