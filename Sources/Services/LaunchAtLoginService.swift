import Foundation
import ServiceManagement
import AppKit

/// Service to manage Launch at Login functionality using modern SMAppService API
final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()
    
    private let loginService = SMAppService.mainApp
    
    private init() {}
    
    /// Checks if the app is set to launch at login
    /// - Returns: true if launch at login is enabled, false otherwise
    func isEnabled() -> Bool {
        let status = loginService.status
        return status == .enabled
    }
    
    /// Enables or disables launch at login
    /// - Parameter enabled: true to enable launch at login, false to disable
    /// - Returns: true if the operation was successful, false otherwise
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try loginService.register()
            } else {
                try loginService.unregister()
            }
            return true
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            return false
        }
    }
}
