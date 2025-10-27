import Foundation
import CoreImage
import AppKit

/// Redaction styles for obscuring sensitive content
public enum Style {
    case blur(radius: CGFloat)
    case pixelate(scale: CGFloat)
}

/// Applies redaction effects to specified regions of an image and handles clipboard operations
public final class ImageRedactor {
    
    private let context: CIContext
    
    public init() {
        // Use software rendering to ensure consistent results across devices
        self.context = CIContext(options: [.workingColorSpace: NSNull()])
    }
    
    /// Redacts specified regions of an image with the given style
    /// - Parameters:
    ///   - image: The original image to redact
    ///   - regions: Array of rectangles defining areas to redact
    ///   - style: The redaction style (blur or pixelate)
    /// - Returns: A new NSImage with redacted regions
    /// - Throws: RedactionError if processing fails
    public func redact(image: NSImage, in regions: [CGRect], style: Style) throws -> NSImage {
        
        guard !regions.isEmpty else {
            return image
        }
        
        // Convert NSImage to CIImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw RedactionError.invalidImage
        }
        
        let inputImage = CIImage(cgImage: cgImage)
        let extent = inputImage.extent
        let imageSize = extent.size
        
        NSLog("🎨 ImageRedactor: Processing \(regions.count) regions for redaction")
        
        let ciRegions = regions.enumerated().compactMap { index, region -> CGRect? in
            let converted = convertToCoreImageSpace(region, imageSize: imageSize)
            let clamped = converted.intersection(extent)
            if clamped.isEmpty {
                NSLog("⚠️ ImageRedactor: Region \(index) is empty after clamping, skipping")
                return nil
            }
            NSLog("🔴 ImageRedactor: Processing region \(index + 1)/\(regions.count) at \(clamped)")
            return clamped
        }
        
        guard !ciRegions.isEmpty else {
            return image
        }
        
        let mask = buildMask(for: ciRegions, extent: extent)
        let filteredImage = try applyRedaction(to: inputImage, style: style)
        
        let resultImage = filteredImage.applyingFilter("CIBlendWithMask", parameters: [
            "inputBackgroundImage": inputImage,
            "inputMaskImage": mask
        ])
        
        return try convertToNSImage(resultImage, originalImage: image)
    }
    
    /// Copies an image to the clipboard
    /// - Parameter image: The image to copy
    public func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    // MARK: - Private Methods
    
    /// Applies the selected redaction style to the full image and clamps the extent.
    private func applyRedaction(to image: CIImage, style: Style) throws -> CIImage {
        NSLog("🎨 applyRedaction: Processing full image with style \(style)")
        let filtered: CIImage
        switch style {
        case .blur(let radius):
            filtered = try applyBlur(to: image, radius: radius)
        case .pixelate(let scale):
            NSLog("🎨 applyRedaction: Applying pixelation with scale \(scale)")
            filtered = try applyPixelate(to: image, scale: scale)
            NSLog("🎨 applyRedaction: Pixelation applied successfully")
        }
        return filtered.cropped(to: image.extent)
    }
    
    /// Applies Gaussian blur effect
    private func applyBlur(to image: CIImage, radius: CGFloat) throws -> CIImage {
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            throw RedactionError.filterCreationFailed
        }
        
        blurFilter.setValue(image, forKey: kCIInputImageKey)
        blurFilter.setValue(radius, forKey: kCIInputRadiusKey)
        
        guard let outputImage = blurFilter.outputImage else {
            throw RedactionError.filterProcessingFailed
        }
        
        return outputImage
    }
    
    /// Applies pixelate effect
    private func applyPixelate(to image: CIImage, scale: CGFloat) throws -> CIImage {
        guard let pixelateFilter = CIFilter(name: "CIPixellate") else {
            throw RedactionError.filterCreationFailed
        }
        
        pixelateFilter.setValue(image, forKey: kCIInputImageKey)
        pixelateFilter.setValue(scale, forKey: kCIInputScaleKey)
        
        guard let outputImage = pixelateFilter.outputImage else {
            throw RedactionError.filterProcessingFailed
        }
        
        return outputImage
    }
    
    /// Builds a combined white-on-black mask that covers every Core Image region.
    private func buildMask(for regions: [CGRect], extent: CGRect) -> CIImage {
        var mask = CIImage(color: .black).cropped(to: extent)
        for region in regions {
            let expanded = expand(region: region, within: extent)
            let whiteRect = CIImage(color: .white).cropped(to: expanded)
            mask = whiteRect.composited(over: mask)
        }
        return mask
    }
    
    /// Slightly expands a region to compensate for OCR box underestimation.
    private func expand(region: CGRect, within extent: CGRect, padding: CGFloat = 16) -> CGRect {
        let expanded = region.insetBy(dx: -padding, dy: -padding)
        return expanded.intersection(extent)
    }
    
    /// Converts a region from top-left origin (Cocoa) to Core Image space (bottom-left origin).
    private func convertToCoreImageSpace(_ region: CGRect, imageSize: CGSize) -> CGRect {
        return CGRect(
            x: region.origin.x,
            y: imageSize.height - region.origin.y - region.height,
            width: region.width,
            height: region.height
        )
    }
    
    /// Converts CIImage back to NSImage while preserving original properties
    private func convertToNSImage(_ ciImage: CIImage, originalImage: NSImage) throws -> NSImage {
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw RedactionError.imageConversionFailed
        }
        
        return NSImage(cgImage: cgImage, size: originalImage.size)
    }
}

/// Errors that can occur during image redaction
public enum RedactionError: Error, LocalizedError {
    case invalidImage
    case filterCreationFailed
    case filterProcessingFailed
    case compositingFailed
    case imageConversionFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image provided for redaction"
        case .filterCreationFailed:
            return "Failed to create Core Image filter"
        case .filterProcessingFailed:
            return "Failed to process image with filter"
        case .compositingFailed:
            return "Failed to composite redacted region"
        case .imageConversionFailed:
            return "Failed to convert processed image"
        }
    }
}
