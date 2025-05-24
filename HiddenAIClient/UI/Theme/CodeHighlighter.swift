//
//  CodeHighlighter.swift
//  HiddenWindowMCP
//
//  Created for HiddenWindowMCP project
//

import SwiftUI
import AppKit

class CodeHighlighter {
    // Define common language tokens for syntax highlighting
    enum TokenType {
        case keyword
        case string
        case comment
        case number
        case identifier
        case type
        case operatorToken
        case defaultToken
        
        var color: Color {
            switch self {
            case .keyword:
                return Color(hex: "#9B9B9B") // Muted gray for keywords
            case .string:
                return Color(hex: "#7D8471") // Muted green for strings
            case .comment:
                return Color(hex: "#5A5A5A") // Dark gray for comments
            case .number:
                return Color(hex: "#7A8A99") // Muted blue for numbers
            case .identifier:
                return Color(hex: "#B0B0B0") // Light gray for identifiers
            case .type:
                return Color(hex: "#8B8B8B") // Medium gray for types
            case .operatorToken:
                return Color(hex: "#808080") // Gray for operators
            case .defaultToken:
                return Color(hex: "#A0A0A0") // Default gray
            }
        }
    }
    
    // Basic syntax highlighting for common languages
    static func highlightCode(_ code: String, language: String) -> AttributedString {
        var attributedString = AttributedString(code)
        
        // Simple patterns for common language constructs
        let patterns: [(pattern: String, tokenType: TokenType)] = {
            switch language.lowercased() {
            case "swift":
                return [
                    // Keywords
                    ("\\b(class|struct|enum|func|var|let|if|else|guard|switch|case|for|while|do|try|catch|return|import|public|private|internal|fileprivate|open|static|self|throw|throws|rethrows|async|await|defer)\\b", .keyword),
                    // Strings
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    // Comments
                    ("//[^\n]*", .comment),
                    ("(/\\*)(.*?)(\\*/)", .comment),
                    // Numbers
                    ("\\b[0-9]+\\b", .number),
                    // Types
                    ("\\b(String|Int|Double|Float|Bool|Character|Array|Dictionary|Set|Optional|Result)\\b", .type)
                ]
            case "python":
                return [
                    // Keywords
                    ("\\b(def|class|if|else|elif|for|while|try|except|finally|with|import|from|as|return|break|continue|pass|lambda|yield|global|nonlocal|assert|del|raise|in|is|not|and|or)\\b", .keyword),
                    // Strings
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    ("'[^'\\\\]*(\\\\.[^'\\\\]*)*'", .string),
                    // Comments
                    ("#[^\n]*", .comment),
                    // Numbers
                    ("\\b[0-9]+\\b", .number),
                    // Types
                    ("\\b(str|int|float|bool|list|dict|set|tuple)\\b", .type)
                ]
            case "javascript", "js", "typescript", "ts":
                return [
                    // Keywords
                    ("\\b(var|let|const|function|class|if|else|for|while|do|switch|case|try|catch|finally|return|break|continue|import|export|async|await|of|in|instanceof|typeof|new|this|delete)\\b", .keyword),
                    // Strings
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    ("'[^'\\\\]*(\\\\.[^'\\\\]*)*'", .string),
                    ("`[^`\\\\]*(\\\\.[^`\\\\]*)*`", .string),
                    // Comments
                    ("//[^\n]*", .comment),
                    ("(/\\*)(.*?)(\\*/)", .comment),
                    // Numbers
                    ("\\b[0-9]+\\b", .number),
                    // Types
                    ("\\b(string|number|boolean|any|void|undefined|null|object|array)\\b", .type)
                ]
            case "java":
                return [
                    // Keywords
                    ("\\b(class|interface|enum|public|private|protected|static|final|abstract|synchronized|volatile|transient|native|strictfp|if|else|for|while|do|switch|case|break|continue|return|try|catch|finally|throw|throws|new|this|super|extends|implements|import|package|instanceof)\\b", .keyword),
                    // Strings
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    // Comments
                    ("//[^\n]*", .comment),
                    ("(/\\*)(.*?)(\\*/)", .comment),
                    // Numbers
                    ("\\b[0-9]+\\b", .number),
                    // Types
                    ("\\b(String|Integer|Double|Float|Boolean|Character|Object|List|Map|Set|Array|void|int|double|float|boolean|char|byte|short|long)\\b", .type)
                ]
            default:
                // Generic code highlighting for unknown languages
                return [
                    // Common keywords across languages
                    ("\\b(if|else|for|while|return|function|class|var|let|const|import|export|public|private|protected|static|void|true|false|null|undefined)\\b", .keyword),
                    // Strings
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    ("'[^'\\\\]*(\\\\.[^'\\\\]*)*'", .string),
                    // Comments
                    ("//[^\n]*", .comment),
                    ("(/\\*)(.*?)(\\*/)", .comment),
                    ("#[^\n]*", .comment),
                    // Numbers
                    ("\\b[0-9]+\\.?[0-9]*\\b", .number)
                ]
            }
        }()
        
        // Apply highlighting patterns
        for (pattern, tokenType) in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: code.utf16.count)
                let matches = regex.matches(in: code, options: [], range: range)
                
                for match in matches.reversed() {
                    // Convert NSRange to Range<String.Index>
                    if let stringRange = Range(match.range, in: code) {
                        let nsStringCode = code as NSString
                        let matchedText = nsStringCode.substring(with: match.range)
                        
                        // Calculate range in AttributedString
                        if let startIndex = attributedString.characters.index(attributedString.startIndex, offsetBy: stringRange.lowerBound.utf16Offset(in: code), limitedBy: attributedString.endIndex),
                           let endIndex = attributedString.characters.index(attributedString.startIndex, offsetBy: stringRange.upperBound.utf16Offset(in: code), limitedBy: attributedString.endIndex) {
                            
                            let range = startIndex..<endIndex
                            
                            // Apply foreground color
                            attributedString[range].foregroundColor = tokenType.color
                            
                            // Apply font based on token type (all light weight for austere look)
                            attributedString[range].font = .monospacedSystemFont(ofSize: 13, weight: .light)
                        }
                    }
                }
            } catch {
                print("Error applying regex for syntax highlighting: \(error)")
            }
        }
        
        return attributedString
    }
}
