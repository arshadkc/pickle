import Foundation
import NaturalLanguage

/// Represents a detected sensitive token with its location and type
public struct Hit {
    public let textRange: Range<String.Index>
    public let kind: Kind
    
    public init(textRange: Range<String.Index>, kind: Kind) {
        self.textRange = textRange
        self.kind = kind
    }
}

/// Types of sensitive content that can be detected
public enum Kind {
    case mention
    case channel
    case email
    case phone
    case url
    case personalName
    case organizationName
    case customTerm(String)
}

/// Detects potentially sensitive tokens in text using various detection methods
public enum SensitivityDetector {
    
    /// Detects all types of sensitive content in a line of text
    /// - Parameters:
    ///   - line: The text line to analyze
    ///   - customTerms: Array of custom terms to detect (case-insensitive, fuzzy matching)
    /// - Returns: Array of Hit objects representing detected sensitive content
    public static func detect(in line: String, customTerms: [String] = []) -> [Hit] {
        var hits: [Hit] = []
        
        // Detect mentions (@username)
        hits.append(contentsOf: detectMentions(in: line))
        
        // Detect channels (#channel-name)
        hits.append(contentsOf: detectChannels(in: line))
        
        // Detect emails, phones, and URLs using NSDataDetector
        hits.append(contentsOf: detectDataTypes(in: line))
        
        // Fallback regex-based email detection to catch formats NSDataDetector can miss
        hits.append(contentsOf: detectEmailsWithRegex(in: line))
        
        // Fallback numeric detector for digit-only sequences (e.g., loose phone numbers)
        hits.append(contentsOf: detectNumericSequences(in: line))
        
        // Detect personal and organization names using NLTagger
        // DISABLED: Causes false positives on common words like "Team", "Days"
        // hits.append(contentsOf: detectNames(in: line))
        
        // Detect custom terms with fuzzy matching
        hits.append(contentsOf: detectCustomTerms(in: line, customTerms: customTerms))
        
        // Deduplicate overlapping hits and sort hits by position in the text
        return deduplicateHits(hits).sorted { $0.textRange.lowerBound < $1.textRange.lowerBound }
    }
    
    // MARK: - Mention Detection
    
    /// Detects @mentions using regex pattern
    private static func detectMentions(in line: String) -> [Hit] {
        let pattern = "@[\\p{L}\\p{N}._-]+"
        return detectWithRegex(pattern: pattern, in: line, kind: .mention)
    }
    
    // MARK: - Channel Detection
    
    /// Detects #channels using regex pattern
    private static func detectChannels(in line: String) -> [Hit] {
        let pattern = "#[\\p{L}\\p{N}_-]+"
        return detectWithRegex(pattern: pattern, in: line, kind: .channel)
    }
    
    // MARK: - Data Type Detection (Email, Phone, URL)
    
    /// Detects emails, phone numbers, and URLs using NSDataDetector
    private static func detectDataTypes(in line: String) -> [Hit] {
        var hits: [Hit] = []
        
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue | NSTextCheckingResult.CheckingType.link.rawValue) else {
            return hits
        }
        
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = detector.matches(in: line, options: [], range: range)
        
        for match in matches {
            guard let textRange = Range(match.range, in: line) else { continue }
            
            let kind: Kind
            switch match.resultType {
            case .phoneNumber:
                kind = .phone
            case .link:
                // Check if it's a mailto: link (email) or regular URL
                if let url = match.url, url.scheme == "mailto" {
                    kind = .email
                } else {
                    kind = .url
                }
            default:
                continue
            }
            
            hits.append(Hit(textRange: textRange, kind: kind))
        }
        
        return hits
    }
    
    // MARK: - Email Regex Fallback

    /// Detects email addresses using regex as a fallback when NSDataDetector misses a pattern
    private static func detectEmailsWithRegex(in line: String) -> [Hit] {
        let pattern = "(?xi)[A-Z0-9._%+-]+\\s*@\\s*[A-Z0-9.-]+\\s*\\.[A-Z]{2,}"
        return detectWithRegex(pattern: pattern, in: line, kind: .email, options: [.caseInsensitive, .allowCommentsAndWhitespace])
    }

    // MARK: - Numeric Sequence Fallback

    /// Detects long digit sequences (7+ digits) that may represent phone numbers
    private static func detectNumericSequences(in line: String) -> [Hit] {
        let pattern = "(?<!\\d)\\d{7,}(?!\\d)"
        return detectWithRegex(pattern: pattern, in: line, kind: .phone)
    }

    // MARK: - Name Detection
    
    /// Detects personal and organization names using NLTagger
    private static func detectNames(in line: String) -> [Hit] {
        var hits: [Hit] = []
        
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = line
        
        let range = line.startIndex..<line.endIndex
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange in
            guard let tag = tag else { return true }
            
            let kind: Kind
            switch tag {
            case .personalName:
                kind = .personalName
            case .organizationName:
                kind = .organizationName
            default:
                return true
            }
            
            hits.append(Hit(textRange: tokenRange, kind: kind))
            return true
        }
        
        return hits
    }
    
    // MARK: - Custom Terms Detection
    
    /// Detects custom terms with fuzzy matching (edit distance ≤ 1)
    private static func detectCustomTerms(in line: String, customTerms: [String]) -> [Hit] {
        var hits: [Hit] = []
        
        for customTerm in customTerms {
            let lowercasedLine = line.lowercased()
            let lowercasedTerm = customTerm.lowercased()
            
            // First try exact match (case-insensitive)
            if let range = lowercasedLine.range(of: lowercasedTerm) {
                hits.append(Hit(textRange: range, kind: .customTerm(customTerm)))
                continue
            }
            
            // Then try fuzzy matching with edit distance ≤ 1
            let fuzzyMatches = findFuzzyMatches(term: lowercasedTerm, in: lowercasedLine, maxDistance: 1)
            for match in fuzzyMatches {
                hits.append(Hit(textRange: match, kind: .customTerm(customTerm)))
            }
        }
        
        return hits
    }
    
    /// Finds fuzzy matches of a term in text with maximum edit distance
    private static func findFuzzyMatches(term: String, in text: String, maxDistance: Int) -> [Range<String.Index>] {
        var matches: [Range<String.Index>] = []
        
        let termLength = term.count
        let textLength = text.count
        
        // Check each possible position
        for i in 0...(textLength - termLength) {
            let startIndex = text.index(text.startIndex, offsetBy: i)
            let endIndex = text.index(startIndex, offsetBy: termLength)
            let substring = String(text[startIndex..<endIndex])
            
            if editDistance(term, substring) <= maxDistance {
                matches.append(startIndex..<endIndex)
            }
        }
        
        return matches
    }
    
    /// Calculates edit distance between two strings using dynamic programming
    private static func editDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        // Initialize base cases
        for i in 0...m {
            dp[i][0] = i
        }
        for j in 0...n {
            dp[0][j] = j
        }
        
        // Fill the DP table
        for i in 1...m {
            for j in 1...n {
                if s1Array[i-1] == s2Array[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }
        
        return dp[m][n]
    }
    
    // MARK: - Helper Methods
    
    /// Detects patterns using regex and returns hits
    private static func detectWithRegex(pattern: String, in line: String, kind: Kind, options: NSRegularExpression.Options = []) -> [Hit] {
        var hits: [Hit] = []
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: line, options: [], range: range)
            
            for match in matches {
                guard let textRange = Range(match.range, in: line) else { continue }
                hits.append(Hit(textRange: textRange, kind: kind))
            }
        } catch {
            // If regex fails, return empty array
        }
        
        return hits
    }
    
    /// Deduplicates hits that cover the same text range, preserving the first occurrence.
    private static func deduplicateHits(_ hits: [Hit]) -> [Hit] {
        var unique: [Hit] = []
        for hit in hits {
            if unique.contains(where: { $0.textRange == hit.textRange }) {
                continue
            }
            unique.append(hit)
        }
        return unique
    }
}
