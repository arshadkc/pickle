import Foundation
import NaturalLanguage

// MARK: - Date/Time Guard System

/// Precompiled regex patterns for fast date/time detection
enum DateGuards {
    // e.g., 2025-10-28 or 28-10-2025 / separators: - / .
    static let ymd = try! NSRegularExpression(pattern: #"(?<!\d)(?:19|20)\d{2}[-/.](?:0?[1-9]|1[0-2])[-/.](?:0?[1-9]|[12]\d|3[01])(?!\d)"#)
    static let dmy = try! NSRegularExpression(pattern: #"(?<!\d)(?:0?[1-9]|[12]\d|3[01])[-/.](?:0?[1-9]|1[0-2])[-/.](?:19|20)\d{2}(?!\d)"#)
    static let mdy = try! NSRegularExpression(pattern: #"(?<!\d)(?:0?[1-9]|1[0-2])[-/.](?:0?[1-9]|[12]\d|3[01])[-/.](?:19|20)\d{2}(?!\d)"#)
    static let compactYMD = try! NSRegularExpression(pattern: #"(?<!\d)(?:19|20)\d{6}(?!\d)"#) // YYYYMMDD
    static let time = try! NSRegularExpression(pattern: #"(?<!\d)(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?(?:\s?(?:AM|PM))?(?!\d)"#, options: [.caseInsensitive])
    static let iso8601 = try! NSRegularExpression(pattern: #"(?:19|20)\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+\-]\d{2}:\d{2})"#)
    static let monthWords = try! NSRegularExpression(pattern: #"(?:\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec|January|February|March|April|June|July|August|September|October|November|December)\b\.?,?\s+\d{1,2}(?:st|nd|rd|th)?(?:,?\s+(?:19|20)\d{2})?)|(?:\b\d{1,2}(?:st|nd|rd|th)?\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec|January|February|March|April|June|July|August|September|October|November|December)\b\.?,?\s+(?:19|20)\d{2})"#, options: [.caseInsensitive])
}

/// Fast helper to check if a string looks like a date or time
func looksLikeDateOrTime(_ s: String) -> Bool {
    let range = NSRange(s.startIndex..<s.endIndex, in: s)
    if DateGuards.ymd.firstMatch(in: s, options: [], range: range) != nil { return true }
    if DateGuards.dmy.firstMatch(in: s, options: [], range: range) != nil { return true }
    if DateGuards.mdy.firstMatch(in: s, options: [], range: range) != nil { return true }
    if DateGuards.compactYMD.firstMatch(in: s, options: [], range: range) != nil { return true }
    if DateGuards.iso8601.firstMatch(in: s, options: [], range: range) != nil { return true }
    if DateGuards.time.firstMatch(in: s, options: [], range: range) != nil { return true }
    if DateGuards.monthWords.firstMatch(in: s, options: [], range: range) != nil { return true }
    return false
}

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
    case address
    case transit
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
        
        // Fallback regex-based URL detection to catch URLs without protocols
        hits.append(contentsOf: detectURLsWithRegex(in: line))
        
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
        
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue | NSTextCheckingResult.CheckingType.link.rawValue | NSTextCheckingResult.CheckingType.address.rawValue | NSTextCheckingResult.CheckingType.transitInformation.rawValue) else {
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
            case .address:
                kind = .address
            case .transitInformation:
                kind = .transit
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
    
    /// Detects URLs using regex as a fallback when NSDataDetector misses URLs without protocols
    private static func detectURLsWithRegex(in line: String) -> [Hit] {
        var hits: [Hit] = []
        
        // First try the standard pattern for clean URLs with protocols
        let protocolPattern = "(?xi)https?://[a-z0-9][a-z0-9-]{0,61}[a-z0-9]\\.[a-z]{2,}(?:/[^\\s]*)?"
        hits.append(contentsOf: detectWithRegex(pattern: protocolPattern, in: line, kind: .url, options: [.caseInsensitive]))
        
        // Then try the standard pattern for clean URLs without protocols
        let standardPattern = "(?xi)(?:www\\.)?[a-z0-9][a-z0-9-]{0,61}[a-z0-9]\\.[a-z]{2,}(?:/[^\\s]*)?"
        hits.append(contentsOf: detectWithRegex(pattern: standardPattern, in: line, kind: .url, options: [.caseInsensitive]))
        
        // Handle OCR concatenation issues where URLs are merged with other text
        // Simple approach: redact everything that starts with a domain pattern until whitespace/punctuation
        // This will catch cases like "docs.stripe.comltesting" and redact the entire string
        let ocrPattern = "(?xi)(?:www\\.)?[a-z0-9][a-z0-9-]{0,61}[a-z0-9]\\.[a-z]{2,}[a-z0-9]+"
        let ocrHits = detectWithRegex(pattern: ocrPattern, in: line, kind: .url, options: [.caseInsensitive])
        
        // Only add OCR hits if they don't overlap with existing hits
        for ocrHit in ocrHits {
            let hasOverlap = hits.contains { existingHit in
                existingHit.textRange.overlaps(ocrHit.textRange)
            }
            if !hasOverlap {
                hits.append(ocrHit)
            }
        }
        
        return hits
    }

    // MARK: - Numeric Sequence Fallback

    /// Detects long digit sequences (7+ digits) that may represent phone numbers
    /// Excludes common date patterns using comprehensive date guard
    private static func detectNumericSequences(in line: String) -> [Hit] {
        var hits: [Hit] = []
        
        // First, find all 7+ digit sequences
        let allSequencesPattern = "(?<!\\d)\\d{7,}(?!\\d)"
        let allMatches = detectWithRegex(pattern: allSequencesPattern, in: line, kind: .customTerm("Long Numeric ID"))
        
        for hit in allMatches {
            let text = String(line[hit.textRange])
            
            // Apply comprehensive date guard - skip if it looks like any date/time format
            if looksLikeDateOrTime(text) {
                continue
            }
            
            // Additional numeric heuristics for pure digit tokens
            if text.allSatisfy({ $0.isNumber }) {
                // If length == 8 and matches YYYYMMDD in a valid range → skip
                if text.count == 8 && isLikelyYYYYMMDD(text) {
                    continue
                }
                
                // Check if token is near date/time context words
                if isNearDateContext(text, in: line, range: hit.textRange) {
                    continue
                }
            }
            hits.append(hit)
        }
        
        return hits
    }
    
    /// Checks if an 8-digit string looks like a date in DDMMYYYY or DDMMYYY format
    private static func isLikelyDate(_ text: String) -> Bool {
        guard text.count == 8 else { return false }
        
        let day = Int(String(text.prefix(2))) ?? 0
        let month = Int(String(text.dropFirst(2).prefix(2))) ?? 0
        let year = Int(String(text.suffix(4))) ?? 0
        let year3 = Int(String(text.suffix(3))) ?? 0
        
        // Check DDMMYYYY format (4-digit year)
        if year >= 1900 && year <= 2100 {
            return day >= 1 && day <= 31 && month >= 1 && month <= 12
        }
        
        // Check DDMMYYY format (3-digit year)
        if year3 >= 100 && year3 <= 999 {
            return day >= 1 && day <= 31 && month >= 1 && month <= 12
        }
        
        return false
    }
    
    /// Checks if a 7-digit string looks like a date in DDMMYYY format
    private static func isLikelyShortDate(_ text: String) -> Bool {
        guard text.count == 7, let day = Int(String(text.prefix(2))),
              let month = Int(String(text.dropFirst(2).prefix(2))),
              let year = Int(String(text.suffix(3))) else {
            return false
        }
        
        // Basic validation: day 1-31, month 1-12, year 100-999
        return day >= 1 && day <= 31 && month >= 1 && month <= 12 && year >= 100 && year <= 999
    }
    
    /// Checks if an 8-digit string looks like YYYYMMDD format
    private static func isLikelyYYYYMMDD(_ text: String) -> Bool {
        guard text.count == 8 else { return false }
        
        let year = Int(String(text.prefix(4))) ?? 0
        let month = Int(String(text.dropFirst(4).prefix(2))) ?? 0
        let day = Int(String(text.suffix(2))) ?? 0
        
        return year >= 1900 && year <= 2100 && month >= 1 && month <= 12 && day >= 1 && day <= 31
    }
    
    /// Checks if a numeric token is near date/time context words
    private static func isNearDateContext(_ text: String, in line: String, range: Range<String.Index>) -> Bool {
        // For now, skip context checking to avoid string index issues
        // This is a simplified version that just checks the entire line
        let lineLowercased = line.lowercased()
        
        // Check for date/time context words in the entire line
        let dateContextWords = [
            "mon", "tue", "wed", "thu", "fri", "sat", "sun",
            "am", "pm", "utc", "ist", "gmt", "pst", "est",
            "jan", "feb", "mar", "apr", "may", "jun",
            "jul", "aug", "sep", "oct", "nov", "dec",
            "january", "february", "march", "april", "june",
            "july", "august", "september", "october", "november", "december",
            "today", "yesterday", "tomorrow", "date", "time"
        ]
        
        // Only check for date context if the line is relatively short (single line)
        // This prevents false positives when processing multi-line text
        if line.count > 100 {
            return false
        }
        
        let foundContextWord = dateContextWords.first { lineLowercased.contains($0) }
        return foundContextWord != nil
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
