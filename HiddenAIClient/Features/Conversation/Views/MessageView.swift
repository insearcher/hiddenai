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
        .contextMenu {
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
