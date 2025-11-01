import Foundation
import TelemetryDeck
import SwiftUI

/// Centralized analytics service using TelemetryDeck
final class AnalyticsService {
    static let shared = AnalyticsService()
    
    @AppStorage("pickle.analyticsEnabled") private var analyticsEnabled = true
    
    private init() {}
    
    /// Initialize TelemetryDeck with your app ID
    /// Get your App ID from https://dashboard.telemetrydeck.com/
    func initialize() {
        let configuration = TelemetryDeck.Config(appID: "40F59CA1-3C0F-42C7-9416-DC8CDB6D589A")
        TelemetryDeck.initialize(config: configuration)
    }
    
    /// Check if analytics is enabled by the user
    var isEnabled: Bool {
        return analyticsEnabled
    }
    
    // MARK: - App Lifecycle Events
    
    func trackAppLaunch() {
        signal("app.launched")
    }
    
    func trackAppTerminated() {
        signal("app.terminated")
    }
    
    // MARK: - Screenshot Events
    
    func trackScreenshotDetected() {
        signal("screenshot.detected")
    }
    
    func trackScreenshotDeleted() {
        signal("screenshot.deleted")
    }
    
    func trackScreenshotShared(via method: String) {
        signal("screenshot.shared", parameters: ["method": method])
    }
    
    func trackScreenshotCopied() {
        signal("screenshot.copied")
    }
    
    func trackScreenshotOpened() {
        signal("screenshot.opened")
    }
    
    // MARK: - Redaction Events
    
    func trackRedactionPerformed(sensitiveItemsFound: Int) {
        signal("redaction.performed", parameters: [
            "sensitive_items_found": String(sensitiveItemsFound)
        ])
    }
    
    func trackRedactionEnabled() {
        signal("redaction.enabled")
    }
    
    func trackRedactionDisabled() {
        signal("redaction.disabled")
    }
    
    // MARK: - Settings Events
    
    func trackSettingsOpened() {
        signal("settings.opened")
    }
    
    func trackLaunchAtLoginChanged(enabled: Bool) {
        signal("settings.launch_at_login", parameters: ["enabled": String(enabled)])
    }
    
    func trackGroupingChanged(enabled: Bool) {
        signal("settings.grouping", parameters: ["enabled": String(enabled)])
    }
    
    func trackScreenshotLocationChanged(from: String, to: String) {
        signal("settings.location_changed", parameters: [
            "from_location": from,
            "to_location": to
        ])
    }
    
    // MARK: - Error Events
    
    func trackError(_ error: Error, context: String) {
        signal("error.occurred", parameters: [
            "error_description": error.localizedDescription,
            "context": context
        ])
    }
    
    func trackPermissionDenied(folder: String) {
        signal("permission.denied", parameters: ["folder": folder])
    }
    
    // MARK: - Helper Methods
    
    private func signal(_ eventName: String, parameters: [String: String] = [:]) {
        // Only send events if analytics is enabled
        guard analyticsEnabled else { return }
        TelemetryDeck.signal(eventName, parameters: parameters)
    }
}

