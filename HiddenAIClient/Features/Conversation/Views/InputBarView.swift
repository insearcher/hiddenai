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
        VStack(spacing: 10) {
            // API key warning if needed
            if !viewModel.apiKeyIsSet {
                Text("OpenAI API key not set. Click Settings to configure.")
                    .font(.system(size: 13))
                    .foregroundColor(JetBrainsTheme.warning)
                    .padding(8)
                    .background(JetBrainsTheme.warning.opacity(0.1))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(JetBrainsTheme.warning.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.horizontal)
            }
            
            // Text input field and send button
            HStack(spacing: 8) {
                TextField("Type your message...", text: $viewModel.inputText)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(JetBrainsTheme.backgroundTertiary)
                    .cornerRadius(6)
                    .foregroundColor(JetBrainsTheme.textPrimary)
                    .submitLabel(.send)
                    .focused($isInputFocused)
                    .onTapGesture {
                        // Ensure field gets focused when tapped
                        isInputFocused = true
                        print("Text field tapped, setting focus")
                    }
                    .onChange(of: isInputFocused) { _, focused in
                        // Notify about focus state changes
                        NotificationCenter.default.post(
                            name: .textFieldFocusChanged,
                            object: ["focused": focused]
                        )
                        print("Text input focus changed: \(focused)")
                        
                        // If losing focus unexpectedly, try to regain it
                        if !focused {
                            // Add a short delay before trying to refocus
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                // Only try to refocus if we're not currently in a different text field
                                if let window = NSApplication.shared.keyWindow,
                                   !(window.firstResponder is NSTextField) && 
                                   !(window.firstResponder is NSTextView) {
                                    isInputFocused = true
                                    print("Auto-refocusing text field")
                                }
                            }
                        }
                    }
                    .onSubmit {
                        viewModel.sendTextMessage()
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isInputFocused ? JetBrainsTheme.accentPrimary : JetBrainsTheme.border, lineWidth: isInputFocused ? 1.5 : 1)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isInputFocused)
                
                // Send button
                Button(action: viewModel.sendTextMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundColor(JetBrainsTheme.textPrimary)
                        .padding(10)
                        .background(JetBrainsTheme.accentPrimary)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing)
            }
            .padding(.horizontal)
        }
        .onAppear {
            // Set focus to the input field when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isInputFocused = true
            }
        }
    }
}
