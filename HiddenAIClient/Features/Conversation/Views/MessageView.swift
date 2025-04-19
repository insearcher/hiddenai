//
//  MessageView.swift
//  HiddenAIClient
//
//  Created on 4/20/25.
//

import SwiftUI
import AppKit

/// View for displaying a single message in the conversation
struct MessageView: View {
    let message: Message
    @State private var copiedIndex: Int? = nil
    
    var body: some View {
        HStack {
            if message.type == .assistant {
                Spacer(minLength: 30)
            }
            
            VStack(alignment: message.type == .user ? .leading : .trailing, spacing: 4) {
                VStack(alignment: message.type == .user ? .leading : .trailing, spacing: 10) { // Increased spacing between blocks in a message
                    ForEach(Array(message.contents.enumerated()), id: \.offset) { index, content in
                        switch content.type {
                        case .text:
                            Text(attributedString: MarkdownParser.parse(text: content.content))
                                .font(.system(size: 14))
                                .padding(10)
                                .fixedSize(horizontal: false, vertical: true) // Proper wrapping
                                .background(message.type == .user ? JetBrainsTheme.userMessage : JetBrainsTheme.assistantMessage)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            message.type == .user ? 
                                                JetBrainsTheme.accentPrimary.opacity(0.3) : 
                                                JetBrainsTheme.accentSecondary.opacity(0.3),
                                            lineWidth: 1
                                        )
                                )
                                .textSelection(.enabled) // Enable text selection
                        
                        case .code(let language):
                            VStack(alignment: .leading, spacing: 0) {
                                // Code header with language label and copy button
                                HStack {
                                    Text(language)
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 8) // Reduced padding
                                        .padding(.vertical, 3)   // Reduced padding
                                        .foregroundColor(JetBrainsTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        copyToClipboard(content.content)
                                        copiedIndex = index
                                        
                                        // Reset "Copied" text after 2 seconds
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            copiedIndex = nil
                                        }
                                    }) {
                                        HStack(spacing: 3) { // Reduced spacing
                                            Image(systemName: copiedIndex == index ? "checkmark" : "doc.on.doc")
                                                .font(.system(size: 11)) // Smaller icon
                                            
                                            Text(copiedIndex == index ? "Copied!" : "Copy")
                                                .font(.system(size: 11)) // Smaller text
                                        }
                                        .foregroundColor(JetBrainsTheme.textPrimary)
                                        .padding(.horizontal, 6) // Reduced padding
                                        .padding(.vertical, 3)   // Reduced padding
                                        .background(JetBrainsTheme.backgroundTertiary)
                                        .cornerRadius(4)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                .padding(.horizontal, 8) // Reduced padding
                                .padding(.vertical, 4)   // Reduced padding
                                .background(JetBrainsTheme.backgroundSecondary)
                                .clipShape(RoundedCorner(radius: 6, corners: [.topLeft, .topRight]))
                                
                                // Code content with syntax highlighting
                                ScrollView(.horizontal, showsIndicators: false) {
                                    Text(CodeHighlighter.highlightCode(content.content, language: language))
                                        .font(.system(size: 13, design: .monospaced))
                                        .lineSpacing(1) // Reduced line spacing
                                        .padding(8)      // Reduced padding
                                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                }
                                .background(JetBrainsTheme.codeBackground)
                                .clipShape(RoundedCorner(radius: 6, corners: [.bottomLeft, .bottomRight]))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(JetBrainsTheme.border, lineWidth: 1)
                                        .clipShape(RoundedCorner(radius: 6, corners: [.bottomLeft, .bottomRight]))
                                )
                            }
                            .frame(maxWidth: 500, alignment: message.type == .user ? .leading : .trailing)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(JetBrainsTheme.border, lineWidth: 1)
                            )
                            // Regular spacing between content blocks
                            .padding(.bottom, 2)
                        }
                    }
                }
                
                Text(formattedTime(for: message.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(JetBrainsTheme.textSecondary)
                    .padding(.horizontal, 5)
            }
            
            if message.type == .user {
                Spacer(minLength: 30)
            }
        }
        .contextMenu {
            // Add copy button for the entire message
            Button(action: {
                copyMessageContent()
            }) {
                Label("Copy Message", systemImage: "doc.on.doc")
            }
        }
    }
    
    private func formattedTime(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func copyMessageContent() {
        // Combine all content parts into a single string
        let fullText = message.contents.map { content -> String in
            switch content.type {
            case .text:
                return content.content
            case .code(let language):
                return "```\(language)\n\(content.content)\n```"
            }
        }.joined(separator: "\n\n")
        
        copyToClipboard(fullText)
    }
}
