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
    @State private var initialWindowPosition = CGPoint.zero
    
    var body: some View {
        VStack(spacing: 0) {
            // Minimal Header with drag functionality
            HStack {
                // Draggable area with title
                HStack {
                    Text("HIDDEN AI")
                        .font(.system(size: 14, weight: .light, design: .monospaced))
                        .foregroundColor(JetBrainsTheme.textSecondary)
                        .tracking(2)
                    
                    Spacer()
                }
                .contentShape(Rectangle()) // Make entire area draggable
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            moveWindow(with: value)
                        }
                        .onEnded { _ in
                            resetDrag()
                        }
                )
                
                // Button area (not draggable)
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
    
    // MARK: - Window Movement Functions
    
    private func moveWindow(with value: DragGesture.Value) {
        guard let window = NSApplication.shared.keyWindow else { return }
        
        // Store initial window position on first drag
        if initialWindowPosition == CGPoint.zero {
            initialWindowPosition = window.frame.origin
        }
        
        // Calculate new position
        let newX = initialWindowPosition.x + value.translation.width
        let newY = initialWindowPosition.y - value.translation.height // Flip Y coordinate
        
        // Keep window within screen bounds
        if let screenFrame = NSScreen.main?.visibleFrame {
            let constrainedX = max(screenFrame.minX - window.frame.width + 100, 
                                 min(newX, screenFrame.maxX - 100))
            let constrainedY = max(screenFrame.minY - window.frame.height + 100, 
                                 min(newY, screenFrame.maxY - 100))
            
            let newFrame = CGRect(
                x: constrainedX,
                y: constrainedY,
                width: window.frame.width,
                height: window.frame.height
            )
            
            window.setFrame(newFrame, display: true)
        }
    }
    
    private func resetDrag() {
        initialWindowPosition = CGPoint.zero
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
