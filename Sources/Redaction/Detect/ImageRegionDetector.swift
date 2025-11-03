import Foundation
import Vision
import AppKit
import CoreImage

/// Detects embedded images and photos in screenshots
public final class ImageRegionDetector {
    
    public init() {}
    
    /// Detects image regions (profile pictures, photos, screenshots) in a screenshot
    /// - Parameter image: The screenshot to analyze
    /// - Returns: Array of image region bounding boxes in pixel coordinates (top-left origin)
    /// - Throws: Error if detection fails
    public func detectImageRegions(in image: NSImage) async throws -> [CGRect] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageRegionDetectorError.invalidImage
        }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        // Use Vision's saliency detection to find interesting regions (photos, avatars)
        let salientRegions = try await detectSalientRegions(cgImage: cgImage, imageSize: imageSize)
        
        // Also detect rectangular photo-like regions using attention-based saliency
        let attentionRegions = try await detectAttentionRegions(cgImage: cgImage, imageSize: imageSize)
        
        // Combine and deduplicate
        var allRegions = salientRegions + attentionRegions
        allRegions = mergeOverlappingRegions(allRegions)
        
        return allRegions
    }
    
    /// Detects salient objects (profile pictures, embedded photos)
    private func detectSalientRegions(cgImage: CGImage, imageSize: CGSize) async throws -> [CGRect] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateObjectnessBasedSaliencyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ImageRegionDetectorError.detectionFailed(error))
                    return
                }
                
                guard let observation = request.results?.first as? VNSaliencyImageObservation else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Get salient objects (areas of interest like photos/avatars)
                let objects = observation.salientObjects ?? []
                
                let rects = objects.compactMap { object -> CGRect? in
                    // Higher confidence threshold to reduce false positives
                    guard object.confidence > 0.5 else { return nil }
                    
                    let normalizedBox = object.boundingBox
                    
                    // More conservative area range - focus on actual photos/avatars
                    // 0.001 = small avatars, 0.3 = large embedded photos
                    let area = normalizedBox.width * normalizedBox.height
                    guard area > 0.001 && area < 0.3 else { return nil }
                    
                    NSLog("🖼️ Saliency object: confidence=\(object.confidence), area=\(area), box=\(normalizedBox)")
                    
                    return self.convertToPixelCoordinates(
                        normalizedBox: normalizedBox,
                        imageSize: imageSize
                    )
                }
                
                continuation.resume(returning: rects)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ImageRegionDetectorError.detectionFailed(error))
            }
        }
    }
    
    /// Detects attention-based regions (where eyes would naturally look - often photos)
    private func detectAttentionRegions(cgImage: CGImage, imageSize: CGSize) async throws -> [CGRect] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateAttentionBasedSaliencyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ImageRegionDetectorError.detectionFailed(error))
                    return
                }
                
                guard let observation = request.results?.first as? VNSaliencyImageObservation else {
                    continuation.resume(returning: [])
                    return
                }
                
                // Get salient objects from attention-based analysis
                let objects = observation.salientObjects ?? []
                
                let rects = objects.compactMap { object -> CGRect? in
                    // Higher threshold to reduce false positives
                    guard object.confidence > 0.6 else { return nil }
                    
                    let normalizedBox = object.boundingBox
                    let area = normalizedBox.width * normalizedBox.height
                    guard area > 0.001 && area < 0.3 else { return nil }
                    
                    NSLog("🎯 Attention object: confidence=\(object.confidence), area=\(area), box=\(normalizedBox)")
                    
                    return self.convertToPixelCoordinates(
                        normalizedBox: normalizedBox,
                        imageSize: imageSize
                    )
                }
                
                continuation.resume(returning: rects)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ImageRegionDetectorError.detectionFailed(error))
            }
        }
    }
    
    /// Merges overlapping regions
    private func mergeOverlappingRegions(_ regions: [CGRect]) -> [CGRect] {
        guard !regions.isEmpty else { return [] }
        
        var merged: [CGRect] = []
        let sorted = regions.sorted { $0.minX < $1.minX }
        
        for region in sorted {
            if let last = merged.last, regionsOverlap(last, region) {
                // Merge with last region
                merged[merged.count - 1] = last.union(region)
            } else {
                merged.append(region)
            }
        }
        
        return merged
    }
    
    /// Checks if two regions overlap
    private func regionsOverlap(_ rect1: CGRect, _ rect2: CGRect) -> Bool {
        return rect1.intersects(rect2)
    }
    
    /// Converts Vision's normalized coordinates (0-1) to pixel coordinates with top-left origin
    private func convertToPixelCoordinates(normalizedBox: CGRect, imageSize: CGSize) -> CGRect {
        // Vision uses bottom-left origin, convert to top-left origin
        let flippedY = 1.0 - normalizedBox.origin.y - normalizedBox.height
        
        let pixelX = normalizedBox.origin.x * imageSize.width
        let pixelY = flippedY * imageSize.height
        let pixelWidth = normalizedBox.width * imageSize.width
        let pixelHeight = normalizedBox.height * imageSize.height
        
        // Add tight padding - just enough for circular avatars and image edges
        // 10% padding for images, with minimum 8px
        let percentagePadding = max(pixelWidth, pixelHeight) * 0.1
        let padding = max(percentagePadding, 8.0)
        
        // This ensures coverage without extending too far:
        // - Big image (100px): 10px padding = 120px blur
        // - Medium image (50px): 8px padding = 66px blur
        // - Small avatar (20px): 8px padding = 36px blur
        
        return CGRect(
            x: max(0, pixelX - padding),
            y: max(0, pixelY - padding),
            width: min(imageSize.width - (pixelX - padding), pixelWidth + 2 * padding),
            height: min(imageSize.height - (pixelY - padding), pixelHeight + 2 * padding)
        )
    }
}

/// Errors that can occur during image region detection
public enum ImageRegionDetectorError: Error, LocalizedError {
    case invalidImage
    case detectionFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image provided for image region detection"
        case .detectionFailed(let error):
            return "Image region detection failed: \(error.localizedDescription)"
        }
    }
}

