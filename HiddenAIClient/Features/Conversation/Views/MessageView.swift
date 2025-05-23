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
    @State private var isHovering = false
    @State private var showingDeleteConfirmation = false
    
    // Callback for message deletion
    var onDelete: ((Message) -> Void)?
    
    var body: some View {
        HStack {
            if message.type == .assistant {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.type == .user ? .leading : .trailing, spacing: 2) {
                VStack(alignment: message.type == .user ? .leading : .trailing, spacing: 8) {
                    ForEach(Array(message.contents.enumerated()), id: \.offset) { index, content in
                        switch content.type {
                        case .text:
                            Text(attributedString: MarkdownParser.parse(text: content.content))
                                .font(.system(size: 14, weight: .light))
                                .lineSpacing(4)
                                .padding(12)
                                .fixedSize(horizontal: false, vertical: true)
                                .background(
                                    message.type == .user ? 
                                        JetBrainsTheme.backgroundTertiary : 
                                        JetBrainsTheme.backgroundSecondary
                                )
                                .cornerRadius(2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(
                                            JetBrainsTheme.border.opacity(0.3),
                                            lineWidth: 0.5
                                        )
                                )
                                .textSelection(.enabled)
                        
                        case .code(let language):
                            VStack(alignment: .leading, spacing: 0) {
                                // Minimal code header
                                HStack {
                                    Text(language.uppercased())
                                        .font(.system(size: 11, weight: .light, design: .monospaced))
                                        .foregroundColor(JetBrainsTheme.textSecondary)
                                        .tracking(1)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        copyToClipboard(content.content)
                                        copiedIndex = index
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            copiedIndex = nil
                                        }
                                    }) {
                                        Text(copiedIndex == index ? "COPIED" : "COPY")
                                            .font(.system(size: 10, weight: .light, design: .monospaced))
                                            .foregroundColor(JetBrainsTheme.textSecondary)
                                            .tracking(1)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(JetBrainsTheme.backgroundPrimary)
                                
                                // Thin separator
                                Rectangle()
                                    .fill(JetBrainsTheme.border.opacity(0.3))
                                    .frame(height: 0.5)
                                
                                // Code content
                                ScrollView(.horizontal, showsIndicators: false) {
                                    Text(CodeHighlighter.highlightCode(content.content, language: language))
                                        .font(.system(size: 13, weight: .light, design: .monospaced))
                                        .lineSpacing(2)
                                        .padding(12)
                                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                }
                                .background(JetBrainsTheme.codeBackground)
                            }
                            .frame(maxWidth: 500, alignment: message.type == .user ? .leading : .trailing)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(JetBrainsTheme.border.opacity(0.3), lineWidth: 0.5)
                            )
                            .cornerRadius(2)
                        }
                    }
                }
                
                // Minimal timestamp
                Text(formattedTime(for: message.timestamp))
                    .font(.system(size: 10, weight: .light, design: .monospaced))
                    .foregroundColor(JetBrainsTheme.textSecondary.opacity(0.6))
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
            }
            
            if message.type == .user {
                Spacer(minLength: 60)
            }
        }
        .overlay(
            // Hover timestamp overlay
            VStack {
                HStack {
                    if message.type == .user {
                        Spacer()
                    }
                    
                    if isHovering {
                        Text(formattedTime(for: message.timestamp))
                            .font(.system(size: 11, weight: .light, design: .monospaced))
                            .foregroundColor(JetBrainsTheme.textSecondary.opacity(0.6))
                            .padding(4)
                            .background(JetBrainsTheme.backgroundSecondary.opacity(0.8))
                            .cornerRadius(2)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                    
                    if message.type == .assistant {
                        Spacer()
                    }
                }
                Spacer()
            }
            .animation(.easeInOut(duration: 0.2), value: isHovering)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            // Copy actions
            Button(action: {
                copyMessageContent()
            }) {
                Label("Copy Message", systemImage: "doc.on.doc")
            }
            
            Button(action: {
                copyRawContent()
            }) {
                Label("Copy as Plain Text", systemImage: "textformat")
            }
            
            Divider()
            
            // Message info
            Button(action: {
                showMessageInfo()
            }) {
                Label("Message Info", systemImage: "info.circle")
            }
            
            if message.type == .user {
                Divider()
                
                // Delete option (only for user messages to avoid confusion)
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete Message", systemImage: "trash")
                }
            }
        }
        .alert("Delete Message", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete?(message)
            }
        } message: {
            Text("Are you sure you want to delete this message? This action cannot be undone.")
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
    
    // MARK: - Enhanced Context Menu Actions
    
    private func copyRawContent() {
        let rawContent = message.contents.map { content in
            content.content // Just the raw text without markdown formatting
        }.joined(separator: "\n\n")
        
        copyToClipboard(rawContent)
    }
    
    private func showMessageInfo() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        
        let messageLength = message.contents.reduce(0) { total, content in
            total + content.content.count
        }
        
        let info = """
        Message ID: \(message.id.uuidString.prefix(8))...
        Type: \(message.type == .user ? "User" : "Assistant")
        Timestamp: \(formatter.string(from: message.timestamp))
        Content Length: \(messageLength) characters
        Content Parts: \(message.contents.count)
        """
        
        copyToClipboard(info)
        
        // Show a brief notification (we could enhance this with a proper toast)
        print("Message info copied to clipboard")
    }
}
