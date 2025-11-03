import Foundation

/// Detects potential passwords in text using pattern matching and context analysis
public enum PasswordDetector {
    
    /// Detects password-like strings in text
    /// - Parameter line: The text line to analyze
    /// - Returns: Array of Hit objects representing potential passwords
    public static func detect(in line: String) -> [Hit] {
        var hits: [Hit] = []
        
        // Password context keywords that typically appear before passwords
        let passwordKeywords = [
            "password", "pwd", "pass", "passcode", "passphrase",
            "secret", "key", "token", "api key", "access key",
            "credential", "auth", "authentication"
        ]
        
        // Check if line contains password-related keywords
        let lowercasedLine = line.lowercased()
        var hasPasswordContext = false
        for keyword in passwordKeywords {
            if lowercasedLine.contains(keyword) {
                hasPasswordContext = true
                break
            }
        }
        
        // If no password context, skip
        guard hasPasswordContext else {
            return hits
        }
        
        // Pattern 1: Detect strings after common separators (: = ->)
        let separatorPatterns = [
            ":\\s*([^\\s]+)",           // password: value
            "=\\s*([^\\s]+)",           // password=value
            "->\\s*([^\\s]+)",          // password -> value
            "is\\s+([^\\s]+)",          // password is value
        ]
        
        for pattern in separatorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                let matches = regex.matches(in: line, options: [], range: range)
                
                for match in matches {
                    // Get the captured group (the value after the separator)
                    if match.numberOfRanges > 1 {
                        let valueRange = match.range(at: 1)
                        if let textRange = Range(valueRange, in: line) {
                            let value = String(line[textRange])
                            
                            // Validate that it looks like a password
                            if looksLikePassword(value) {
                                hits.append(Hit(textRange: textRange, kind: .customTerm("Password")))
                            }
                        }
                    }
                }
            }
        }
        
        // Pattern 2: Detect quoted strings in password context
        let quotedPattern = "[\"']([^\"']{6,})[\"']"
        if let regex = try? NSRegularExpression(pattern: quotedPattern, options: []) {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: line, options: [], range: range)
            
            for match in matches {
                if match.numberOfRanges > 1 {
                    let valueRange = match.range(at: 1)
                    if let textRange = Range(valueRange, in: line) {
                        let value = String(line[textRange])
                        
                        // Validate that it looks like a password
                        if looksLikePassword(value) {
                            hits.append(Hit(textRange: textRange, kind: .customTerm("Password")))
                        }
                    }
                }
            }
        }
        
        // Pattern 3: API keys and tokens (long alphanumeric strings)
        if lowercasedLine.contains("api") || lowercasedLine.contains("token") || lowercasedLine.contains("key") {
            let apiKeyPattern = "\\b[A-Za-z0-9_\\-]{20,}\\b"
            if let regex = try? NSRegularExpression(pattern: apiKeyPattern, options: []) {
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                let matches = regex.matches(in: line, options: [], range: range)
                
                for match in matches {
                    if let textRange = Range(match.range, in: line) {
                        hits.append(Hit(textRange: textRange, kind: .customTerm("API Key")))
                    }
                }
            }
        }
        
        return deduplicateHits(hits)
    }
    
    /// Checks if a string looks like a password based on common characteristics
    private static func looksLikePassword(_ value: String) -> Bool {
        // Skip common non-password values
        let skipWords = ["true", "false", "yes", "no", "none", "null", "undefined", "example", "test"]
        if skipWords.contains(value.lowercased()) {
            return false
        }
        
        // Must be at least 6 characters
        guard value.count >= 6 else {
            return false
        }
        
        // Skip if it's a common word or looks like regular text
        if value.allSatisfy({ $0.isLetter }) && value.count < 20 {
            return false
        }
        
        // Passwords often have mixed characteristics
        let hasLetters = value.contains(where: { $0.isLetter })
        let hasNumbers = value.contains(where: { $0.isNumber })
        let hasSpecialChars = value.contains(where: { !$0.isLetter && !$0.isNumber })
        
        // At least 2 of 3 characteristics, or very long string
        let characteristicCount = [hasLetters, hasNumbers, hasSpecialChars].filter { $0 }.count
        return characteristicCount >= 2 || value.count >= 16
    }
    
    /// Deduplicates hits that cover the same text range
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

