import Foundation
import Vision
import AppKit

/// Detects faces in images using Apple's Vision framework
public final class FaceDetector {
    
    public init() {}
    
    /// Detects faces in an image and returns their bounding boxes in pixel coordinates
    /// - Parameter image: The image to analyze
    /// - Returns: Array of face bounding boxes in pixel coordinates (top-left origin)
    /// - Throws: Error if face detection fails
    public func detectFaces(in image: NSImage) async throws -> [CGRect] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw FaceDetectorError.invalidImage
        }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: FaceDetectorError.detectionFailed(error))
                    return
                }
                
                guard let observations = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let faceRects = observations.map { observation in
                    self.convertToPixelCoordinates(
                        normalizedBox: observation.boundingBox,
                        imageSize: imageSize
                    )
                }
                
                continuation.resume(returning: faceRects)
            }
            
            // Request high accuracy for face detection
            request.revision = VNDetectFaceRectanglesRequestRevision3
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: FaceDetectorError.detectionFailed(error))
            }
        }
    }
    
    /// Converts Vision's normalized coordinates (0-1) to pixel coordinates with top-left origin
    private func convertToPixelCoordinates(normalizedBox: CGRect, imageSize: CGSize) -> CGRect {
        // Vision uses bottom-left origin, convert to top-left origin
        let flippedY = 1.0 - normalizedBox.origin.y - normalizedBox.height
        
        let pixelX = normalizedBox.origin.x * imageSize.width
        let pixelY = flippedY * imageSize.height
        let pixelWidth = normalizedBox.width * imageSize.width
        let pixelHeight = normalizedBox.height * imageSize.height
        
        // Add moderate padding with minimum for small faces
        // 40% padding for larger faces, but at least 50px for tiny faces
        let percentagePadding = max(pixelWidth, pixelHeight) * 0.4
        let padding = max(percentagePadding, 50.0)
        
        // This ensures:
        // - Big face (200px): 80px padding = 360px blur
        // - Medium face (100px): 50px padding = 200px blur
        // - Small face (30px): 50px padding = 130px blur
        // - Tiny face (15px): 50px padding = 115px blur
        
        return CGRect(
            x: max(0, pixelX - padding),
            y: max(0, pixelY - padding),
            width: min(imageSize.width - (pixelX - padding), pixelWidth + 2 * padding),
            height: min(imageSize.height - (pixelY - padding), pixelHeight + 2 * padding)
        )
    }
}

/// Errors that can occur during face detection
public enum FaceDetectorError: Error, LocalizedError {
    case invalidImage
    case detectionFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image provided for face detection"
        case .detectionFailed(let error):
            return "Face detection failed: \(error.localizedDescription)"
        }
    }
}

