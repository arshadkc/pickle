import Foundation
import AppKit

enum ScreenshotLocation {
    /// Returns the current macOS screenshot folder, or ~/Desktop if unset/invalid.
    static func current() -> URL {
        let domain = "com.apple.screencapture" as CFString
        let key    = "location" as CFString
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        
        // Check global domain first (user's explicit preference)
        let globalValue: String? = {
            if let raw = CFPreferencesCopyValue(key, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) {
                if let path = raw as? String {
                    return (path as NSString).expandingTildeInPath
                }
            }
            return nil
        }()
        
        // Check ByHost domain (host-specific preference)
        let byHostValue: String? = {
            if let raw = CFPreferencesCopyValue(key, domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) {
                if let path = raw as? String {
                    return (path as NSString).expandingTildeInPath
                }
            }
            return nil
        }()
        
        // macOS behavior: Desktop is the default when NO preference exists
        // When user sets Desktop via Cmd+Shift+5, macOS doesn't write a preference
        // So if global domain is empty, Desktop is active (even if ByHost has stale data)
        if globalValue == nil {
            // No global preference means Desktop is the active location
            // Ignore ByHost if it exists (it might be stale)
            print("📍 No global preference, Desktop is active: \(desktopURL.path)")
            return desktopURL
        }
        
        // If global preference exists, use it
        if let globalPath = globalValue {
            let url = URL(fileURLWithPath: globalPath).standardizedFileURL
            if isExistingDirectory(url) {
                print("📍 Using global preference: \(url.path)")
                return url
            }
        }
        
        // Fallback to ByHost if global didn't work
        if let byHostPath = byHostValue {
            let url = URL(fileURLWithPath: byHostPath).standardizedFileURL
            if isExistingDirectory(url) {
                print("📍 Using ByHost preference: \(url.path)")
                return url
            }
        }
        
        // Final fallback: Desktop
        print("📍 No valid preference found, using Desktop: \(desktopURL.path)")
        return desktopURL
    }

    private static func isExistingDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}

/// Manages screenshot location detection and configuration
class ScreenshotLocationManager: ObservableObject {
    static let shared = ScreenshotLocationManager()
    
    @Published private(set) var currentScreenshotLocation: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    
    private var lastKnownLocation: URL?
    
    private init() {
        // Initialize with current location
        currentScreenshotLocation = currentLocation()
        lastKnownLocation = currentScreenshotLocation
    }
    
    /// Gets the current screenshot location from system defaults
    /// Returns ~/Desktop if not set or if the path doesn't exist
    func currentLocation() -> URL {
        return ScreenshotLocation.current()
    }
    
    /// Checks if the current screenshot location is the Desktop
    func isCurrentLocationDesktop() -> Bool {
        let currentPath = currentLocation().path
        let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
        return currentPath == desktopPath
    }
    
    /// Changes the system screenshot location to the specified folder.
    /// - Parameter folderURL: The new screenshot folder URL (can be non-existing; it will be created)
    /// - Returns: true if successful, false otherwise
    func changeScreenshotLocation(to folderURL: URL) -> Bool {
        print("🔄 DEBUG: Starting location change to: \(folderURL.path)")
        
        // 1) Normalize & ensure folder exists
        let target = folderURL.standardizedFileURL
        do {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true, attributes: nil)
            print("✅ DEBUG: Created folder: \(target.path)")
        } catch {
            print("❌ Failed to create screenshot folder: \(error)")
            return false
        }

        // 2) Delete existing preferences first (both ByHost and global)
        print("🧹 DEBUG: Cleaning existing preferences...")
        runDefaultsCommand(["delete", "com.apple.screencapture", "location"])
        runDefaultsCommand(["-currentHost", "delete", "com.apple.screencapture", "location"])
        
        // 3) Write to both ByHost and global preferences
        print("🔧 DEBUG: Writing to ByHost preference...")
        guard runDefaultsCommand(["-currentHost", "write", "com.apple.screencapture", "location", "-string", target.path]) else {
            print("❌ Failed to write ByHost preference")
            return false
        }
        
        print("🔧 DEBUG: Writing to global preference...")
        guard runDefaultsCommand(["write", "com.apple.screencapture", "location", "-string", target.path]) else {
            print("❌ Failed to write global preference")
            return false
        }
        
        print("✅ DEBUG: Both preferences written successfully")
        
        // Add a small delay to ensure the preferences are written
        Thread.sleep(forTimeInterval: 0.5)
        
        // 4) Verify the change worked by reading both back
        print("🔍 DEBUG: Verifying ByHost preference...")
        let byHostValue = runDefaultsCommand(["read", "com.apple.screencapture", "location"], captureOutput: true)
        print("🔍 DEBUG: ByHost value: '\(byHostValue.trimmingCharacters(in: .whitespacesAndNewlines))'")
        
        print("🔍 DEBUG: Verifying global preference...")
        let globalValue = runDefaultsCommand(["-currentHost", "read", "com.apple.screencapture", "location"], captureOutput: true)
        print("🔍 DEBUG: Global value: '\(globalValue.trimmingCharacters(in: .whitespacesAndNewlines))'")

        // 5) Restart SystemUIServer and screencaptureui to apply the change
        print("🔄 DEBUG: Restarting SystemUIServer...")
        runDefaultsCommand(["killall", "SystemUIServer"])
        
        print("🔄 DEBUG: Restarting screencaptureui...")
        runDefaultsCommand(["killall", "screencaptureui"])
        
        print("✅ DEBUG: Both processes restarted")

        // 4) Update internal state
        currentScreenshotLocation = target
        lastKnownLocation = target
        
        print("✅ DEBUG: Updated internal state to: \(target.path)")
        
        // 5) Post a custom notification for internal app use
        NotificationCenter.default.post(name: .screenshotLocationChanged, object: nil)

        return true
    }
    
    
    /// Gets the recommended Pictures/Screenshots folder URL
    func recommendedScreenshotsFolder() -> URL {
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures")
            .appendingPathComponent("Screenshots")
    }
    
    // MARK: - Observer Methods
    
    /// Manually check for location changes and update if needed
    func checkForLocationChange() {
        let newLocation = currentLocation()
        
        if newLocation != lastKnownLocation {
            print("🔄 Location changed from \(lastKnownLocation?.path ?? "nil") to \(newLocation.path)")
            
            currentScreenshotLocation = newLocation
            lastKnownLocation = newLocation
            
            // Notify that location changed
            NotificationCenter.default.post(
                name: .screenshotLocationChanged,
                object: nil,
                userInfo: ["newLocation": newLocation]
            )
        }
    }
    
    // MARK: - Helper Functions
    
    /// Runs a defaults command and returns success status
    private func runDefaultsCommand(_ arguments: [String]) -> Bool {
        let process = Process()
        process.launchPath = "/usr/bin/defaults"
        process.arguments = arguments
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("❌ Error running defaults command: \(error)")
            return false
        }
    }
    
    /// Runs a defaults command and returns the output
    private func runDefaultsCommand(_ arguments: [String], captureOutput: Bool) -> String {
        let process = Process()
        process.launchPath = "/usr/bin/defaults"
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("❌ Error running defaults command: \(error)")
            return ""
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let screenshotLocationChanged = Notification.Name("screenshotLocationChanged")
}
