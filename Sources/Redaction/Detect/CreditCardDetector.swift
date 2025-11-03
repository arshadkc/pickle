import Foundation

/// Detects credit card numbers in text using pattern matching and Luhn algorithm validation
public enum CreditCardDetector {
    
    /// Detects credit card numbers in text
    /// - Parameter line: The text line to analyze
    /// - Returns: Array of Hit objects representing detected credit card numbers
    public static func detect(in line: String) -> [Hit] {
        var hits: [Hit] = []
        
        // Pattern for credit card numbers (13-19 digits, with optional spaces or dashes)
        // Matches: 4242424242424242, 4242-4242-4242-4242, 4242 4242 4242 4242
        let patterns = [
            "\\b(?:\\d[ -]?){13,19}\\b",  // General pattern with optional separators
            "\\b\\d{13,19}\\b"             // Continuous digits
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }
            
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: line, options: [], range: range)
            
            for match in matches {
                guard let textRange = Range(match.range, in: line) else { continue }
                let matchedText = String(line[textRange])
                
                // Extract only digits
                let digits = matchedText.filter { $0.isNumber }
                
                // Validate using Luhn algorithm
                if isValidCreditCard(digits) {
                    hits.append(Hit(textRange: textRange, kind: .customTerm("Credit Card")))
                }
            }
        }
        
        return deduplicateHits(hits)
    }
    
    /// Validates a credit card number using the Luhn algorithm
    /// - Parameter cardNumber: String containing only digits
    /// - Returns: true if valid credit card number
    private static func isValidCreditCard(_ cardNumber: String) -> Bool {
        // Credit cards must be 13-19 digits
        guard cardNumber.count >= 13 && cardNumber.count <= 19 else {
            return false
        }
        
        // All characters must be digits
        guard cardNumber.allSatisfy({ $0.isNumber }) else {
            return false
        }
        
        // Apply Luhn algorithm
        return luhnCheck(cardNumber)
    }
    
    /// Performs Luhn algorithm check
    /// - Parameter cardNumber: String of digits
    /// - Returns: true if passes Luhn check
    private static func luhnCheck(_ cardNumber: String) -> Bool {
        var sum = 0
        let reversedDigits = cardNumber.reversed()
        
        for (index, character) in reversedDigits.enumerated() {
            guard let digit = character.wholeNumberValue else {
                return false
            }
            
            if index % 2 == 1 {
                // Double every second digit
                let doubled = digit * 2
                // If doubled value is > 9, add the digits together
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        
        // Valid if sum is divisible by 10
        return sum % 10 == 0
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

