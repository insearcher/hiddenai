//
//  ConversationView.swift
//  HiddenAIClient
//
//  Created by Maxim Frolov on 4/9/25.
//  Refactored on 4/20/25.
//

import SwiftUI
import AppKit

struct ConversationView: View {
    @EnvironmentObject private var viewModel: ConversationViewModel
    @State private var showSettings: Bool = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Conversation")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                
                Spacer()
                
                // Settings button
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(JetBrainsTheme.textPrimary)
                        .font(.system(size: 16))
                        .padding(6)
                        .background(JetBrainsTheme.backgroundTertiary)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 8)
                
                // Clear button
                Button(action: viewModel.clearConversation) {
                    Image(systemName: "trash")
                        .foregroundColor(JetBrainsTheme.textPrimary)
                        .font(.system(size: 16))
                        .padding(6)
                        .background(JetBrainsTheme.backgroundTertiary)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(JetBrainsTheme.accentPrimary.opacity(0.9))
            
            // Messages area with scrolling
            MessageListView(viewModel: viewModel)
            
            // Controls area
            VStack(spacing: 0) {
                // Text input field
                InputBarView(viewModel: viewModel, isInputFocused: _isInputFocused)
                
                // Control buttons
                ControlBarView(viewModel: viewModel, showSettings: {
                    showSettings = true
                })
            }
            .background(JetBrainsTheme.backgroundSecondary)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .background(JetBrainsTheme.backgroundPrimary)
        // Set minimum frame size
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            // Add a longer delay before focusing to ensure the UI is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isInputFocused = true
                print("Setting input focus to true after delay")
                
                // Try to focus text field through notification as well for redundancy
                NotificationCenter.default.post(
                    name: .focusTextFieldNotification,
                    object: nil
                )
            }
        }
    }
}

// For SwiftUI previews
struct ConversationView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationView()
            .environmentObject(ConversationViewModel())
            .preferredColorScheme(.dark)
    }
}
