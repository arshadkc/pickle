import Foundation
import Vision
import AppKit

/// Represents a line of text recognized by OCR with its bounding box in pixel coordinates
public struct RecognizedLine {
    public let text: String
    public let boxInPixels: CGRect
    
    private let candidate: VNRecognizedText?
    private let imageSize: CGSize
    
    public init(text: String, boxInPixels: CGRect, candidate: VNRecognizedText?, imageSize: CGSize) {
        self.text = text
        self.boxInPixels = boxInPixels
        self.candidate = candidate
        self.imageSize = imageSize
    }
    
    /// Returns a precise pixel-space bounding box for a substring using Vision's character boxes when available.
    public func pixelBox(for range: Range<String.Index>) -> CGRect? {
        guard let candidate = candidate else { return nil }
        guard let observation = try? candidate.boundingBox(for: range) else { return nil }
        let normalizedRect = observation.boundingBox
        
        let flippedY = 1.0 - normalizedRect.origin.y - normalizedRect.height
        let pixelX = normalizedRect.origin.x * imageSize.width
        let pixelY = flippedY * imageSize.height
        let pixelWidth = normalizedRect.width * imageSize.width
        let pixelHeight = normalizedRect.height * imageSize.height
        
        return CGRect(
            x: pixelX,
            y: pixelY,
            width: pixelWidth,
            height: pixelHeight
        )
    }
}

/// Recognition accuracy levels for text recognition
public enum RecognitionLevel {
    case fast
    case accurate
    
    var visionLevel: VNRequestTextRecognitionLevel {
        switch self {
        case .fast:
            return .fast
        case .accurate:
            return .accurate
        }
    }
}

/// OCR utility that extracts text and bounding boxes from NSImage using Apple's Vision framework
public final class TextRecognizer {
    
    /// Minimum confidence threshold for accepting recognized text
    private static let minimumConfidence: Float = 0.25
    
    public init() {}
    
    /// Recognizes text in an image and returns lines with their pixel-coordinate bounding boxes
    /// - Parameters:
    ///   - image: The NSImage to perform OCR on
    ///   - languages: Array of language codes for recognition (default: ["en-US"])
    ///   - level: Recognition accuracy level (default: .fast)
    /// - Returns: Array of RecognizedLine objects containing text and pixel-coordinate bounding boxes
    /// - Throws: Error if image processing or OCR fails
    public func recognize(
        in image: NSImage,
        languages: [String] = ["en-US"],
        level: RecognitionLevel = .fast
    ) async throws -> [RecognizedLine] {
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.invalidImage
        }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.visionError(error))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let recognizedLines = self.processObservations(observations, imageSize: imageSize)
                continuation.resume(returning: recognizedLines)
            }
            
            // Configure the request
            request.recognitionLevel = level.visionLevel
            request.recognitionLanguages = languages
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.visionError(error))
            }
        }
    }
    
    /// Processes Vision observations and converts them to RecognizedLine objects
    private func processObservations(_ observations: [VNRecognizedTextObservation], imageSize: CGSize) -> [RecognizedLine] {
        var recognizedLines: [RecognizedLine] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first,
                  topCandidate.confidence >= Self.minimumConfidence else {
                continue
            }
            
            let text = topCandidate.string
            
            // Convert normalized coordinates to pixel coordinates
            let boundingBox = observation.boundingBox
            let pixelBox = convertToPixelCoordinates(
                normalizedBox: boundingBox,
                imageSize: imageSize
            )
            
            let recognizedLine = RecognizedLine(
                text: text,
                boxInPixels: pixelBox,
                candidate: topCandidate,
                imageSize: imageSize
            )
            recognizedLines.append(recognizedLine)
        }
        
        return recognizedLines
    }
    
    /// Converts Vision's normalized coordinates (0-1) to pixel coordinates
    private func convertToPixelCoordinates(normalizedBox: CGRect, imageSize: CGSize) -> CGRect {
        // Vision uses bottom-left origin, but we want top-left origin for consistency
        let flippedY = 1.0 - normalizedBox.origin.y - normalizedBox.height
        
        let pixelX = normalizedBox.origin.x * imageSize.width
        let pixelY = flippedY * imageSize.height
        let pixelWidth = normalizedBox.width * imageSize.width
        let pixelHeight = normalizedBox.height * imageSize.height
        
        return CGRect(
            x: pixelX,
            y: pixelY,
            width: pixelWidth,
            height: pixelHeight
        )
    }
}

/// Errors that can occur during OCR processing
public enum OCRError: Error, LocalizedError {
    case invalidImage
    case visionError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image provided for OCR processing"
        case .visionError(let error):
            return "Vision framework error: \(error.localizedDescription)"
        }
    }
}
