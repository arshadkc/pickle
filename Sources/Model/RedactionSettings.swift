import Foundation
import SwiftUI

/// Settings for controlling redaction behavior
class RedactionSettings: ObservableObject {
    /// Singleton instance
    static let shared = RedactionSettings()
    
    /// Enable advanced AI-powered detection (faces, names, passwords, credit cards, QR codes)
    @Published var advancedDetectionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(advancedDetectionEnabled, forKey: "advancedDetectionEnabled")
        }
    }
    
    private init() {
        self.advancedDetectionEnabled = UserDefaults.standard.bool(forKey: "advancedDetectionEnabled")
    }
}

