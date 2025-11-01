import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()
    
    private let screenshotStore = ScreenshotStore.shared
    private let directoryWatcher = DirectoryWatcher()
    
    override init() {
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize analytics
        AnalyticsService.shared.initialize()
        AnalyticsService.shared.trackAppLaunch()
        
        // Hide app from dock (menu bar only)
        NSApp.setActivationPolicy(.accessory)
        
        // Set app icon
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = icon
            
            // Also try to set the menu bar icon
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let statusItem = NSApp.mainMenu?.items.first?.submenu?.items.first {
                    statusItem.image = icon
                }
            }
        }
        
        // Initialize location manager
        _ = ScreenshotLocationManager.shared
        
        // Listen for location changes and restart watcher
        NotificationCenter.default.addObserver(
            forName: .screenshotLocationChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartDirectoryWatcher()
        }
        
        // Get screenshot folder and start watching
        let screenshotFolderURL = ScreenshotFolderResolver.getScreenshotFolderURL()
        screenshotStore.reload(from: screenshotFolderURL)
        
        // Set permission denied callback
        directoryWatcher.onPermissionDenied = { [weak self] url in
            DispatchQueue.main.async {
                self?.screenshotStore.permissionDenied = true
                self?.screenshotStore.permissionDeniedFolder = url.lastPathComponent
            }
        }
        
        directoryWatcher.startWatching(url: screenshotFolderURL, 
            onNewFile: { [weak self] newFileURL in
                DispatchQueue.main.async {
                    self?.screenshotStore.insertIfNew(newFileURL)
                }
            },
            onFileDeleted: { [weak self] deletedFileURL in
                DispatchQueue.main.async {
                    self?.screenshotStore.removeItem(with: deletedFileURL)
                }
            }
        )
    }
    
    func restartDirectoryWatcher() {
        // Stop current watcher
        directoryWatcher.stopWatching()
        
        // Get the new screenshot folder URL
        let screenshotFolderURL = ScreenshotFolderResolver.getScreenshotFolderURL()
        screenshotStore.reload(from: screenshotFolderURL)
        
        // Set permission denied callback
        directoryWatcher.onPermissionDenied = { [weak self] url in
            DispatchQueue.main.async {
                self?.screenshotStore.permissionDenied = true
                self?.screenshotStore.permissionDeniedFolder = url.lastPathComponent
            }
        }
        
        // Start watching the new location
        directoryWatcher.startWatching(url: screenshotFolderURL, 
            onNewFile: { [weak self] newFileURL in
                DispatchQueue.main.async {
                    self?.screenshotStore.insertIfNew(newFileURL)
                }
            },
            onFileDeleted: { [weak self] deletedFileURL in
                DispatchQueue.main.async {
                    self?.screenshotStore.removeItem(with: deletedFileURL)
                }
            }
        )
    }
}

@main
struct PickleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("PickleApp", image: "MenuBarIcon") {
            ToastHost {
                MenuBarView()
            }
        }
        .menuBarExtraStyle(.window)
    }
}
