import Foundation

struct ScreenshotFolderResolver {
    static func getScreenshotFolderURL() -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", "com.apple.screencapture", "location"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    let expandedPath = NSString(string: path).expandingTildeInPath
                    return URL(fileURLWithPath: expandedPath)
                }
            }
        } catch {
            // Fall through to default
        }
        
        // Fallback to Desktop folder
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }
}
