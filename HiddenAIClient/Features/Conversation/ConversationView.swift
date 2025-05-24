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
            // Minimal Header
            HStack {
                // Title area
                HStack {
                    Text("HIDDEN AI")
                        .font(.system(size: 14, weight: .light, design: .monospaced))
                        .foregroundColor(JetBrainsTheme.textSecondary)
                        .tracking(2)
                    
                    Spacer()
                }
                
                // Button area
                HStack(spacing: 8) {
                    // Minimal settings button
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gear")
                            .foregroundColor(JetBrainsTheme.textSecondary)
                            .font(.system(size: 14, weight: .light))
                            .frame(width: 32, height: 32)
                            .background(JetBrainsTheme.backgroundTertiary)
                            .cornerRadius(2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Clear button
                    Button(action: viewModel.clearConversation) {
                        Image(systemName: "trash")
                            .foregroundColor(JetBrainsTheme.textSecondary)
                            .font(.system(size: 14, weight: .light))
                            .frame(width: 32, height: 32)
                            .background(JetBrainsTheme.backgroundTertiary)
                            .cornerRadius(2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(JetBrainsTheme.backgroundSecondary)
            
            // Thin separator line
            Rectangle()
                .fill(JetBrainsTheme.border.opacity(0.3))
                .frame(height: 0.5)
            
            // Tabbed conversation area
            TabbedConversationView(viewModel: viewModel)
            
            // Controls area
            VStack(spacing: 0) {
                // Thin separator line
                Rectangle()
                    .fill(JetBrainsTheme.border.opacity(0.3))
                    .frame(height: 0.5)
                
                // Text input field
                InputBarView(viewModel: viewModel, isInputFocused: _isInputFocused)
                    .padding(.vertical, 12)
                
                // Control buttons
                ControlBarView(viewModel: viewModel, showSettings: {
                    showSettings = true
                })
                    .padding(.bottom, 12)
            }
            .background(JetBrainsTheme.backgroundSecondary)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .background(JetBrainsTheme.backgroundPrimary)
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isInputFocused = true
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
