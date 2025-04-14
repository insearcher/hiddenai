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
                return Color(hex: "#CF8E6D") // Orange-brown for keywords
            case .string:
                return Color(hex: "#6AAB73") // Green for strings
            case .comment:
                return Color(hex: "#808080") // Gray for comments
            case .number:
                return Color(hex: "#6897BB") // Blue for numbers
            case .identifier:
                return Color(hex: "#A9B7C6") // Light gray for identifiers
            case .type:
                return Color(hex: "#B5B6E3") // Light purple for types
            case .operatorToken:
                return Color(hex: "#A9B7C6") // Light gray for operators
            case .defaultToken:
                return Color(hex: "#A9B7C6") // Default light gray
            }
        }
    }
    
    // Basic syntax highlighting for common languages
    static func highlightCode(_ code: String, language: String) -> AttributedString {
        var attributedString = AttributedString(code)
        
        // Simple patterns for common language constructs
        // These are simplified patterns - a full syntax highlighter would be more complex
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
            case "cpp", "c++":
                return [
                    // Keywords
                    ("\\b(class|struct|enum|namespace|template|typedef|const|static|virtual|override|if|else|for|while|do|switch|case|break|continue|return|try|catch|throw|new|delete|this|auto|using)\\b", .keyword),
                    // Strings
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    // Comments
                    ("//[^\n]*", .comment),
                    ("(/\\*)(.*?)(\\*/)", .comment),
                    // Numbers
                    ("\\b[0-9]+\\b", .number),
                    // Types
                    ("\\b(string|int|float|double|bool|char|void|size_t|nullptr|std|vector|map|set|array|unique_ptr|shared_ptr|weak_ptr)\\b", .type)
                ]
            case "c#", "csharp":
                return [
                    // Keywords
                    ("\\b(class|struct|enum|interface|namespace|using|public|private|protected|internal|static|readonly|const|virtual|override|abstract|sealed|if|else|for|foreach|while|do|switch|case|break|continue|return|try|catch|finally|throw|new|this|base|var|void|out|ref|params)\\b", .keyword),
                    // Strings
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    ("@\"[^\"]*(?:\"\"[^\"]*)*\"", .string),
                    // Comments
                    ("//[^\n]*", .comment),
                    ("(/\\*)(.*?)(\\*/)", .comment),
                    // Numbers
                    ("\\b[0-9]+\\b", .number),
                    // Types
                    ("\\b(string|int|float|double|decimal|bool|char|object|void|var|List|Dictionary|IEnumerable|Task|Action|Func)\\b", .type)
                ]
            case "ruby":
                return [
                    // Keywords
                    ("\\b(def|class|module|if|else|elsif|unless|case|when|while|until|for|begin|rescue|ensure|end|yield|return|break|next|redo|retry|super|self|nil|true|false|and|or|not|alias)\\b", .keyword),
                    // Strings
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    ("'[^'\\\\]*(\\\\.[^'\\\\]*)*'", .string),
                    // Comments
                    ("#[^\n]*", .comment),
                    // Numbers
                    ("\\b[0-9]+\\b", .number)
                ]
            case "go", "golang":
                return [
                    // Keywords
                    ("\\b(func|package|import|var|const|type|struct|interface|map|chan|if|else|for|range|switch|case|break|continue|return|go|defer|select|fallthrough)\\b", .keyword),
                    // Strings
                    ("`[^`]*`", .string),
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    // Comments
                    ("//[^\n]*", .comment),
                    ("(/\\*)(.*?)(\\*/)", .comment),
                    // Numbers
                    ("\\b[0-9]+\\b", .number),
                    // Types
                    ("\\b(string|int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64|bool|byte|rune|error|interface)\\b", .type)
                ]
            case "rust":
                return [
                    // Keywords
                    ("\\b(fn|let|mut|const|static|if|else|match|for|while|loop|break|continue|return|struct|enum|trait|impl|use|mod|pub|self|super|as|move|where|unsafe|async|await|dyn|type|extern)\\b", .keyword),
                    // Strings
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    // Comments
                    ("//[^\n]*", .comment),
                    ("(/\\*)(.*?)(\\*/)", .comment),
                    // Numbers
                    ("\\b[0-9]+\\b", .number),
                    // Types
                    ("\\b(String|i8|i16|i32|i64|i128|isize|u8|u16|u32|u64|u128|usize|f32|f64|bool|char|Option|Result|Vec|Box|Rc|Arc)\\b", .type)
                ]
            case "html":
                return [
                    // Tags
                    ("<[^>]+>", .keyword),
                    // Attributes
                    ("\\b([a-zA-Z\\-:]+)=", .type),
                    // Strings
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    ("'[^'\\\\]*(\\\\.[^'\\\\]*)*'", .string),
                    // Comments
                    ("<!--[\\s\\S]*?-->", .comment)
                ]
            case "css":
                return [
                    // Selectors
                    ("\\b([a-zA-Z\\-]+)\\s*\\{", .keyword),
                    // Properties
                    ("\\b([a-zA-Z\\-]+)\\s*:", .type),
                    // Values
                    (":\\s*([^;\\{]+);", .string),
                    // Colors
                    ("#[0-9a-fA-F]{3,6}", .number),
                    // Comments
                    ("/\\*[\\s\\S]*?\\*/", .comment)
                ]
            case "json":
                return [
                    // Keys
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"\\s*:", .keyword),
                    // Strings
                    (":\\s*\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    // Numbers
                    ("\\b[0-9]+\\.?[0-9]*\\b", .number),
                    // Booleans
                    ("\\b(true|false|null)\\b", .type)
                ]
            case "sql":
                return [
                    // Keywords
                    ("\\b(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE|AND|OR|NOT|ORDER BY|GROUP BY|HAVING|JOIN|LEFT|RIGHT|INNER|OUTER|UNION|CREATE|ALTER|DROP|TABLE|INDEX|VIEW|TRIGGER|PROCEDURE|FUNCTION|DATABASE|SCHEMA|GRANT|REVOKE|COMMIT|ROLLBACK|BEGIN|TRANSACTION)\\b", .keyword),
                    // Strings
                    ("'[^'\\\\]*(\\\\.[^'\\\\]*)*'", .string),
                    // Comments
                    ("--[^\n]*", .comment),
                    ("(/\\*)(.*?)(\\*/)", .comment),
                    // Numbers
                    ("\\b[0-9]+\\b", .number)
                ]
            case "xml":
                return [
                    // Tags
                    ("<[^>]+>", .keyword),
                    // Attributes
                    ("\\b([a-zA-Z\\-:]+)=", .type),
                    // Strings
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    ("'[^'\\\\]*(\\\\.[^'\\\\]*)*'", .string),
                    // Comments
                    ("<!--[\\s\\S]*?-->", .comment),
                    // CDATA
                    ("<!\\[CDATA\\[[\\s\\S]*?\\]\\]>", .string)
                ]
            case "bash", "shell", "sh":
                return [
                    // Keywords
                    ("\\b(if|then|else|elif|fi|for|do|done|while|until|case|esac|function|in|select|time|exec|command|source)\\b", .keyword),
                    // Variables
                    ("\\$\\{?[a-zA-Z0-9_]+\\}?", .identifier),
                    // Strings
                    ("\"[^\"\\\\]*(\\\\.[^\"\\\\]*)*\"", .string),
                    ("'[^'\\\\]*(\\\\.[^'\\\\]*)*'", .string),
                    // Commands
                    ("\\b(echo|cd|pwd|ls|cat|grep|find|sed|awk|mkdir|rm|cp|mv|chmod|chown|touch|exit|return|export|source|alias)\\b", .type),
                    // Comments
                    ("#[^\n]*", .comment)
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
                            
                            // Apply font traits based on token type
                            if tokenType == .keyword || tokenType == .type {
                                attributedString[range].font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
                            } else {
                                attributedString[range].font = .monospacedSystemFont(ofSize: 13, weight: .regular)
                            }
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
