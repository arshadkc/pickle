import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject private var locationManager = ScreenshotLocationManager.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoCleanDays") private var autoCleanDays = 0
    @AppStorage("pickle.groupingEnabled") private var groupingEnabled = true
    @State private var showLocationUpdateConfirmation = false
    @Binding var isPresented: Bool
    
    // Auto-clean options
    private let autoCleanOptions = [
        (0, "Off"),
        (7, "7 days"),
        (14, "14 days"),
        (30, "30 days"),
        (60, "60 days")
    ]
    
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
                            Toggle("", isOn: $launchAtLogin)
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
                        
                        Button("Move to Pictures/Screenshots") {
                            changeScreenshotLocation()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
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
                
                        // Auto-Clean Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Auto-Clean")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Auto-clean screenshots older than")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text("Automatically delete old screenshots to save space")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Picker("", selection: $autoCleanDays) {
                                        ForEach(autoCleanOptions, id: \.0) { option in
                                            Text(option.1).tag(option.0)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 120)
                                    .disabled(locationManager.isCurrentLocationDesktop())
                                }
                                .padding(.horizontal, 20)
                                
                                if locationManager.isCurrentLocationDesktop() {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(.orange)
                                            .font(.caption)
                                        Text("Auto-clean is disabled when screenshots are saved to Desktop. Move screenshots to Pictures/Screenshots to enable this feature.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            
                            Spacer()
                                .frame(height: 24)
                        }
                
            }
        }
        .frame(minWidth: 400, maxWidth: 600)
        .onKeyPress(.escape) {
            withAnimation(.easeInOut(duration: 0.25)) {
                isPresented = false
            }
            return .handled
        }
    }
    
    
    // MARK: - Actions
    
    private func changeScreenshotLocation() {
        let recommendedFolder = locationManager.recommendedScreenshotsFolder()
        
        if locationManager.changeScreenshotLocation(to: recommendedFolder) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showLocationUpdateConfirmation = true
            }
            
            // Hide confirmation after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showLocationUpdateConfirmation = false
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
