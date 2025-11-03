import Foundation
import Vision
import AppKit

/// Detects QR codes and barcodes in images using Apple's Vision framework
public final class QRCodeDetector {
    
    public init() {}
    
    /// Detects QR codes and barcodes in an image and returns their bounding boxes in pixel coordinates
    /// - Parameter image: The image to analyze
    /// - Returns: Array of barcode/QR code bounding boxes in pixel coordinates (top-left origin)
    /// - Throws: Error if barcode detection fails
    public func detectQRCodesAndBarcodes(in image: NSImage) async throws -> [CGRect] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw QRCodeDetectorError.invalidImage
        }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: QRCodeDetectorError.detectionFailed(error))
                    return
                }
                
                guard let observations = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let barcodeRects = observations.map { observation in
                    self.convertToPixelCoordinates(
                        normalizedBox: observation.boundingBox,
                        imageSize: imageSize
                    )
                }
                
                continuation.resume(returning: barcodeRects)
            }
            
            // Detect all barcode types (QR, EAN, Code128, etc.)
            request.symbologies = [
                .QR,
                .Aztec,
                .PDF417,
                .DataMatrix,
                .EAN8,
                .EAN13,
                .Code39,
                .Code93,
                .Code128,
                .ITF14,
                .UPCE
            ]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: QRCodeDetectorError.detectionFailed(error))
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
        
        // Add padding to ensure full QR code coverage (25%)
        let padding = max(pixelWidth, pixelHeight) * 0.25
        
        return CGRect(
            x: max(0, pixelX - padding),
            y: max(0, pixelY - padding),
            width: min(imageSize.width - (pixelX - padding), pixelWidth + 2 * padding),
            height: min(imageSize.height - (pixelY - padding), pixelHeight + 2 * padding)
        )
    }
}

/// Errors that can occur during QR code/barcode detection
public enum QRCodeDetectorError: Error, LocalizedError {
    case invalidImage
    case detectionFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image provided for QR code detection"
        case .detectionFailed(let error):
            return "QR code detection failed: \(error.localizedDescription)"
        }
    }
}

