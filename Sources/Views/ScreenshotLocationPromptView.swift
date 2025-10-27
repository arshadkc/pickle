import SwiftUI
import UserNotifications

/// A non-intrusive macOS-style banner prompting users to change their screenshot location
struct ScreenshotLocationPromptView: View {
    @Binding var isPresented: Bool
    @Binding var suppressLocationPromptPermanently: Bool
    let onLocationChanged: (() -> Void)?
    
    @State private var isProcessing = false
    @State private var showSuccessState = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @AppStorage("hasPromptedForLocationChange") private var hasPromptedForLocationChange = false
    
    private let locationManager = ScreenshotLocationManager.shared
    
    init(isPresented: Binding<Bool>, suppressLocationPromptPermanently: Binding<Bool>, onLocationChanged: (() -> Void)? = nil) {
        self._isPresented = isPresented
        self._suppressLocationPromptPermanently = suppressLocationPromptPermanently
        self.onLocationChanged = onLocationChanged
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isPresented {
                bannerContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.3), value: isPresented)
            }
        }
        .onChange(of: showSuccessState) { _, newValue in
            if newValue {
                // Auto-dismiss after showing success state for 1.5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                        showSuccessState = false
                    }
                }
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var bannerContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Desktop icon
                Image(systemName: "desktopcomputer")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keep your Desktop clean")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Pickle can save your screenshots in Pictures/Screenshots so they don't clutter your Desktop.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Folder icon
                Image(systemName: "folder")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            // Button area with different states
            HStack(spacing: 12) {
                Spacer()
                
                if showSuccessState {
                    // Success state
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        Text("Location updated!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .transition(.opacity)
                } else {
                    // Normal state with buttons
                           Button("Not Now") {
                               hasPromptedForLocationChange = true
                               suppressLocationPromptPermanently = true
                               withAnimation(.easeInOut(duration: 0.3)) {
                                   isPresented = false
                               }
                           }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(isProcessing)
                    
                    Button(action: handleUpdateLocationClick) {
                        HStack(spacing: 6) {
                                   if isProcessing {
                                       ProgressView()
                                           .scaleEffect(0.8)
                                       Text("Moving...")
                                   } else {
                                       Image(systemName: "folder.badge.plus")
                                       Text("Move to Pictures")
                                   }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(isProcessing)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    @MainActor
    private func handleUpdateLocationClick() {
        isProcessing = true
        
        Task {
            do {
                // Step 1: Ensure the Pictures/Screenshots folder exists
                try await ensureScreenshotsFolderExists()
                
                // Step 2: Update system screenshot location
                try await updateSystemScreenshotLocation()
                
                // Step 3: Show success state
                showSuccessState = true
                showSuccessNotification()
                
                // Step 4: Mark as prompted and prepare for auto-dismiss
                hasPromptedForLocationChange = true
                
                // Step 5: Notify parent to restart directory watcher
                onLocationChanged?()
                
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
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let success = self.locationManager.changeScreenshotLocation(to: folderURL)
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "ScreenshotLocationError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to update system preferences"]))
                }
            }
        }
    }
    
    private func showSuccessNotification() {
        // Use modern UserNotifications framework for macOS 14+
        let content = UNMutableNotificationContent()
        content.title = "Screenshot Location Updated"
        content.body = "New screenshots will be saved in \"Pictures/Screenshots\"."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "screenshot-location-updated",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show success notification: \(error)")
            }
        }
    }
}

#Preview {
    VStack {
        ScreenshotLocationPromptView(
            isPresented: .constant(true),
            suppressLocationPromptPermanently: .constant(false)
        )
        Spacer()
    }
    .frame(width: 500, height: 300)
}
