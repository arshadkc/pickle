import SwiftUI
import AppKit
import QuickLookThumbnailing

struct ShotTile: View {
    let item: ScreenshotItem
    let isHighlighted: Bool
    @State private var image: NSImage?
    @State private var isHovered = false
    @State private var isDeleting = false
    @State private var isEditing = false
    @State private var editedName = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showCopyConfirmation = false
    @State private var isRedacting = false
    @State private var showRedactionGlow = false
    @State private var showProgressBar = false
    @State private var showSuccessBadge = false
    @State private var showFailureToast = false
    @State private var failureMessage = ""
    @State private var showCopyGlyph = false
    @State private var showRetryButton = false
    @State private var isSharing = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var uploadPhase: UploadPhase? = nil
    @State private var currentUploadTask: URLSessionUploadTask? = nil
    @FocusState private var isTextFieldFocused: Bool
    
    init(item: ScreenshotItem, isHighlighted: Bool = false) {
        self.item = item
        self.isHighlighted = isHighlighted
    }

    enum UploadPhase {
        case preparing
        case uploading
        case verifying
        case success
        case failed
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
        .overlay(alignment: .bottom) {
            UploadProgressBar(phase: uploadPhase, progress: uploadProgress)
        }
        .overlay(alignment: .topTrailing) {
            UploadStatusPill(phase: uploadPhase, progress: uploadProgress)
                .allowsHitTesting(false)
        }
        .overlay {
            // Dim overlay based on phase
            if let phase = uploadPhase {
                let opacity: Double = (phase == .verifying) ? 0.12 : ((phase == .uploading || phase == .preparing) ? 0.08 : 0)
                if opacity > 0 {
                    RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isDeleting)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .shadow(
            color: isHighlighted ? Color.accentColor.opacity(0.6) : (isHovered ? Color.black.opacity(0.25) : Color.black.opacity(0.1)),
            radius: isHighlighted ? 16 : (isHovered ? 12 : 4),
            x: 0,
            y: isHovered ? 6 : 2
        )
        .scaleEffect(isDeleting ? 0.85 : (isHighlighted ? 1.05 : (isHovered ? 1.02 : 1.0)))
        .brightness(isHovered ? 0.05 : 0)
        .overlay {
            // Highlight border when item is newly added
            if isHighlighted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.15))
                    )
                    .animation(.easeInOut(duration: 0.3), value: isHighlighted)
            }
        }
            .overlay {
                // Hover overlay with floating action bar
                if isHovered && !isDeleting {
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .scaleEffect(isHovered ? 1.02 : 1.0)
                    
                    VStack {
                        Spacer()
                        
                        HoverActionBar(
                            isHovered: isHovered,
                            isUploading: isUploading,
                            onDelete: deleteScreenshot,
                            onPreview: openQuickLook,
                            onCancel: {
                                currentUploadTask?.cancel()
                                isUploading = false
                                isSharing = false
                                uploadPhase = .failed
                                DispatchQueue.main.async {
                                    ToastCenter.shared.info("Upload cancelled", subtitle: nil, duration: 1.5)
                                }
                                // Clear failed state after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        self.uploadPhase = nil
                                    }
                                }
                            }
                        )
                    }
                    .frame(height: 90, alignment: .bottom)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .scaleEffect(isHovered ? 1.02 : 1.0)
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
                
                
                // Redaction visual feedback system
                if isRedacting {
                    VStack {
                        Spacer()
                        
                        // Spinner at center
                            ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        
                        Spacer()
                        
                        // Progress bar at bottom
                        if showProgressBar {
                            VStack(spacing: 0) {
                                Spacer()
                                
                                // Progress bar track
                                Rectangle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 3)
                                    .overlay(
                                        // Progress fill
                                        HStack {
                                            Rectangle()
                                                .fill(Color(red: 0.19, green: 0.82, blue: 0.35)) // #30D158
                                                .frame(width: 100) // Indeterminate width
                                                .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: showProgressBar)
                                            Spacer()
                                        }
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        .padding(.horizontal, 8)
                                    .padding(.bottom, 8)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(height: 90)
                }
                
                // Success badge
                if showSuccessBadge {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.19, green: 0.82, blue: 0.35)) // #30D158
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("Redacted")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.6))
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                        .transition(.scale.combined(with: .opacity))
                        
                        Spacer()
                    }
                    .frame(height: 90)
                }
                
                // Redaction success glow effect
                if showRedactionGlow {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.19, green: 0.82, blue: 0.35), lineWidth: 3) // #30D158
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.19, green: 0.82, blue: 0.35).opacity(0.1))
                        )
                        .frame(height: 90)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
                
                // Failure toast
                if showFailureToast {
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 14, weight: .medium))
                                
                                Text(failureMessage)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                            
                            if showRetryButton {
                                Button("Retry") {
                                    // Retry the redaction
                                    if failureMessage.contains("copy") {
                                        redactAndSave()
                                    } else {
                                        redactInPlace()
                                    }
                                    
                                    // Hide failure toast
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showFailureToast = false
                                        showRetryButton = false
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.2))
                                )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.8))
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                        Spacer()
                    }
                    .frame(height: 90)
                }
                
                
                // Copy glyph animation
                if showCopyGlyph {
                    VStack {
                        Spacer()
                        
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color(red: 0.19, green: 0.82, blue: 0.35).opacity(0.9))
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                            .offset(y: showCopyGlyph ? -8 : 0)
                            .opacity(showCopyGlyph ? 0 : 1)
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        
                        Spacer()
                    }
                    .frame(height: 90)
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
            // Change cursor based on hover state
            if hovering {
                NSCursor.openHand.push()
            } else {
                NSCursor.pop()
            }
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
            Button("Copy Image", action: copyImageToClipboard)
                .keyboardShortcut("c", modifiers: .command)
            
            Button("Copy Path", action: copyPathToClipboard)
                .keyboardShortcut("c", modifiers: [.command, .shift])
            
            Button("Reveal in Finder", action: showInFinder)
                .keyboardShortcut("r", modifiers: .command)
            
            Divider()
            
            Menu("Redact") {
                Button("Redact this image", action: redactInPlace)
                    .keyboardShortcut("r", modifiers: [.command, .option])
                    .disabled(isRedacting)
                
                Button("Redact a copy", action: redactAndSave)
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(isRedacting)
            }
            
            Divider()
            
            Button(action: shareLink) {
                Label("Share Link", systemImage: "link")
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(isSharing || isUploading)
            
            Button("Share...", action: shareImage)
                .keyboardShortcut("s", modifiers: .command)
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
            AnalyticsService.shared.trackScreenshotCopied()
            
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
        
        AnalyticsService.shared.trackScreenshotShared(via: "native_share")
        
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
    
    private func shareLink() {
        // Prevent concurrent share attempts
        guard !isSharing && !isUploading else {
            DispatchQueue.main.async {
                ToastCenter.shared.info("Share link already in progress", subtitle: nil, duration: 1.5)
            }
            return
        }
        
        // Check if ShareLinkManager is already uploading (another tile might be uploading)
        guard !ShareLinkManager.shared.isUploading else {
            DispatchQueue.main.async {
                ToastCenter.shared.info("Another share link is in progress", subtitle: "Please wait", duration: 1.5)
            }
            return
        }
        
        isSharing = true
        isUploading = true
        uploadProgress = 0.0
        uploadPhase = .preparing
        
        // Start upload in parallel and get immediate link copy
        ShareLinkManager.shared.createShareLinkWithProgress(for: item.url, onTask: { task in
            DispatchQueue.main.async {
                self.currentUploadTask = task
                self.uploadPhase = .uploading
            }
        }, progressCallback: { progress in
            DispatchQueue.main.async {
                self.uploadProgress = progress
                if progress >= 1.0 {
                    self.uploadPhase = .verifying
                }
            }
        }, completion: { success in
            DispatchQueue.main.async {
                if success {
                    AnalyticsService.shared.trackScreenshotShared(via: "share_link")
                }
                
                // Always reset state flags, regardless of success/failure
                self.isUploading = false
                self.isSharing = false
                self.uploadPhase = success ? .success : .failed
                
                // Auto-clear state after delay (both success and failure)
                let delay = success ? 0.6 : 3.0 // Show failure longer so user can see it
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.uploadPhase = nil
                    }
                }
            }
        })
    }
    
    private func redactAndSave() {
        // Prevent concurrent redaction attempts
        guard !isRedacting else {
            DispatchQueue.main.async {
                ToastCenter.shared.info("Redaction already in progress", subtitle: nil, duration: 1.5)
            }
            return
        }
        
        // Start source tile pulse and copy glyph animation
        startRedactionCopyVisualFeedback()
        
        RedactionService.shared.redactAndSave(imageURL: item.url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let outputURL):
                    // Clear redaction state
                    isRedacting = false
                    
                    // Clear the glow effect
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showRedactionGlow = false
                    }
                    
                    // Add the new file to the store immediately for instant UI update
                    ScreenshotStore.shared.insertImmediately(outputURL)
                    
                    // Show ToastCenter toast
                    ToastCenter.shared.success("Redacted copy added", subtitle: nil)
                    
                    // Highlight the new item and scroll to top
                    // Use a small delay to ensure the item is in the store
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Find the item in MenuBarView and trigger highlight
                        NotificationCenter.default.post(
                            name: NSNotification.Name("HighlightNewRedactedCopy"),
                            object: nil,
                            userInfo: ["url": outputURL]
                        )
                    }
                    
                case .failure(let error):
                    // Clear redaction state
                    isRedacting = false
                    
                    // Clear the glow effect on failure
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showRedactionGlow = false
                    }
                    
                    // Show failure toast
                    DispatchQueue.main.async {
                        ToastCenter.shared.error("Failed to create redacted copy", subtitle: "Please try again")
                    }
                    // Show failure sequence on tile
                    showRedactionFailure(message: "Failed to create redacted copy")
                    print("Redaction failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func redactInPlace() {
        // Prevent concurrent redaction attempts
        guard !isRedacting else {
            DispatchQueue.main.async {
                ToastCenter.shared.info("Redaction already in progress", subtitle: nil, duration: 1.5)
            }
            return
        }
        
        // Start visual feedback sequence
        startRedactionVisualFeedback()
        
        RedactionService.shared.redactInPlace(imageURL: item.url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Refresh the image to show the redacted version
                    loadImage()
                    
                    // Show success sequence
                    showRedactionInPlaceSuccess()
                    
                case .failure(let error):
                    // Show failure sequence
                    showRedactionFailure(message: "Redaction failed")
                    print("In-place redaction failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - New Visual Feedback System
    
    private func startRedactionVisualFeedback() {
        // Initial trigger: glow pulse and dim
        withAnimation(.easeOut(duration: 0.25)) {
            showRedactionGlow = true
        }
        
        // Start spinner
        withAnimation(.easeIn(duration: 0.12)) {
            isRedacting = true
        }
        
        // Show progress bar after 0.6s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showProgressBar = true
            }
        }
    }
    
    private func startRedactionCopyVisualFeedback() {
        // Mark redaction as in progress
        isRedacting = true
        
        // Start glow effect
        withAnimation(.easeOut(duration: 0.25)) {
            showRedactionGlow = true
        }
        
        // Dim the image
        withAnimation(.easeInOut(duration: 0.15)) {
            // This will be handled by the opacity modifier in the view
        }
        
        // Show copy glyph animation
        withAnimation(.easeIn(duration: 0.12)) {
            showCopyGlyph = true
        }
        
        // Hide copy glyph after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopyGlyph = false
            }
        }
    }
    
    private func showRedactionInPlaceSuccess() {
        // Hide spinner and progress bar
        withAnimation(.easeIn(duration: 0.12)) {
            isRedacting = false
            showProgressBar = false
        }
        
        // Show success glow effect
        withAnimation(.easeInOut(duration: 0.15)) {
            showRedactionGlow = true
        }
        
        // Show success badge
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            showSuccessBadge = true
        }
        
        // Hide success badge after 1.2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSuccessBadge = false
            }
        }
        
        
        // Hide glow after success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showRedactionGlow = false
            }
        }
    }
    
    private func showRedactionFailure(message: String) {
        // Hide spinner and progress bar
        withAnimation(.easeIn(duration: 0.12)) {
            isRedacting = false
            showProgressBar = false
        }
        
        // Set failure message and show failure toast
        failureMessage = message
        withAnimation(.easeInOut(duration: 0.25)) {
            showFailureToast = true
        }
        
        // Show retry button after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showRetryButton = true
            }
        }
        
        // Auto-dismiss failure toast after 6s (longer to allow retry)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showFailureToast = false
                showRetryButton = false
            }
        }
        
        // Hide glow
        withAnimation(.easeInOut(duration: 0.3)) {
            showRedactionGlow = false
        }
    }
    
        private func deleteScreenshot() {
            // Start deletion animation with more dramatic effect
            withAnimation(.easeInOut(duration: 0.25)) {
                isDeleting = true
            }
            
            // Wait for animation to complete, then delete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                do {
                    try FileManager.default.removeItem(at: item.url)
                    // Use withAnimation for smooth grid re-layout
                    withAnimation(.easeInOut(duration: 0.4)) {
                        ScreenshotStore.shared.items.removeAll { $0.url == item.url }
                    }
                } catch {
                    print("Failed to delete screenshot: \(error)")
                    // Reset animation state if deletion failed
                    withAnimation(.easeInOut(duration: 0.25)) {
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
            AnalyticsService.shared.trackScreenshotOpened()
            
            let urls = ScreenshotStore.shared.items.map { $0.url }
            if let index = ScreenshotStore.shared.items.firstIndex(where: { $0.id == item.id }) {
                QuickLookPreviewController.shared.show(urls: urls, startAt: index)
            } else {
                QuickLookPreviewController.shared.showSingle(url: item.url)
            }
        }
        
}

// MARK: - Extracted Subviews

struct UploadProgressBar: View {
    let phase: ShotTile.UploadPhase?
    let progress: Double
    
    var body: some View {
        Group {
            if phase == .uploading || phase == .verifying || phase == .failed || phase == .success {
                GeometryReader { geo in
                    let inset: CGFloat = 8
                    let width = max(0, (geo.size.width - inset * 2) * barProgress)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 2)
                            .padding(.horizontal, inset)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(isFailed ? Color.red : Color.accentColor)
                            .frame(width: width, height: 2)
                            .padding(.horizontal, inset)
                            .animation(.easeInOut(duration: 0.15), value: progress)
                    }
                }
                .frame(height: 6)
            }
        }
    }
    
    private var isFailed: Bool { phase == .failed }
    private var isSuccess: Bool { phase == .success }
    private var barProgress: CGFloat {
        if isFailed { return progress }
        if isSuccess { return 1.0 }
        return progress
    }
}

struct UploadStatusPill: View {
    let phase: ShotTile.UploadPhase?
    let progress: Double
    
    var body: some View {
        Group {
            if let phase = phase {
                HStack(spacing: 6) {
                    switch phase {
                    case .preparing:
                        ProgressView()
                            .scaleEffect(0.4)
                    case .uploading:
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 11, weight: .semibold))
                    case .verifying:
                        ProgressView()
                            .scaleEffect(0.4)
                    case .success:
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                    case .failed:
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 18, alignment: .center)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(6)
                .transition(.opacity)
            }
        }
    }
}

struct HoverActionBar: View {
    let isHovered: Bool
    let isUploading: Bool
    let onDelete: () -> Void
    let onPreview: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Left side: Cancel (when uploading) or Delete (when not uploading)
            if isUploading {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
            } else {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.85))
                                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
            }
            
            Spacer()
            
            // Right side: Always show Preview
            Button(action: onPreview) {
                Image(systemName: "eye")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.85))
                            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

struct MenuBarView: View {
    @ObservedObject private var store = ScreenshotStore.shared
    @ObservedObject private var locationManager = ScreenshotLocationManager.shared
    @ObservedObject private var shareLinkManager = ShareLinkManager.shared
    @State private var screenshotFolderURL: URL?
    @State private var showLocationPrompt = false
    @State private var showSettings = false
    @AppStorage("hasPromptedForLocationChange") private var hasPromptedForLocationChange = false
    @AppStorage("lastKnownScreenshotLocation") private var lastKnownScreenshotLocation = ""
    @AppStorage("suppressLocationPromptPermanently") private var suppressLocationPromptPermanently = false
    @AppStorage("pickle.groupingEnabled") private var groupingEnabled = true
    @State private var highlightedItemURL: URL? = nil
    
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
                          
                      }
                      .padding(.horizontal)
                      .padding(.vertical, 8)
                      
                
                // Line separator
                Divider()
                    .padding(.horizontal, 16) // macOS style - doesn't touch edges
                    .padding(.bottom, 8)
                
                // Screenshot Grid
                if store.items.isEmpty {
                    if store.permissionDenied {
                        // Permission denied error state
                        VStack(spacing: 16) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            
                            VStack(spacing: 8) {
                                Text("Permission Required")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Pickle needs permission to access your \(store.permissionDeniedFolder ?? "screenshot") folder to display screenshots.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("Go to System Settings → Privacy & Security → Files and Folders → Enable access for PickleApp")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 4)
                            }
                            
                            HStack(spacing: 12) {
                                Button("Open System Settings") {
                                    // Open System Settings to Privacy & Security > Files and Folders
                                    if #available(macOS 13.0, *) {
                                        // Use the Files and Folders specific URL (not Full Disk Access)
                                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") {
                                            NSWorkspace.shared.open(url)
                                        } else {
                                            // Fallback to Privacy & Security
                                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)
                                        }
                                    } else {
                                        // Fallback for older macOS versions
                                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                                
                                Button("Retry") {
                                    // Retry by reloading the screenshot folder
                                    let screenshotFolderURL = ScreenshotFolderResolver.getScreenshotFolderURL()
                                    store.reload(from: screenshotFolderURL)
                                    AppDelegate.shared.restartDirectoryWatcher()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 32)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                    } else {
                        // Normal empty state
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
                    }
                } else {
                    ScrollViewReader { proxy in
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
                                                    ForEach(Array(group.1.enumerated()), id: \.element.id) { index, item in
                                                        ShotTile(item: item, isHighlighted: highlightedItemURL == item.url)
                                                            .id(item.id)
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
                                        ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                                            ShotTile(item: item, isHighlighted: highlightedItemURL == item.url)
                                                .id(item.id)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .animation(.easeInOut(duration: 0.25), value: groupingEnabled)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.items.count)
                        }
                        .frame(maxHeight: 300)
                        .onChange(of: highlightedItemURL) { oldValue, newValue in
                            if let newURL = newValue {
                                // Small delay to ensure the item is rendered
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    if let highlightedItem = store.items.first(where: { $0.url == newURL }) {
                                        // Scroll to the highlighted item (which should be at top)
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            proxy.scrollTo(highlightedItem.id, anchor: .top)
                                        }
                                    } else {
                                        // If item not found yet, scroll to top as fallback
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            proxy.scrollTo(store.items.first?.id ?? UUID(), anchor: .top)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
            }
            .frame(width: 400)
            .padding(.bottom, 12)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HighlightNewRedactedCopy"))) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                // Set highlighted item
                withAnimation(.easeInOut(duration: 0.3)) {
                    highlightedItemURL = url
                }
                
                // Auto-clear highlight after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        highlightedItemURL = nil
                    }
                }
            }
        }
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
               
               // Debug logging
               print("🔍 Location Check:")
               print("   Current system location: \(currentSystemLocation.path)")
               print("   Desktop URL: \(desktopURL.path)")
               print("   Is Desktop: \(isDesktop)")
               print("   Suppress flag: \(suppressLocationPromptPermanently)")
               
               // Update location manager
               locationManager.checkForLocationChange()
               
               // Only restart watcher if the path actually changed
               if screenshotFolderURL?.standardizedFileURL != currentSystemLocation.standardizedFileURL {
                   screenshotFolderURL = currentSystemLocation
                   store.reload(from: currentSystemLocation)
                   AppDelegate.shared.restartDirectoryWatcher()
               }
               
               // Update banner visibility
               if isDesktop && !suppressLocationPromptPermanently {
                   // Show prompt if location is Desktop and user hasn't permanently suppressed it
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
