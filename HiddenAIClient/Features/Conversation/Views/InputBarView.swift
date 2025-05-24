//
//  InputBarView.swift
//  HiddenAIClient
//
//  Created on 4/20/25.
//

import SwiftUI

/// View for the message input bar at the bottom of the conversation
struct InputBarView: View {
    @ObservedObject var viewModel: ConversationViewModel
    @FocusState var isInputFocused: Bool
    @State private var isHoveringOverSend = false
    @State private var isDragTargetActive = false
    
    var body: some View {
        VStack(spacing: 8) {
            // API key warning if needed - minimal style
            if !viewModel.apiKeyIsSet {
                Text("API KEY NOT CONFIGURED")
                    .font(.system(size: 11, weight: .light, design: .monospaced))
                    .foregroundColor(JetBrainsTheme.warning.opacity(0.8))
                    .tracking(1)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(JetBrainsTheme.warning.opacity(0.1))
                    .cornerRadius(2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(JetBrainsTheme.warning.opacity(0.3), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 20)
            }
            
            // Minimal text input field and send button
            HStack(spacing: 12) {
                TextField("", text: $viewModel.inputText, prompt: Text(promptText)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(JetBrainsTheme.textSecondary.opacity(0.6)))
                    .font(.system(size: 14, weight: .light))
                    .padding(12)
                    .background(isDragTargetActive ? JetBrainsTheme.accentPrimary.opacity(0.1) : JetBrainsTheme.backgroundTertiary)
                    .cornerRadius(2)
                    .foregroundColor(JetBrainsTheme.textPrimary)
                    .submitLabel(.send)
                    .focused($isInputFocused)
                    .accessibilityLabel("Message input")
                    .accessibilityHint("Type your message or drop files to send to the AI assistant")
                    .accessibilityValue(viewModel.inputText.isEmpty ? "Empty" : viewModel.inputText)
                    .onDrop(of: [.fileURL, .image], isTargeted: $isDragTargetActive) { providers in
                        handleFileDrop(providers: providers)
                    }
                    .onTapGesture {
                        isInputFocused = true
                    }
                    .onChange(of: isInputFocused) { _, focused in
                        NotificationCenter.default.post(
                            name: .textFieldFocusChanged,
                            object: ["focused": focused]
                        )
                        
                        if !focused {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if let window = NSApplication.shared.keyWindow,
                                   !(window.firstResponder is NSTextField) && 
                                   !(window.firstResponder is NSTextView) {
                                    isInputFocused = true
                                }
                            }
                        }
                    }
                    .onSubmit {
                        viewModel.sendTextMessage()
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(
                                isInputFocused ? 
                                    JetBrainsTheme.accentPrimary.opacity(0.5) : 
                                    JetBrainsTheme.border.opacity(0.3), 
                                lineWidth: 0.5
                            )
                    )
                    .animation(.easeInOut(duration: 0.15), value: isInputFocused)
                
                // Enhanced send button with hover effects
                Button(action: viewModel.sendTextMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(sendButtonForegroundColor)
                        .frame(width: 36, height: 36)
                        .background(sendButtonBackgroundColor)
                        .cornerRadius(2)
                        .scaleEffect(isHoveringOverSend && canSend ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: isHoveringOverSend)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canSend || viewModel.isProcessing)
                .onHover { hovering in
                    isHoveringOverSend = hovering
                }
                .accessibilityLabel("Send message")
                .accessibilityHint("Sends your typed message to the AI assistant")
                .accessibilityAddTraits(canSend ? [.isButton] : [])
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
    }
    
    // MARK: - Computed Properties for Enhanced UX
    
    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var sendButtonForegroundColor: Color {
        if canSend {
            return isHoveringOverSend ? JetBrainsTheme.textPrimary : JetBrainsTheme.textPrimary.opacity(0.9)
        } else {
            return JetBrainsTheme.textSecondary.opacity(0.4)
        }
    }
    
    private var sendButtonBackgroundColor: Color {
        if canSend {
            if isHoveringOverSend {
                return JetBrainsTheme.accentPrimary.opacity(0.8)
            } else {
                return JetBrainsTheme.accentPrimary.opacity(0.6)
            }
        } else {
            return JetBrainsTheme.backgroundTertiary
        }
    }
    
    private var promptText: String {
        if isDragTargetActive {
            return "Drop files here..."
        } else {
            return "Type message..."
        }
    }
    
    // MARK: - Drag & Drop Support
    
    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            handleDroppedFile(url: url)
                        }
                    }
                }
                return true
            } else if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadItem(forTypeIdentifier: "public.image", options: nil) { item, error in
                    // Handle image drops - for now, we'll handle this in the next iteration
                    DispatchQueue.main.async {
                        viewModel.inputText = "📷 Image dropped - image analysis feature coming soon!"
                    }
                }
                return true
            }
        }
        
        return false
    }
    
    private func handleDroppedFile(url: URL) {
        let fileExtension = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent
        
        switch fileExtension {
        case "txt", "md", "swift", "py", "js", "html", "css", "json", "xml":
            // Text files - read content and add to input
            do {
                let content = try String(contentsOf: url)
                let preview = content.prefix(200) + (content.count > 200 ? "..." : "")
                viewModel.inputText = "📄 \(fileName):\n\(preview)"
            } catch {
                viewModel.inputText = "❌ Could not read file: \(fileName)"
            }
            
        case "png", "jpg", "jpeg", "gif", "bmp", "tiff":
            // Images - trigger screenshot analysis workflow
            viewModel.inputText = "🖼️ \(fileName) - Analyzing image..."
            // In a full implementation, this would trigger the vision API
            
        default:
            viewModel.inputText = "📁 \(fileName) - File type not yet supported for analysis"
        }
        
        // Auto-focus input for user to add context or send
        isInputFocused = true
    }
}
