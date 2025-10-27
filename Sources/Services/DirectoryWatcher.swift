import Foundation

extension URL {
    var creationDate: Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            return attributes[.creationDate] as? Date
        } catch {
            return nil
        }
    }
}

class DirectoryWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var watchedURL: URL?
    private var seenFiles: Set<String> = []
    private var pollingTimer: Timer?
    
    func startWatching(url: URL, onNewFile: @escaping (URL) -> Void, onFileDeleted: @escaping (URL) -> Void) {
        stopWatching()
        
        watchedURL = url
        
        // Initialize seen files with current directory contents
        initializeSeenFiles()
        
        // Set up file system watcher
        let fileDescriptor = open(url.path, O_EVTONLY)
        
        guard fileDescriptor != -1 else {
            print("Failed to open directory for watching: \(url.path)")
            return
        }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .attrib, .delete],
            queue: DispatchQueue.global(qos: .background)
        )
        
        source?.setEventHandler { [weak self] in
            self?.handleDirectoryChange(onNewFile: onNewFile, onFileDeleted: onFileDeleted)
        }
        
        source?.setCancelHandler {
            close(fileDescriptor)
        }
        
        source?.resume()
        
        // Also set up a polling timer as backup (every 500ms)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.handleDirectoryChange(onNewFile: onNewFile, onFileDeleted: onFileDeleted)
        }
        
        print("Started watching directory: \(url.path)")
    }
    
    func stopWatching() {
        source?.cancel()
        source = nil
        pollingTimer?.invalidate()
        pollingTimer = nil
        watchedURL = nil
        seenFiles.removeAll()
    }
    
    private func initializeSeenFiles() {
        guard let watchedURL = watchedURL else { return }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: watchedURL, includingPropertiesForKeys: [.creationDateKey])
            
            let imageExtensions = ["png", "jpg", "jpeg", "heic", "tiff"]
            let imageFiles = contents.filter { url in
                let ext = url.pathExtension.lowercased()
                let fileName = url.lastPathComponent
                return imageExtensions.contains(ext) && !fileName.hasPrefix(".")
            }
            
            seenFiles = Set(imageFiles.map { $0.lastPathComponent })
            print("Initialized with \(seenFiles.count) existing screenshots")
            
        } catch {
            print("Error initializing seen files: \(error)")
        }
    }
    
    private func handleDirectoryChange(onNewFile: @escaping (URL) -> Void, onFileDeleted: @escaping (URL) -> Void) {
        guard let watchedURL = watchedURL else { return }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: watchedURL, includingPropertiesForKeys: [.creationDateKey])
            
            let imageExtensions = ["png", "jpg", "jpeg", "heic", "tiff"]
            let imageFiles = contents.filter { url in
                let ext = url.pathExtension.lowercased()
                let fileName = url.lastPathComponent
                return imageExtensions.contains(ext) && !fileName.hasPrefix(".")
            }
            
            // Find new files and deleted files by comparing with seen files
            let currentFiles = Set(imageFiles.map { $0.lastPathComponent })
            let newFileNames = currentFiles.subtracting(seenFiles)
            let deletedFileNames = seenFiles.subtracting(currentFiles)
            
            // Process each new file
            for fileName in newFileNames {
                if let newFile = imageFiles.first(where: { $0.lastPathComponent == fileName }) {
                    seenFiles.insert(fileName)
                    
                    // Check if this is a renamed file to prevent notifications
                    DispatchQueue.main.async {
                        if !ScreenshotStore.shared.isRenamedFile(newFile) {
                            print("Detected new screenshot: \(fileName)")
                            onNewFile(newFile)
                        } else {
                            print("Skipping notification for renamed file: \(fileName)")
                        }
                    }
                }
            }
            
            // Process each deleted file
            for fileName in deletedFileNames {
                seenFiles.remove(fileName)
                
                // Create a URL for the deleted file (we can't check if it exists, but we need the URL for removal)
                let deletedFileURL = watchedURL.appendingPathComponent(fileName)
                
                DispatchQueue.main.async {
                    print("Detected deleted screenshot: \(fileName)")
                    onFileDeleted(deletedFileURL)
                }
            }
            
        } catch {
            print("Error reading directory contents: \(error)")
        }
    }
    
    deinit {
        stopWatching()
    }
}
