import SwiftUI
import UserNotifications
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    static let shared = AppDelegate()
    
    private let screenshotStore = ScreenshotStore.shared
    private let directoryWatcher = DirectoryWatcher()
    
    override init() {
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
        
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register notification categories
        registerNotificationCategories()
        
        // Initialize location manager
        _ = ScreenshotLocationManager.shared
        
        // Don't request permissions at startup - will request when menu is first opened
        
        // Get screenshot folder and start watching
        let screenshotFolderURL = ScreenshotFolderResolver.getScreenshotFolderURL()
        screenshotStore.reload(from: screenshotFolderURL)
        
        directoryWatcher.startWatching(url: screenshotFolderURL, 
            onNewFile: { [weak self] newFileURL in
                DispatchQueue.main.async {
                    self?.screenshotStore.insertIfNew(newFileURL)
                    NotificationSender.show(
                        title: "New Screenshot",
                        body: "Screenshot saved: \(newFileURL.lastPathComponent)",
                        categoryIdentifier: "SCREENSHOT_NEW",
                        userInfo: ["path": newFileURL.path]
                    )
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
        
        // Start watching the new location
        directoryWatcher.startWatching(url: screenshotFolderURL, 
            onNewFile: { [weak self] newFileURL in
                DispatchQueue.main.async {
                    self?.screenshotStore.insertIfNew(newFileURL)
                    NotificationSender.show(
                        title: "New Screenshot",
                        body: "Screenshot saved: \(newFileURL.lastPathComponent)",
                        categoryIdentifier: "SCREENSHOT_NEW",
                        userInfo: ["path": newFileURL.path]
                    )
                }
            },
            onFileDeleted: { [weak self] deletedFileURL in
                DispatchQueue.main.async {
                    self?.screenshotStore.removeItem(with: deletedFileURL)
                }
            }
        )
    }
    
    private func registerNotificationCategories() {
        let openShotAction = UNNotificationAction(
            identifier: "OPEN_SHOT",
            title: "Open in Finder",
            options: []
        )
        
        let copyShotAction = UNNotificationAction(
            identifier: "COPY_SHOT",
            title: "Copy Image",
            options: []
        )
        
        let screenshotCategory = UNNotificationCategory(
            identifier: "SCREENSHOT_NEW",
            actions: [openShotAction, copyShotAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([screenshotCategory])
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "OPEN_SHOT":
            if let path = userInfo["path"] as? String {
                let url = URL(fileURLWithPath: path)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            
        case "COPY_SHOT":
            if let path = userInfo["path"] as? String {
                let url = URL(fileURLWithPath: path)
                if let image = NSImage(contentsOf: url) {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([image])
                }
            }
            
        default:
            break
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .sound, .badge])
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
