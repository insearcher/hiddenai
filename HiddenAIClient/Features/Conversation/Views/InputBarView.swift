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
                TextField("", text: $viewModel.inputText, prompt: Text("Type message...")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(JetBrainsTheme.textSecondary.opacity(0.6)))
                    .font(.system(size: 14, weight: .light))
                    .padding(12)
                    .background(JetBrainsTheme.backgroundTertiary)
                    .cornerRadius(2)
                    .foregroundColor(JetBrainsTheme.textPrimary)
                    .submitLabel(.send)
                    .focused($isInputFocused)
                    .accessibilityLabel("Message input")
                    .accessibilityHint("Type your message to send to the AI assistant")
                    .accessibilityValue(viewModel.inputText.isEmpty ? "Empty" : viewModel.inputText)
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
                
                // Minimal send button
                Button(action: viewModel.sendTextMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(
                            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                JetBrainsTheme.textSecondary.opacity(0.4) : 
                                JetBrainsTheme.textPrimary.opacity(0.9)
                        )
                        .frame(width: 36, height: 36)
                        .background(
                            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                JetBrainsTheme.backgroundTertiary : 
                                JetBrainsTheme.accentPrimary.opacity(0.6)
                        )
                        .cornerRadius(2)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing)
                .accessibilityLabel("Send message")
                .accessibilityHint("Sends your typed message to the AI assistant")
                .accessibilityAddTraits(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : .isButton)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
    }
}
