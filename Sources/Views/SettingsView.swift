import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject private var locationManager = ScreenshotLocationManager.shared
    @ObservedObject private var redactionSettings = RedactionSettings.shared
    @AppStorage("pickle.groupingEnabled") private var groupingEnabled = true
    @State private var launchAtLogin = false
    @State private var showLocationUpdateConfirmation = false
    @State private var isProcessing = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @AppStorage("pickle.analyticsEnabled") private var analyticsEnabled = true
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPresented = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Back to Screenshots")
                
                Spacer()
                
                Text("Settings")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
        // Quit button
        Button(action: {
            NSApp.terminate(nil)
        }) {
            Image(systemName: "power")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help("Quit Pickle")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                // General Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("General")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Launch at Login")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("Start Pickle automatically when you log in")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { launchAtLogin },
                                set: { newValue in
                                    launchAtLogin = newValue
                                    LaunchAtLoginService.shared.setEnabled(newValue)
                                    AnalyticsService.shared.trackLaunchAtLoginChanged(enabled: newValue)
                                }
                            ))
                            .toggleStyle(SwitchToggleStyle())
                        }
                        .padding(.horizontal, 20)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Group Screenshots by Date")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text("Organize screenshots into Today, Yesterday, etc.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $groupingEnabled)
                                .toggleStyle(SwitchToggleStyle())
                                .onChange(of: groupingEnabled) { _, newValue in
                                    AnalyticsService.shared.trackGroupingChanged(enabled: newValue)
                                }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 24)
                }
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Redaction Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Redaction")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    
                    VStack(spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Advanced Detection")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text("Uses built-in AI to detect and redact faces, profile pictures, passwords, credit cards, and QR codes. All processing happens on your device.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(2)
                            }
                            Spacer()
                            Toggle("", isOn: $redactionSettings.advancedDetectionEnabled)
                                .toggleStyle(SwitchToggleStyle())
                                .onChange(of: redactionSettings.advancedDetectionEnabled) { _, newValue in
                                    AnalyticsService.shared.trackAdvancedDetectionChanged(enabled: newValue)
                                }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 24)
                }
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Screenshot Location Section (only show if current location is Desktop)
                if locationManager.isCurrentLocationDesktop() {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Screenshot Location")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        Text("Your screenshots are currently saved to Desktop. Move them to Pictures/Screenshots to keep your desktop clean.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                        
                        HStack {
                            Spacer()
                            Button(action: handleMoveToPicturesClick) {
                                HStack(spacing: 6) {
                                    if isProcessing {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .frame(width: 14, height: 14)
                                        Text("Moving...")
                                    } else {
                                        Image(systemName: "folder.badge.plus")
                                            .frame(width: 14, height: 14)
                                        Text("Move to Pictures")
                                    }
                                }
                                .fixedSize()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(isProcessing)
                        }
                        .padding(.horizontal, 20)
                        
                        if showLocationUpdateConfirmation {
                            Text("Location updated")
                                .font(.caption)
                                .foregroundColor(.green)
                                .transition(.opacity)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 20)
                    
                    Divider()
                        .padding(.horizontal, 20)
                }
                
                // Privacy Section (always last)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    
                    VStack(spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Help Improve Pickle")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text("Allow Pickle to send anonymous usage data to help us make it better.\n\nWe never collect screenshots, personal data, or file names — only general app usage statistics.\n\nAll information is anonymized, encrypted, and handled securely.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(2)
                                
                                Text("Powered by TelemetryDeck (GDPR compliant).")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .padding(.top, 2)
                            }
                            Spacer()
                            Toggle("", isOn: $analyticsEnabled)
                                .toggleStyle(SwitchToggleStyle())
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 24)
                }
                
            }
        }
        .frame(minWidth: 400, maxWidth: 600)
        .onAppear {
            // Track settings opened
            AnalyticsService.shared.trackSettingsOpened()
            
            // Sync launch at login state when view appears
            launchAtLogin = LaunchAtLoginService.shared.isEnabled()
        }
        .onKeyPress(.escape) {
            withAnimation(.easeInOut(duration: 0.25)) {
                isPresented = false
            }
            return .handled
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    
    // MARK: - Actions
    
    @MainActor
    private func handleMoveToPicturesClick() {
        isProcessing = true
        
        Task {
            do {
                // Step 1: Ensure the Pictures/Screenshots folder exists
                try await ensureScreenshotsFolderExists()
                
                // Step 2: Update system screenshot location
                try await updateSystemScreenshotLocation()
                
                // Step 3: Restart directory watcher to watch the new location
                AppDelegate.shared.restartDirectoryWatcher()
                
                // Step 4: Show success confirmation
                withAnimation(.easeInOut(duration: 0.3)) {
                    showLocationUpdateConfirmation = true
                }
                
                // Step 5: Hide confirmation after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showLocationUpdateConfirmation = false
                    }
                }
                
            } catch {
                // Handle error gracefully
                errorMessage = "Could not update screenshot location. Please try again."
                showErrorAlert = true
            }
            
            isProcessing = false
        }
    }
    
    private func ensureScreenshotsFolderExists() async throws {
        let folderURL = locationManager.recommendedScreenshotsFolder()
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func updateSystemScreenshotLocation() async throws {
        let folderURL = locationManager.recommendedScreenshotsFolder()
        let currentLocation = locationManager.currentLocation()
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let success = self.locationManager.changeScreenshotLocation(to: folderURL)
                if success {
                    AnalyticsService.shared.trackScreenshotLocationChanged(
                        from: currentLocation.lastPathComponent,
                        to: folderURL.lastPathComponent
                    )
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "ScreenshotLocationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to update system preferences"]))
                }
            }
        }
    }
    
}



#if DEBUG && canImport(SwiftUI) && ENABLE_PREVIEWS
#Preview {
    SettingsView(isPresented: .constant(true))
}
#endif
