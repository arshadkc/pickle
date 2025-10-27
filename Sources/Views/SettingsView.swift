import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject private var locationManager = ScreenshotLocationManager.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoCleanDays") private var autoCleanDays = 0
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
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Invisible spacer to center the title
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Back")
                        .font(.system(size: 14, weight: .medium))
                }
                .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                // General Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("General")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    HStack {
                        Text("Launch at Login")
                            .font(.body)
                        Spacer()
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(SwitchToggleStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
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
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Auto-Clean")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                            
                            HStack {
                                Text("Auto-clean screenshots older than")
                                    .font(.body)
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
                                Text("Auto-clean is disabled when screenshots are saved to Desktop. Move screenshots to Pictures/Screenshots to enable this feature.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 20)
                            }
                            
                            Spacer()
                                .frame(height: 20)
                        }
                
                Divider()
                    .padding(.horizontal, 20)
                
                // About Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    HStack {
                        Text("Version")
                            .font(.body)
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    
                    Button("Check for Updates…") {
                        checkForUpdates()
                    }
                    .buttonStyle(.link)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
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
    
    // MARK: - Computed Properties
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
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
    
    private func checkForUpdates() {
        print("Check for updates tapped")
        // TODO: Implement actual update checking logic
    }
}

#if DEBUG && canImport(SwiftUI) && ENABLE_PREVIEWS
#Preview {
    SettingsView(isPresented: .constant(true))
}
#endif
