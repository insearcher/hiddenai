//
//  MarkdownParser.swift
//  HiddenAIClient
//
//  Created by Maxim Frolov on 4/19/25.
//

import SwiftUI
import AppKit

struct MarkdownParser {
    // MARK: - Markdown Parsing
    
    static func parse(text: String) -> AttributedString {
        // Create base attributed string with system font
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: attributedString.length)
        
        // Apply base styling
        let font = NSFont.systemFont(ofSize: 14)
        attributedString.addAttribute(.font, value: font, range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: NSColor.white, range: fullRange)
        
        // Apply styling for each Markdown element
        processBoldText(in: attributedString)
        processItalicText(in: attributedString)
        processInlineCode(in: attributedString)
        processHeadings(in: attributedString)
        processBulletLists(in: attributedString)
        processNumberedLists(in: attributedString)
        processHyperlinks(in: attributedString)
        
        // Convert to AttributedString for SwiftUI
        return AttributedString(attributedString)
    }
    
    // MARK: - Styling Methods
    
    private static func processBoldText(in attrString: NSMutableAttributedString) {
        // Match text between ** or __
        let boldPatterns = ["\\*\\*(.*?)\\*\\*", "__(.*?)__"]
        
        for pattern in boldPatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let fullRange = NSRange(location: 0, length: attrString.length)
            
            let matches = regex?.matches(in: attrString.string, options: [], range: fullRange) ?? []
            
            // Process matches in reverse to avoid range issues
            for match in matches.reversed() {
                guard match.numberOfRanges >= 2 else { continue }
                
                let wholeRange = match.range
                let contentRange = match.range(at: 1)
                
                // Extract and replace with bold text
                let contentText = (attrString.string as NSString).substring(with: contentRange)
                let boldText = NSMutableAttributedString(string: contentText)
                
                // Apply bold font
                let boldFont = NSFont.boldSystemFont(ofSize: 14)
                boldText.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: boldText.length))
                
                // Replace in the original string
                attrString.replaceCharacters(in: wholeRange, with: boldText)
            }
        }
    }
    
    private static func processItalicText(in attrString: NSMutableAttributedString) {
        // Match text between * or _
        let italicPatterns = ["(?<![*_])\\*((?!\\*).*?)\\*(?![*])", "(?<![*_])_((?!_).*?)_(?![_])"]
        
        for pattern in italicPatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let fullRange = NSRange(location: 0, length: attrString.length)
            
            let matches = regex?.matches(in: attrString.string, options: [], range: fullRange) ?? []
            
            // Process matches in reverse to avoid range issues
            for match in matches.reversed() {
                guard match.numberOfRanges >= 2 else { continue }
                
                let wholeRange = match.range
                let contentRange = match.range(at: 1)
                
                // Extract and replace with italic text
                let contentText = (attrString.string as NSString).substring(with: contentRange)
                let italicText = NSMutableAttributedString(string: contentText)
                
                // Apply italic font
                let italicFont = NSFont.systemFont(ofSize: 14).withItalicTrait()
                italicText.addAttribute(.font, value: italicFont, range: NSRange(location: 0, length: italicText.length))
                
                // Replace in the original string
                attrString.replaceCharacters(in: wholeRange, with: italicText)
            }
        }
    }
    
    private static func processInlineCode(in attrString: NSMutableAttributedString) {
        // Match text between backticks
        let pattern = "`([^`]+)`"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        let fullRange = NSRange(location: 0, length: attrString.length)
        let matches = regex?.matches(in: attrString.string, options: [], range: fullRange) ?? []
        
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }
            
            let wholeRange = match.range
            let contentRange = match.range(at: 1)
            
            // Extract and replace with code-styled text
            let contentText = (attrString.string as NSString).substring(with: contentRange)
            let codeText = NSMutableAttributedString(string: contentText)
            
            // Apply monospaced font and styling
            let codeFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            codeText.addAttribute(.font, value: codeFont, range: NSRange(location: 0, length: codeText.length))
            
            // Use a slightly different color
            codeText.addAttribute(.foregroundColor, value: NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0), range: NSRange(location: 0, length: codeText.length))
            
            // Add light background
            codeText.addAttribute(.backgroundColor, value: NSColor(white: 0.2, alpha: 0.5), range: NSRange(location: 0, length: codeText.length))
            
            // Replace in the original string
            attrString.replaceCharacters(in: wholeRange, with: codeText)
        }
    }
    
    private static func processHeadings(in attrString: NSMutableAttributedString) {
        // Match # heading lines
        let pattern = "^(#{1,6})\\s+(.+)$"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        
        let fullRange = NSRange(location: 0, length: attrString.length)
        let matches = regex?.matches(in: attrString.string, options: [], range: fullRange) ?? []
        
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }
            
            let wholeRange = match.range
            let hashRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            
            // Get heading level from number of # symbols
            let hashCount = hashRange.length
            
            // Extract and replace with styled heading
            let contentText = (attrString.string as NSString).substring(with: contentRange)
            let headingText = NSMutableAttributedString(string: contentText)
            
            // Choose size and weight based on heading level
            let fontSize: CGFloat
            let fontWeight: NSFont.Weight
            
            switch hashCount {
            case 1: fontSize = 24; fontWeight = .bold
            case 2: fontSize = 22; fontWeight = .bold
            case 3: fontSize = 20; fontWeight = .bold
            case 4: fontSize = 18; fontWeight = .semibold
            case 5: fontSize = 16; fontWeight = .semibold
            default: fontSize = 15; fontWeight = .semibold
            }
            
            let headingFont = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
            headingText.addAttribute(.font, value: headingFont, range: NSRange(location: 0, length: headingText.length))
            
            // Add a bit of extra space after headings
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 8
            headingText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: headingText.length))
            
            // Replace in the original string
            attrString.replaceCharacters(in: wholeRange, with: headingText)
        }
    }
    
    private static func processBulletLists(in attrString: NSMutableAttributedString) {
        // Match bullet list items (- or *)
        let pattern = "^[\\s]*([-*])\\s+(.+)$"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        
        let fullRange = NSRange(location: 0, length: attrString.length)
        let matches = regex?.matches(in: attrString.string, options: [], range: fullRange) ?? []
        
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }
            
            let wholeRange = match.range
            let contentRange = match.range(at: 2)
            
            // Extract content
            let contentText = (attrString.string as NSString).substring(with: contentRange)
            
            // Create bullet point item
            let bulletItem = NSMutableAttributedString(string: "• ")
            
            // Style the bullet itself
            bulletItem.addAttribute(.foregroundColor, value: NSColor.lightGray, range: NSRange(location: 0, length: bulletItem.length))
            
            // Add the content text
            let contentItem = NSMutableAttributedString(string: contentText)
            
            // Copy formatting from original text
            attrString.enumerateAttributes(in: contentRange, options: []) { (attrs, range, _) in
                let localRange = NSRange(location: range.location - contentRange.location, length: range.length)
                if localRange.location + localRange.length <= contentItem.length {
                    for (key, value) in attrs {
                        contentItem.addAttribute(key, value: value, range: localRange)
                    }
                }
            }
            
            bulletItem.append(contentItem)
            
            // Add indentation
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 15
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.paragraphSpacing = 4
            bulletItem.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: bulletItem.length))
            
            // Replace in the original string
            attrString.replaceCharacters(in: wholeRange, with: bulletItem)
        }
    }
    
    private static func processNumberedLists(in attrString: NSMutableAttributedString) {
        // Match numbered list items (1., 2., etc.)
        let pattern = "^[\\s]*(\\d+)\\.\\s+(.+)$"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        
        let fullRange = NSRange(location: 0, length: attrString.length)
        let matches = regex?.matches(in: attrString.string, options: [], range: fullRange) ?? []
        
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }
            
            let wholeRange = match.range
            let numberRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            
            // Extract content and number
            let number = (attrString.string as NSString).substring(with: numberRange)
            let contentText = (attrString.string as NSString).substring(with: contentRange)
            
            // Create numbered item
            let numberedItem = NSMutableAttributedString(string: "\(number). ")
            
            // Style the number
            numberedItem.addAttribute(.foregroundColor, value: NSColor.lightGray, range: NSRange(location: 0, length: numberedItem.length))
            
            // Add the content text
            let contentItem = NSMutableAttributedString(string: contentText)
            
            // Copy formatting from original text
            attrString.enumerateAttributes(in: contentRange, options: []) { (attrs, range, _) in
                let localRange = NSRange(location: range.location - contentRange.location, length: range.length)
                if localRange.location + localRange.length <= contentItem.length {
                    for (key, value) in attrs {
                        contentItem.addAttribute(key, value: value, range: localRange)
                    }
                }
            }
            
            numberedItem.append(contentItem)
            
            // Add indentation
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 20
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.paragraphSpacing = 4
            numberedItem.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: numberedItem.length))
            
            // Replace in the original string
            attrString.replaceCharacters(in: wholeRange, with: numberedItem)
        }
    }
    
    private static func processHyperlinks(in attrString: NSMutableAttributedString) {
        // Match [text](url) links
        let pattern = "\\[(.*?)\\]\\((.*?)\\)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        let fullRange = NSRange(location: 0, length: attrString.length)
        let matches = regex?.matches(in: attrString.string, options: [], range: fullRange) ?? []
        
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }
            
            let wholeRange = match.range
            let textRange = match.range(at: 1)
            let urlRange = match.range(at: 2)
            
            // Extract link text and URL
            let linkText = (attrString.string as NSString).substring(with: textRange)
            let urlString = (attrString.string as NSString).substring(with: urlRange)
            
            // Create hyperlink text
            let linkItem = NSMutableAttributedString(string: linkText)
            
            // Style as link
            linkItem.addAttribute(.foregroundColor, value: NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0), range: NSRange(location: 0, length: linkItem.length))
            linkItem.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: linkItem.length))
            
            // Add link URL if valid
            if let url = URL(string: urlString) {
                linkItem.addAttribute(.link, value: url, range: NSRange(location: 0, length: linkItem.length))
            }
            
            // Replace in the original string
            attrString.replaceCharacters(in: wholeRange, with: linkItem)
        }
    }
}

// MARK: - Helper Extensions

extension NSFont {
    func withItalicTrait() -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: 0) ?? self
    }
}

// Extension to support AttributedString in Text view
extension Text {
    init(attributedString: AttributedString) {
        self = Text(attributedString)
    }
}
