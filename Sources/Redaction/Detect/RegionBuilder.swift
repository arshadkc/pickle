import Foundation
import CoreGraphics

/// Builds pixel regions for redaction by mapping token hits back to their approximate rectangles
/// and merging overlapping/adjacent regions for clean redaction areas
public enum RegionBuilder {
    
    /// Creates merged redaction regions from recognized lines and their sensitivity hits
    /// - Parameters:
    ///   - lines: Array of recognized text lines with their pixel-coordinate bounding boxes
    ///   - hits: Array of hit arrays, one per line, containing detected sensitive tokens
    ///   - padding: Padding to add around each region (default: 2 points)
    /// - Returns: Array of merged pixel-coordinate rectangles for redaction
    public static func regions(
        for lines: [RecognizedLine],
        hits: [[Hit]],
        padding: CGFloat = 2
    ) -> [CGRect] {
        
        guard lines.count == hits.count else {
            return []
        }
        
        var allRegions: [CGRect] = []
        
        // Process each line and its hits
        for (lineIndex, line) in lines.enumerated() {
            let lineHits = hits[lineIndex]
            let lineRegions = createRegionsForLine(line: line, hits: lineHits, padding: padding)
            allRegions.append(contentsOf: lineRegions)
        }
        
        // Merge overlapping and adjacent regions
        return mergeRegions(allRegions)
    }
    
    /// Creates regions for a single line by approximating token rectangles
    private static func createRegionsForLine(
        line: RecognizedLine,
        hits: [Hit],
        padding: CGFloat
    ) -> [CGRect] {
        
        guard !hits.isEmpty else { return [] }
        
        let lineBox = line.boxInPixels
        let lineText = line.text
        var regions: [CGRect] = []
        
        // Sort hits by their position in the text and merge overlapping ranges (e.g., email + mention)
        let sortedHits = mergeOverlappingHits(
            hits.sorted { $0.textRange.lowerBound < $1.textRange.lowerBound }
        )
        
        print("🧭 RegionBuilder: line=\(line.text) hits=\(hits.count) merged=\(sortedHits.count)")
        for hit in sortedHits {
            let start = line.text.distance(from: line.text.startIndex, to: hit.textRange.lowerBound)
            let end = line.text.distance(from: line.text.startIndex, to: hit.textRange.upperBound)
            print("   👉 range=\(start)..\(end) kind=\(hit.kind)")
        }
        for hit in sortedHits {
            // Prefer Vision-provided bounding boxes for substring ranges when available
            let tokenRect: CGRect
            if let preciseRect = line.pixelBox(for: hit.textRange) {
                tokenRect = preciseRect
            } else {
                tokenRect = approximateTokenRect(
                    in: lineText,
                    hit: hit,
                    lineBox: lineBox
                )
            }
            
            // Inflate with padding and clamp to image bounds
            let paddedRect = inflateAndClamp(
                rect: tokenRect,
                padding: padding,
                bounds: lineBox
            )
            
            regions.append(paddedRect)
        }
        
        return regions
    }
    
    /// Approximates a token's rectangle by slicing the line box horizontally based on text position
    private static func approximateTokenRect(
        in text: String,
        hit: Hit,
        lineBox: CGRect
    ) -> CGRect {
        
        let textRange = hit.textRange
        let startIndex = text.distance(from: text.startIndex, to: textRange.lowerBound)
        let endIndex = text.distance(from: text.startIndex, to: textRange.upperBound)
        let tokenLength = endIndex - startIndex
        let totalLength = text.count
        
        // Calculate horizontal position and width as fractions of the line box
        let startFraction = totalLength > 0 ? CGFloat(startIndex) / CGFloat(totalLength) : 0
        let widthFraction = totalLength > 0 ? CGFloat(tokenLength) / CGFloat(totalLength) : 0
        
        // Map to pixel coordinates
        let x = lineBox.minX + (startFraction * lineBox.width)
        let width = widthFraction * lineBox.width
        
        return CGRect(
            x: x,
            y: lineBox.minY,
            width: width,
            height: lineBox.height
        )
    }
    
    /// Inflates a rectangle with padding and clamps it to the given bounds
    private static func inflateAndClamp(
        rect: CGRect,
        padding: CGFloat,
        bounds: CGRect
    ) -> CGRect {
        
        let inflatedRect = CGRect(
            x: rect.minX - padding,
            y: rect.minY - padding,
            width: rect.width + (2 * padding),
            height: rect.height + (2 * padding)
        )
        
        // Clamp to bounds
        let clampedRect = CGRect(
            x: max(inflatedRect.minX, bounds.minX),
            y: max(inflatedRect.minY, bounds.minY),
            width: min(inflatedRect.width, bounds.maxX - max(inflatedRect.minX, bounds.minX)),
            height: min(inflatedRect.height, bounds.maxY - max(inflatedRect.minY, bounds.minY))
        )
        
        return clampedRect
    }
    
    /// Merges overlapping or adjacent hit ranges to avoid duplicate regions for the same text.
    private static func mergeOverlappingHits(_ hits: [Hit]) -> [Hit] {
        guard !hits.isEmpty else { return [] }
        var merged: [Hit] = []
        for hit in hits {
            if let last = merged.last, let combined = mergeIfNeeded(last, hit) {
                merged[merged.count - 1] = combined
            } else {
                merged.append(hit)
            }
        }
        return merged
    }
    
    /// Attempts to merge two hits when their ranges touch or overlap.
    private static func mergeIfNeeded(_ lhs: Hit, _ rhs: Hit) -> Hit? {
        let lhsRange = lhs.textRange
        let rhsRange = rhs.textRange
        let touches = lhsRange.upperBound == rhsRange.lowerBound || rhsRange.upperBound == lhsRange.lowerBound
        guard lhsRange.overlaps(rhsRange) || rhsRange.overlaps(lhsRange) || touches else {
            return nil
        }
        let lower = min(lhsRange.lowerBound, rhsRange.lowerBound)
        let upper = max(lhsRange.upperBound, rhsRange.upperBound)
        let mergedRange = lower..<upper
        let resolvedKind: Kind
        switch (lhs.kind, rhs.kind) {
        case (.mention, let other), (let other, .mention):
            resolvedKind = other
        case (.url, let other), (let other, .url):
            resolvedKind = other
        default:
            resolvedKind = lhs.kind
        }
        return Hit(textRange: mergedRange, kind: resolvedKind)
    }


    /// Merges overlapping and adjacent regions (within 4px gap) into single regions
    private static func mergeRegions(_ regions: [CGRect]) -> [CGRect] {
        
        guard !regions.isEmpty else { return [] }
        
        var mergedRegions: [CGRect] = []
        let sortedRegions = regions.sorted { $0.minX < $1.minX }
        
        var currentRegion = sortedRegions[0]
        
        for i in 1..<sortedRegions.count {
            let nextRegion = sortedRegions[i]
            
            if shouldMerge(currentRegion, nextRegion) {
                // Merge the regions
                currentRegion = mergeTwoRegions(currentRegion, nextRegion)
            } else {
                // Add current region and start a new one
                mergedRegions.append(currentRegion)
                currentRegion = nextRegion
            }
        }
        
        // Add the last region
        mergedRegions.append(currentRegion)
        
        return mergedRegions
    }
    
    /// Determines if two regions should be merged (overlapping or within 4px gap)
    private static func shouldMerge(_ rect1: CGRect, _ rect2: CGRect) -> Bool {
        let gap = 4.0
        
        // Check if rectangles overlap or are within gap distance
        let horizontalOverlap = rect1.maxX >= rect2.minX - gap && rect2.maxX >= rect1.minX - gap
        let verticalOverlap = rect1.maxY >= rect2.minY - gap && rect2.maxY >= rect1.minY - gap
        
        return horizontalOverlap && verticalOverlap
    }
    
    /// Merges two overlapping or adjacent regions into a single region
    private static func mergeTwoRegions(_ rect1: CGRect, _ rect2: CGRect) -> CGRect {
        return CGRect(
            x: min(rect1.minX, rect2.minX),
            y: min(rect1.minY, rect2.minY),
            width: max(rect1.maxX, rect2.maxX) - min(rect1.minX, rect2.minX),
            height: max(rect1.maxY, rect2.maxY) - min(rect1.minY, rect2.minY)
        )
    }
}
