import Foundation

struct ScreenshotFolderResolver {
    /// Returns the current screenshot folder URL using the same logic as ScreenshotLocation.current()
    /// This ensures consistent detection that properly handles global vs ByHost preference domains
    static func getScreenshotFolderURL() -> URL {
        return ScreenshotLocation.current()
    }
}
