import Foundation
import AppKit
import os.log

/// Supported image formats for redaction
enum ImageFormat: CustomStringConvertible {
    case png
    case jpeg
    case unknown
    
    var description: String {
        switch self {
        case .png:
            return "PNG"
        case .jpeg:
            return "JPEG"
        case .unknown:
            return "Unknown"
        }
    }
}

/// Diagnostics for redaction pipeline performance
struct RedactionDiagnostics {
    var totalTime: TimeInterval
    var ocrTime: TimeInterval
    var detectionTime: TimeInterval
    var regionMergeTime: TimeInterval
    var redactionTime: TimeInterval
    var saveTime: TimeInterval
    var lineCount: Int
    var hitCount: Int
    var mergedRegionCount: Int
    var outputFormat: ImageFormat
    var outputPath: String
    var wasDownscaled: Bool
    var wasTimedOut: Bool
}

/// Redaction timeout configuration
struct RedactionConfig {
    static let maxPipelineTime: TimeInterval = 15.0
    static let maxImageDimension: CGFloat = 4000.0
    static let maxFilenameAttempts = 100
    static let downscaleFactor: CGFloat = 1.2
}

/// Service that handles the complete redaction pipeline
class RedactionService {
    static let shared = RedactionService()
    
    private let textRecognizer = TextRecognizer()
    private let imageRedactor = ImageRedactor()
    private let logger = Logger(subsystem: "com.test.Pickle", category: "RedactionService")
    
    private init() {}
    
    /// Performs redaction directly on the original image (overwrites it)
    /// - Parameters:
    ///   - imageURL: URL of the original image to redact
    ///   - completion: Completion handler with result
    func redactInPlace(imageURL: URL, completion: @escaping (Result<URL, RedactionServiceError>) -> Void) {
        NSLog("🚀 IN-PLACE REDACTION STARTED for: \(imageURL.lastPathComponent)")
        print("🚀 IN-PLACE REDACTION STARTED for: \(imageURL.lastPathComponent)")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var diagnostics = RedactionDiagnostics(
            totalTime: 0, ocrTime: 0, detectionTime: 0, regionMergeTime: 0,
            redactionTime: 0, saveTime: 0, lineCount: 0, hitCount: 0,
            mergedRegionCount: 0, outputFormat: .unknown, outputPath: "",
            wasDownscaled: false, wasTimedOut: false
        )
        
        Task {
            do {
                // Step 1: Load and validate image
                guard let originalImage = NSImage(contentsOf: imageURL) else {
                    await MainActor.run {
                        completion(.failure(.redactionFailed("Invalid image provided")))
                    }
                    return
                }
                
                let originalFormat = detectImageFormat(from: imageURL)
                diagnostics.outputFormat = originalFormat
                
                // Step 2: Check directory permissions
                let parentDirectory = imageURL.deletingLastPathComponent()
                guard FileManager.default.isWritableFile(atPath: parentDirectory.path) else {
                    await MainActor.run {
                        completion(.failure(.redactionFailed("Directory is read-only")))
                    }
                    return
                }
                
                // Step 3: Memory safety - downscale large images
                let (processedImage, wasDownscaled) = downscaleIfNeeded(originalImage)
                diagnostics.wasDownscaled = wasDownscaled
                
                // Step 4: Timeout-protected redaction pipeline
                let result = await withTimeout(RedactionConfig.maxPipelineTime) { [self] in
                    await performRedactionPipeline(
                        image: processedImage,
                        originalFormat: originalFormat,
                        diagnostics: &diagnostics
                    )
                }
                
                NSLog("🔍 WITH TIMEOUT RESULT: \(result != nil ? "SUCCESS" : "TIMEOUT")")
                if let result = result {
                    NSLog("🔍 PIPELINE RESULT: \(result)")
                    // Pipeline completed successfully
                    switch result {
                    case .success(let (redactedImage, _, lineCount, hitCount, mergedRegionCount)):
                        diagnostics.lineCount = lineCount
                        diagnostics.hitCount = hitCount
                        diagnostics.mergedRegionCount = mergedRegionCount
                        
                        // Step 5: Save directly to original file (overwrite)
                        diagnostics.outputPath = imageURL.path
                        NSLog("💾 SAVING REDACTED IMAGE to original file: \(imageURL.lastPathComponent)")
                        
                        let saveStartTime = CFAbsoluteTimeGetCurrent()
                        try saveImage(redactedImage, to: imageURL, originalFormat: originalFormat)
                        diagnostics.saveTime = CFAbsoluteTimeGetCurrent() - saveStartTime
                        NSLog("✅ REDACTED IMAGE SAVED SUCCESSFULLY!")
                        
                        // Step 6: Validate saved file
                        guard NSImage(contentsOf: imageURL) != nil else {
                            await MainActor.run {
                                completion(.failure(.redactionFailed("Saved file is invalid")))
                            }
                            return
                        }
                        
                        diagnostics.totalTime = CFAbsoluteTimeGetCurrent() - startTime
                        logDiagnostics(diagnostics)
                        
                        NSLog("🎉 IN-PLACE REDACTION PIPELINE COMPLETED SUCCESSFULLY!")
                        await MainActor.run {
                            completion(.success(imageURL))
                        }
                        
                    case .failure(let error):
                        await MainActor.run {
                            completion(.failure(error))
                        }
                    }
                } else {
                    // Timeout fallback: no changes to original file
                    diagnostics.wasTimedOut = true
                    diagnostics.totalTime = CFAbsoluteTimeGetCurrent() - startTime
                    
                    logDiagnostics(diagnostics)
                    
                    await MainActor.run {
                        completion(.failure(.redactionFailed("Redaction timed out")))
                    }
                }
                
            } catch {
                diagnostics.totalTime = CFAbsoluteTimeGetCurrent() - startTime
                logDiagnostics(diagnostics)
                
                await MainActor.run {
                    completion(.failure(.redactionFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    /// Performs automatic redaction on an image and saves it with timeout and safety guardrails
    /// - Parameters:
    ///   - imageURL: URL of the original image
    ///   - completion: Completion handler with result
    func redactAndSave(imageURL: URL, completion: @escaping (Result<URL, RedactionServiceError>) -> Void) {
        NSLog("🚀 REDACTION STARTED for: \(imageURL.lastPathComponent)")
        print("🚀 REDACTION STARTED for: \(imageURL.lastPathComponent)")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var diagnostics = RedactionDiagnostics(
            totalTime: 0, ocrTime: 0, detectionTime: 0, regionMergeTime: 0,
            redactionTime: 0, saveTime: 0, lineCount: 0, hitCount: 0,
            mergedRegionCount: 0, outputFormat: .unknown, outputPath: "",
            wasDownscaled: false, wasTimedOut: false
        )
        
        Task {
            do {
                // Step 1: Load and validate image
                guard let originalImage = NSImage(contentsOf: imageURL) else {
                    await MainActor.run {
                        completion(.failure(.redactionFailed("Invalid image provided")))
                    }
                    return
                }
                
                let originalFormat = detectImageFormat(from: imageURL)
                diagnostics.outputFormat = originalFormat
                
                // Step 2: Check directory permissions
                let parentDirectory = imageURL.deletingLastPathComponent()
                guard FileManager.default.isWritableFile(atPath: parentDirectory.path) else {
                    await MainActor.run {
                        completion(.failure(.redactionFailed("Directory is read-only")))
                    }
                    return
                }
                
                // Step 3: Memory safety - downscale large images
                let (processedImage, wasDownscaled) = downscaleIfNeeded(originalImage)
                diagnostics.wasDownscaled = wasDownscaled
                
                // Step 4: Timeout-protected redaction pipeline
                let result = await withTimeout(RedactionConfig.maxPipelineTime) { [self] in
                    await performRedactionPipeline(
                        image: processedImage,
                        originalFormat: originalFormat,
                        diagnostics: &diagnostics
                    )
                }
                
                NSLog("🔍 WITH TIMEOUT RESULT: \(result != nil ? "SUCCESS" : "TIMEOUT")")
                if let result = result {
                    NSLog("🔍 PIPELINE RESULT: \(result)")
                    // Pipeline completed successfully
                    switch result {
                    case .success(let (redactedImage, _, lineCount, hitCount, mergedRegionCount)):
                        diagnostics.lineCount = lineCount
                        diagnostics.hitCount = hitCount
                        diagnostics.mergedRegionCount = mergedRegionCount
                        
                        // Step 5: Save to temporary location first
                        let tempURL = URL(fileURLWithPath: "/tmp/pickle_redact_\(UUID().uuidString).\(originalFormat == .jpeg ? "jpg" : "png")")
                        NSLog("💾 SAVING REDACTED IMAGE to temp: \(tempURL.lastPathComponent)")
                        
                        let saveStartTime = CFAbsoluteTimeGetCurrent()
                        try saveImage(redactedImage, to: tempURL, originalFormat: originalFormat)
                        diagnostics.saveTime = CFAbsoluteTimeGetCurrent() - saveStartTime
                        
                        // Step 6: Validate temp file
                        guard NSImage(contentsOf: tempURL) != nil else {
                            try? FileManager.default.removeItem(at: tempURL)
                            await MainActor.run {
                                completion(.failure(.redactionFailed("Redacted file is invalid")))
                            }
                            return
                        }
                        
                        // Step 7: Move to final location
                        let outputURL = try generateUniqueOutputURL(for: imageURL, format: originalFormat)
                        diagnostics.outputPath = outputURL.path
                        NSLog("💾 MOVING REDACTED IMAGE to final location: \(outputURL.lastPathComponent)")
                        
                        try FileManager.default.moveItem(at: tempURL, to: outputURL)
                        NSLog("✅ REDACTED IMAGE SAVED SUCCESSFULLY!")
                        
                        diagnostics.totalTime = CFAbsoluteTimeGetCurrent() - startTime
                        logDiagnostics(diagnostics)
                        
                        NSLog("🎉 REDACTION PIPELINE COMPLETED SUCCESSFULLY!")
                        await MainActor.run {
                            completion(.success(outputURL))
                        }
                        
                    case .failure(let error):
                        await MainActor.run {
                            completion(.failure(error))
                        }
                    }
                } else {
                    // Timeout fallback: save unredacted copy to temp first
                    diagnostics.wasTimedOut = true
                    diagnostics.totalTime = CFAbsoluteTimeGetCurrent() - startTime
                    
                    // Save to temporary location first
                    let tempURL = URL(fileURLWithPath: "/tmp/pickle_redact_\(UUID().uuidString).\(originalFormat == .jpeg ? "jpg" : "png")")
                    NSLog("💾 SAVING UNREDACTED COPY to temp: \(tempURL.lastPathComponent)")
                    
                    let saveStartTime = CFAbsoluteTimeGetCurrent()
                    try saveImage(originalImage, to: tempURL, originalFormat: originalFormat)
                    diagnostics.saveTime = CFAbsoluteTimeGetCurrent() - saveStartTime
                    
                    // Validate temp file
                    guard NSImage(contentsOf: tempURL) != nil else {
                        try? FileManager.default.removeItem(at: tempURL)
                        await MainActor.run {
                            completion(.failure(.redactionFailed("Unredacted copy is invalid")))
                        }
                        return
                    }
                    
                    // Move to final location
                    let outputURL = try generateUniqueOutputURL(for: imageURL, format: originalFormat)
                    diagnostics.outputPath = outputURL.path
                    NSLog("💾 MOVING UNREDACTED COPY to final location: \(outputURL.lastPathComponent)")
                    
                    try FileManager.default.moveItem(at: tempURL, to: outputURL)
                    
                    // Validate final file
                    guard NSImage(contentsOf: outputURL) != nil else {
                        try? FileManager.default.removeItem(at: outputURL)
                        await MainActor.run {
                            completion(.failure(.redactionFailed("Timeout fallback file is invalid")))
                        }
                        return
                    }
                    
                    logDiagnostics(diagnostics)
                    
                    await MainActor.run {
                        completion(.success(outputURL))
                    }
                }
                
            } catch {
                diagnostics.totalTime = CFAbsoluteTimeGetCurrent() - startTime
                logDiagnostics(diagnostics)
                
                await MainActor.run {
                    completion(.failure(.redactionFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Performs the redaction pipeline with timing diagnostics
    private func performRedactionPipeline(
        image: NSImage,
        originalFormat: ImageFormat,
        diagnostics: inout RedactionDiagnostics
    ) async -> Result<(NSImage, [CGRect], Int, Int, Int), RedactionServiceError> {
        
        do {
            // OCR
            NSLog("🔍 STARTING OCR...")
            let ocrStartTime = CFAbsoluteTimeGetCurrent()
            let recognizedLines = try await textRecognizer.recognize(in: image, level: .fast)
            diagnostics.ocrTime = CFAbsoluteTimeGetCurrent() - ocrStartTime
            NSLog("✅ OCR COMPLETED - Found \(recognizedLines.count) lines")
            
            // Detection
            let detectionStartTime = CFAbsoluteTimeGetCurrent()
            var allHits: [[Hit]] = []
            var totalHits = 0
            for line in recognizedLines {
                let hits = SensitivityDetector.detect(in: line.text)
                allHits.append(hits)
                totalHits += hits.count
            }
            diagnostics.detectionTime = CFAbsoluteTimeGetCurrent() - detectionStartTime
            
            // Log detected content for debugging
            NSLog("📊 ABOUT TO LOG DETECTED CONTENT - Lines: \(recognizedLines.count), Hits: \(allHits.flatMap { $0 }.count)")
            logDetectedContent(recognizedLines, allHits)
            NSLog("✅ DETECTED CONTENT LOGGING COMPLETED")
            
            // Region building
            let regionStartTime = CFAbsoluteTimeGetCurrent()
            let regions = RegionBuilder.regions(for: recognizedLines, hits: allHits, padding: 2)
            diagnostics.regionMergeTime = CFAbsoluteTimeGetCurrent() - regionStartTime
            
            // Redaction
            NSLog("🎨 STARTING REDACTION PROCESS...")
            let redactionStartTime = CFAbsoluteTimeGetCurrent()
            let redactedImage: NSImage
            if regions.isEmpty {
                // No sensitive content found, but still create a copy
                NSLog("⚠️ NO SENSITIVE REGIONS FOUND - Creating unredacted copy")
                redactedImage = image
            } else {
                NSLog("🔴 APPLYING PIXELATION to \(regions.count) regions...")
                redactedImage = try imageRedactor.redact(image: image, in: regions, style: .pixelate(scale: 8))
                NSLog("✅ PIXELATION COMPLETED!")
            }
            diagnostics.redactionTime = CFAbsoluteTimeGetCurrent() - redactionStartTime
            NSLog("🎯 REDACTION PIPELINE RETURNING SUCCESS - Image size: \(redactedImage.size), Regions: \(regions.count)")
            
            return .success((redactedImage, regions, recognizedLines.count, totalHits, regions.count))
            
        } catch {
            return .failure(.redactionFailed(error.localizedDescription))
        }
    }
    
    /// Downscales image if dimensions exceed memory safety limits
    private func downscaleIfNeeded(_ image: NSImage) -> (NSImage, Bool) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return (image, false)
        }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        guard width > RedactionConfig.maxImageDimension || height > RedactionConfig.maxImageDimension else {
            return (image, false)
        }
        
        // Calculate downscaled size
        let scale = RedactionConfig.downscaleFactor
        let newWidth = width / scale
        let newHeight = height / scale
        
        // Create downscaled image
        let newSize = NSSize(width: newWidth, height: newHeight)
        let downscaledImage = NSImage(size: newSize)
        
        downscaledImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        downscaledImage.unlockFocus()
        
        return (downscaledImage, true)
    }
    
    /// Timeout wrapper for async operations
    private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async -> T) async -> T? {
        return await withTaskGroup(of: T?.self) { group in
            group.addTask {
                await operation()
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }
            
            let result = await group.next()
            group.cancelAll()
            return result ?? nil
        }
    }
    
    /// Logs diagnostics information (debug builds only)
    private func logDiagnostics(_ diagnostics: RedactionDiagnostics) {
        #if DEBUG
        logger.info("""
            Redaction Pipeline Diagnostics:
            Total: \(String(format: "%.3f", diagnostics.totalTime))s
            OCR: \(String(format: "%.3f", diagnostics.ocrTime))s
            Detection: \(String(format: "%.3f", diagnostics.detectionTime))s
            Region Merge: \(String(format: "%.3f", diagnostics.regionMergeTime))s
            Redaction: \(String(format: "%.3f", diagnostics.redactionTime))s
            Save: \(String(format: "%.3f", diagnostics.saveTime))s
            Lines: \(diagnostics.lineCount), Hits: \(diagnostics.hitCount), Regions: \(diagnostics.mergedRegionCount)
            Format: \(diagnostics.outputFormat), Path: \(diagnostics.outputPath)
            Downscaled: \(diagnostics.wasDownscaled), Timed Out: \(diagnostics.wasTimedOut)
            """)
        #endif
    }
    
    /// Logs detailed information about detected and redacted content
    private func logDetectedContent(_ recognizedLines: [RecognizedLine], _ allHits: [[Hit]]) {
        NSLog("🔍 ENTERING logDetectedContent function")
        print("🔍 DETECTED CONTENT ANALYSIS:")
        NSLog("🔍 DETECTED CONTENT ANALYSIS:")
        
        var totalDetected = 0
        var contentByType: [String: [String]] = [:]
        
        for (lineIndex, line) in recognizedLines.enumerated() {
            let hits = allHits[lineIndex]
            
            if !hits.isEmpty {
                print("📝 Line \(lineIndex + 1): \"\(line.text)\"")
                NSLog("📝 Line \(lineIndex + 1): \"\(line.text)\"")
                
                for hit in hits {
                    let detectedText = String(line.text[hit.textRange])
                    let kindDescription = kindDescription(hit.kind)
                    
                    print("   🔴 \(kindDescription): \"\(detectedText)\"")
                    NSLog("   🔴 \(kindDescription): \"\(detectedText)\"")
                    
                    // Group by type for summary
                    if contentByType[kindDescription] == nil {
                        contentByType[kindDescription] = []
                    }
                    contentByType[kindDescription]?.append(detectedText)
                    totalDetected += 1
                }
            }
        }
        
        // Summary by type
        print("📊 DETECTION SUMMARY:")
        NSLog("📊 DETECTION SUMMARY:")
        for (type, items) in contentByType.sorted(by: { $0.key < $1.key }) {
            print("   \(type): \(items.count) items - \(items.joined(separator: ", "))")
            NSLog("   \(type): \(items.count) items - \(items.joined(separator: ", "))")
        }
        
        print("🎯 TOTAL REDACTED: \(totalDetected) items across \(recognizedLines.count) lines")
        NSLog("🎯 TOTAL REDACTED: \(totalDetected) items across \(recognizedLines.count) lines")
    }
    
    /// Returns a human-readable description of the hit kind
    private func kindDescription(_ kind: Kind) -> String {
        switch kind {
        case .mention:
            return "Mention"
        case .channel:
            return "Channel"
        case .email:
            return "Email"
        case .phone:
            return "Phone"
        case .url:
            return "URL"
        case .address:
            return "Address"
        case .transit:
            return "Transit"
        case .personalName:
            return "Personal Name"
        case .organizationName:
            return "Organization Name"
        case .customTerm(let term):
            return "Custom Term (\(term))"
        }
    }
    
    /// Generates a unique output URL for the redacted image with format preservation and infinite loop protection
    private func generateUniqueOutputURL(for originalURL: URL, format: ImageFormat) throws -> URL {
        let directory = originalURL.deletingLastPathComponent()
        let originalName = originalURL.deletingPathExtension().lastPathComponent
        
        // Determine file extension based on format
        let fileExtension: String
        switch format {
        case .png:
            fileExtension = "png"
        case .jpeg:
            fileExtension = "jpg"  // Use .jpg for consistency
        case .unknown:
            fileExtension = "png"  // Default to PNG for unknown formats
        }
        
        var counter = 0
        var outputURL: URL
        
        repeat {
            guard counter < RedactionConfig.maxFilenameAttempts else {
                throw RedactionServiceError.fileWriteFailed
            }
            
            let suffix = counter == 0 ? "" : "-\(counter)"
            let newName = "redact-\(originalName)\(suffix).\(fileExtension)"
            outputURL = directory.appendingPathComponent(newName)
            counter += 1
        } while FileManager.default.fileExists(atPath: outputURL.path)
        
        return outputURL
    }
    
    /// Saves an NSImage to the specified URL with format preservation and atomic writes
    private func saveImage(_ image: NSImage, to url: URL, originalFormat: ImageFormat) throws {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw RedactionServiceError.fileWriteFailed
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let data: Data
        
        // Format-aware saving
        switch originalFormat {
        case .png:
            guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                throw RedactionServiceError.fileWriteFailed
            }
            data = pngData
            
        case .jpeg:
            guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [
                .compressionFactor: 0.9
            ]) else {
                throw RedactionServiceError.fileWriteFailed
            }
            data = jpegData
            
        case .unknown:
            // Default to PNG for unknown formats
            guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                throw RedactionServiceError.fileWriteFailed
            }
            data = pngData
        }
        
        // Atomic write: write to temporary file first, then move
        let tempURL = url.appendingPathExtension("tmp")
        
        do {
            try data.write(to: tempURL)
            
            // Atomic move to final destination
            _ = try FileManager.default.replaceItem(at: url, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
            
        } catch {
            // Clean up temp file if it exists
            try? FileManager.default.removeItem(at: tempURL)
            throw RedactionServiceError.fileWriteFailed
        }
    }
    
    /// Detects the image format from the original file
    private func detectImageFormat(from url: URL) -> ImageFormat {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "png":
            return .png
        case "jpg", "jpeg":
            return .jpeg
        default:
            return .unknown
        }
    }
}

/// Errors that can occur during the redaction service process
enum RedactionServiceError: Error, LocalizedError {
    case fileWriteFailed
    case redactionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileWriteFailed:
            return "Failed to save redacted image"
        case .redactionFailed(let message):
            return "Redaction failed: \(message)"
        }
    }
}
