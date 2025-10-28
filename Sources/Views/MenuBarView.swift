import SwiftUI
import AppKit
import QuickLookThumbnailing
import UserNotifications

struct ShotTile: View {
    let item: ScreenshotItem
    @State private var image: NSImage?
    @State private var isHovered = false
    @State private var isDeleting = false
    @State private var isEditing = false
    @State private var editedName = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showCopyConfirmation = false
    @State private var showRedactionToast = false
    @State private var redactionToastMessage = ""
    @State private var isRedacting = false
    @FocusState private var isTextFieldFocused: Bool
    
    init(item: ScreenshotItem) {
        self.item = item
    }
    
    var body: some View {
        VStack(spacing: 0) {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 90)
            
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 90)
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(isDeleting ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: isDeleting)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .shadow(
            color: isHovered ? Color.black.opacity(0.2) : Color.black.opacity(0.1),
            radius: isHovered ? 8 : 4,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .scaleEffect(isDeleting ? 0.8 : (isHovered ? 1.05 : 1.0))
            .overlay {
                // Hover overlay
                if isHovered && !isDeleting {
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .frame(height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .scaleEffect(isHovered ? 1.05 : 1.0)
                    
                    VStack {
                        Spacer()
                        
                        // Bottom row with delete and preview buttons
                        HStack {
                            // Delete button - left bottom
                            Button(action: deleteScreenshot) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            // Preview button - right bottom
                            Button(action: openQuickLook) {
                                Image(systemName: "eye")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                    .frame(height: 90, alignment: .bottom)
                    .transition(.opacity)
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                }
            }
            .overlay {
                // Copy confirmation message (on top of hover overlay)
                if showCopyConfirmation {
                    VStack {
                        Spacer()
                        Text("Image copied")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Spacer()
                        Spacer()
                    }
                    .frame(height: 90)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
                
                // Redaction toast message
                if showRedactionToast {
                    VStack {
                        Spacer()
                        Text(redactionToastMessage)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Spacer()
                        Spacer()
                    }
                    .frame(height: 90)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
                
                // Redaction loading indicator
                if isRedacting {
                    VStack {
                        Spacer()
                        HStack {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Redacting...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        Spacer()
                        Spacer()
                    }
                    .frame(height: 90)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            
                VStack(spacing: 2) {
                    if isEditing {
                        VStack(spacing: 1) {
                            TextField("", text: $editedName)
                                .font(.caption2)
                                .textFieldStyle(.plain)
                                .focused($isTextFieldFocused)
                                .multilineTextAlignment(.center)
                                .onSubmit {
                                    saveName()
                                }
                                .onExitCommand {
                                    cancelEditing()
                                }
                                .onAppear {
                                    let baseName = item.url.deletingPathExtension().lastPathComponent
                                    editedName = baseName
                                    isTextFieldFocused = true
                                }
                                .onChange(of: editedName) { _, newValue in
                                    // Clear error when user starts typing
                                    if showError {
                                        showError = false
                                        errorMessage = ""
                                    }
                                }
                            
                            if showError {
                                Text(errorMessage)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    } else {
                        Text(item.url.lastPathComponent)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .onTapGesture {
                                startEditing()
                            }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
        }
        .frame(width: 120)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            loadImage()
        }
        .background(
            // Invisible background to catch clicks outside the text field
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if isEditing {
                        saveName()
                    }
                }
        )
        .onDrag {
            // Create a simple NSItemProvider with the file URL
            let itemProvider = NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
            
            // Register additional type identifiers for better compatibility
            itemProvider.registerFileRepresentation(
                forTypeIdentifier: "public.image",
                fileOptions: [],
                visibility: .all
            ) { completion in
                completion(item.url, true, nil)
                return nil
            }
            
            return itemProvider
        }
        .contextMenu {
            Button("Copy Image") {
                print("📋 COPY IMAGE BUTTON CLICKED!")
                copyImageToClipboard()
            }
            
            Button("Copy Path") {
                copyPathToClipboard()
            }
            
            Button("Reveal in Finder") {
                showInFinder()
            }
            
            Divider()
            
            Menu("Redact") {
                Button("Redact this image") {
                    redactInPlace()
                }
                
                Button("Redact a copy") {
                    redactAndSave()
                }
            }
            
            Button("Share...") {
                shareImage()
            }
        }
    }
    
    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let scale = NSScreen.main?.backingScaleFactor ?? 2
            let size = CGSize(width: 240, height: 240)
            
            let request = QLThumbnailGenerator.Request(
                fileAt: item.url,
                size: size,
                scale: scale,
                representationTypes: .thumbnail
            )
            
            QLThumbnailGenerator.shared.generateRepresentations(for: request) { thumbnail, type, error in
                DispatchQueue.main.async {
                    if let thumbnail = thumbnail {
                        self.image = thumbnail.nsImage
                    } else {
                        // Fallback to direct image loading
                        self.image = NSImage(contentsOf: item.url)
                    }
                }
            }
        }
    }
    
    private func copyImageToClipboard() {
        guard let image = image else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.writeObjects([image])
        
        if success {
            // Show confirmation message
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopyConfirmation = true
            }
            
            // Hide confirmation message after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopyConfirmation = false
                }
            }
        }
    }
    
    private func copyPathToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.url.path, forType: .string)
    }
    
    private func shareImage() {
        guard let image = image else { return }
        
        // Create a sharing service picker
        let sharingService = NSSharingServicePicker(items: [image, item.url])
        
        // Get the current window and create a proper anchor point
        if let window = NSApplication.shared.keyWindow,
           let contentView = window.contentView {
            
            // Create a temporary view at the center of the window
            let tempView = NSView(frame: CGRect(x: contentView.bounds.midX - 50, y: contentView.bounds.midY - 50, width: 100, height: 100))
            tempView.wantsLayer = true
            contentView.addSubview(tempView)
            
            // Show the sharing picker
            sharingService.show(relativeTo: tempView.bounds, of: tempView, preferredEdge: .minY)
            
            // Keep the anchor view alive longer to prevent the share sheet from disappearing
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                tempView.removeFromSuperview()
            }
        }
    }
    
    private func redactAndSave() {
        NSLog("🎯 REDACT BUTTON CLICKED!")
        print("🎯 REDACT BUTTON CLICKED!")
        isRedacting = true
        
        RedactionService.shared.redactAndSave(imageURL: item.url) { result in
            DispatchQueue.main.async {
                isRedacting = false
                
                switch result {
                case .success(let outputURL):
                    // Add the new file to the store immediately for instant UI update
                    ScreenshotStore.shared.insertImmediately(outputURL)
                    
                    // Determine appropriate toast message based on the outcome
                    let message = determineToastMessage(for: outputURL)
                    showRedactionToast(message: message)
                    
                case .failure(let error):
                    // Show error toast
                    showRedactionToast(message: "Couldn't save redacted copy")
                    print("Redaction failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func redactInPlace() {
        NSLog("🎯 REDACT IN-PLACE BUTTON CLICKED!")
        print("🎯 REDACT IN-PLACE BUTTON CLICKED!")
        isRedacting = true
        
        RedactionService.shared.redactInPlace(imageURL: item.url) { result in
            DispatchQueue.main.async {
                isRedacting = false
                
                switch result {
                case .success:
                    // Refresh the image to show the redacted version
                    loadImage()
                    showRedactionToast(message: "🔒 Image redacted")
                    
                case .failure(let error):
                    // Show error toast
                    showRedactionToast(message: "Couldn't redact image")
                    print("In-place redaction failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func determineToastMessage(for outputURL: URL) -> String {
        let filename = outputURL.lastPathComponent
        
        // Check if it's a timeout fallback (unredacted copy)
        if filename.contains("redact-") && !filename.contains("redact-redact-") {
            // This is a normal redacted copy
            return "🔒 Redacted copy saved"
        } else {
            // This might be a timeout fallback or no-hit case
            // For now, we'll use a generic message since we can't easily determine
            // the specific case from just the URL. In a real implementation,
            // we might pass additional context from the service.
            return "🔒 Copy saved"
        }
    }
    
    private func showRedactionToast(message: String) {
        redactionToastMessage = message
        showRedactionToast = true
        
        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showRedactionToast = false
            }
        }
    }
    
        private func deleteScreenshot() {
            // Start deletion animation
            withAnimation(.easeInOut(duration: 0.2)) {
                isDeleting = true
            }
            
            // Wait for animation to complete, then delete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                do {
                    try FileManager.default.removeItem(at: item.url)
                    // Use withAnimation for smooth grid re-layout
                    withAnimation(.easeInOut(duration: 0.3)) {
                        ScreenshotStore.shared.items.removeAll { $0.url == item.url }
                    }
                } catch {
                    print("Failed to delete screenshot: \(error)")
                    // Reset animation state if deletion failed
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDeleting = false
                    }
                }
            }
        }
        
        private func startEditing() {
            isEditing = true
            showError = false
            errorMessage = ""
        }
        
        private func saveName() {
            // Validate the name
            let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check for empty names
            if trimmedName.isEmpty {
                showError = true
                errorMessage = "Name cannot be empty"
                return
            }
            
            // Check for invalid characters (leading dots, slashes)
            if trimmedName.hasPrefix(".") || trimmedName.contains("/") {
                showError = true
                errorMessage = "Invalid characters"
                return
            }
            
            // Get the original extension
            let originalExtension = item.url.pathExtension
            let newFileName = originalExtension.isEmpty ? trimmedName : "\(trimmedName).\(originalExtension)"
            let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newFileName)
            
            // Check if file already exists
            if FileManager.default.fileExists(atPath: newURL.path) {
                showError = true
                errorMessage = "File already exists"
                return
            }
            
            // Mark the new file as renamed to prevent notifications
            ScreenshotStore.shared.markAsRenamed(newURL)
            
            // Optimistic update: update the model immediately
            ScreenshotStore.shared.updateItem(oldURL: item.url, newURL: newURL)
            isEditing = false
            showError = false
            errorMessage = ""
            
            // Then commit the rename on disk
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.moveItem(at: item.url, to: newURL)
                } catch {
                    print("Failed to rename file: \(error)")
                    // Revert the optimistic update on failure
                    DispatchQueue.main.async {
                        ScreenshotStore.shared.updateItem(oldURL: newURL, newURL: item.url)
                        self.isEditing = true
                        self.showError = true
                        self.errorMessage = "Rename failed"
                    }
                }
            }
        }
        
        private func cancelEditing() {
            isEditing = false
            editedName = ""
            showError = false
            errorMessage = ""
            isTextFieldFocused = false
        }
        
        private func showInFinder() {
            print("Attempting to reveal file in Finder: \(item.url.path)")
            
            // Check if file exists
            guard FileManager.default.fileExists(atPath: item.url.path) else {
                print("File does not exist: \(item.url.path)")
                return
            }
            
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }
        
        private func openQuickLook() {
            let urls = ScreenshotStore.shared.items.map { $0.url }
            if let index = ScreenshotStore.shared.items.firstIndex(where: { $0.id == item.id }) {
                QuickLookPreviewController.shared.show(urls: urls, startAt: index)
            } else {
                QuickLookPreviewController.shared.showSingle(url: item.url)
            }
        }
        
}

struct MenuBarView: View {
    @ObservedObject private var store = ScreenshotStore.shared
    @ObservedObject private var locationManager = ScreenshotLocationManager.shared
    @State private var screenshotFolderURL: URL?
    @State private var showLocationPrompt = false
    @State private var showSettings = false
    @AppStorage("hasPromptedForLocationChange") private var hasPromptedForLocationChange = false
    @AppStorage("lastKnownScreenshotLocation") private var lastKnownScreenshotLocation = ""
    @AppStorage("suppressLocationPromptPermanently") private var suppressLocationPromptPermanently = false
    @AppStorage("pickle.groupingEnabled") private var groupingEnabled = true
    
    // MARK: - Grouping Logic
    
    private func groupScreenshots(_ items: [ScreenshotItem]) -> [(String, [ScreenshotItem])] {
        // Limit to first 100 items for performance
        let limitedItems = Array(items.prefix(100))
        
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [(String, [ScreenshotItem])] = []
        
        // Group by date
        let groupedByDate = Dictionary(grouping: limitedItems) { item in
            calendar.startOfDay(for: item.date)
        }
        
        // Sort dates in descending order (most recent first)
        let sortedDates = groupedByDate.keys.sorted(by: >)
        
        for date in sortedDates {
            guard let items = groupedByDate[date] else { continue }
            let sortedItems = items.sorted { $0.date > $1.date }
            
            let groupTitle: String
            if calendar.isDateInToday(date) {
                groupTitle = "Today"
            } else if calendar.isDateInYesterday(date) {
                groupTitle = "Yesterday"
            } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
                // Within the current week
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE" // Full weekday name
                groupTitle = formatter.string(from: date)
            } else {
                groupTitle = "Earlier"
            }
            
            groups.append((groupTitle, sortedItems))
        }
        
        return groups
    }
    
    var body: some View {
        if showSettings {
            // Settings content - this will automatically resize the window
            SettingsView(isPresented: $showSettings)
        } else {
            // Main app content
            VStack(spacing: 0) {
                // Screenshot location prompt
                ScreenshotLocationPromptView(
                    isPresented: $showLocationPrompt,
                    suppressLocationPromptPermanently: $suppressLocationPromptPermanently
                ) {
                    // Restart directory watcher when location changes
                    AppDelegate.shared.restartDirectoryWatcher()
                }
                .onAppear {
                    // Initialize screenshotFolderURL on first load
                    if screenshotFolderURL == nil {
                        screenshotFolderURL = ScreenshotLocationManager.shared.currentLocation()
                        store.reload(from: screenshotFolderURL!)
                        AppDelegate.shared.restartDirectoryWatcher()
                    }
                    
                    // Check for location changes and show banner if needed
                    checkForLocationChanges()
                }
                
                      // Header
                      HStack {
                          Text("Recent Screenshots")
                              .font(.headline)
                          Spacer()
                          
                          // Settings button
                          Button(action: {
                              withAnimation(.easeInOut(duration: 0.25)) {
                                  showSettings.toggle()
                              }
                          }) {
                              Image(systemName: "gearshape")
                                  .font(.system(size: 14, weight: .medium))
                                  .foregroundColor(.primary)
                          }
                          .buttonStyle(.plain)
                          .help("Settings")
                          
                          // Refresh button
                          Button(action: {
                              // Manual refresh - reload from current location
                              checkForLocationChanges()
                          
                           // Reload from current location
                           if let currentLocation = screenshotFolderURL {
                               print("🔄 DEBUG: Reloading from: \(currentLocation.path)")
                               store.reload(from: currentLocation)
                               AppDelegate.shared.restartDirectoryWatcher()
                           } else {
                               print("🔄 DEBUG: No current location set")
                           }
                       }) {
                           Image(systemName: "arrow.clockwise")
                               .font(.system(size: 14, weight: .medium))
                       }
                       .buttonStyle(.plain)
                       .help("Refresh screenshots")
                      }
                      .padding(.horizontal)
                      .padding(.vertical, 8)
                
                // Line separator
                Divider()
                    .padding(.horizontal, 16) // macOS style - doesn't touch edges
                    .padding(.bottom, 8)
                
                // Screenshot Grid
                if store.items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No screenshots found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        Group {
                            if groupingEnabled {
                                // Grouped layout with section headers
                                LazyVStack(spacing: 16) {
                                    ForEach(Array(groupScreenshots(store.items).enumerated()), id: \.offset) { index, group in
                                        VStack(alignment: .leading, spacing: 8) {
                                        // Section header
                                        HStack {
                                            Text(group.0)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 4)
                                            
                                            // Grid for this group
                                            LazyVGrid(columns: [
                                                GridItem(.flexible(), spacing: 8),
                                                GridItem(.flexible(), spacing: 8),
                                                GridItem(.flexible(), spacing: 8)
                                            ], spacing: 8) {
                                                ForEach(group.1) { item in
                                                    ShotTile(item: item)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            } else {
                                // Flat layout (original)
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)
                                ], spacing: 8) {
                                    ForEach(store.items) { item in
                                        ShotTile(item: item)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .animation(.easeInOut(duration: 0.25), value: groupingEnabled)
                    }
                    .frame(maxHeight: 300)
                }
                
            }
            .frame(width: 400)
            .padding(.bottom, 12)
            .contextMenu {
                Button("Settings...") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSettings.toggle()
                    }
                }
                
                Divider()
                
                Button("Quit Pickle") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
    
           /// Checks for location changes when menu opens
           private func checkForLocationChanges() {
               // Use the ScreenshotLocationManager which properly handles ByHost/global precedence
               let currentSystemLocation = ScreenshotLocationManager.shared.currentLocation()
               
               let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
               let isDesktop = currentSystemLocation.standardizedFileURL == desktopURL.standardizedFileURL
               
               // Update location manager
               locationManager.checkForLocationChange()
               
               // Only restart watcher if the path actually changed
               if screenshotFolderURL?.standardizedFileURL != currentSystemLocation.standardizedFileURL {
                   screenshotFolderURL = currentSystemLocation
                   store.reload(from: currentSystemLocation)
                   AppDelegate.shared.restartDirectoryWatcher()
               }
               
               // Update banner visibility
               if isDesktop {
                   // If location is Desktop, reset the suppression flag so we can show the banner again
                   if suppressLocationPromptPermanently {
                       suppressLocationPromptPermanently = false
                   }
                   showLocationPrompt = true
               } else {
                   showLocationPrompt = false
               }
    }
    
    /// Helper function to run shell commands
    private func shell(_ command: String) -> String {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "error"
        } catch {
            return "error: \(error)"
        }
    }
}
