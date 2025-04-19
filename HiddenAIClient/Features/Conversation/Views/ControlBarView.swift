//
//  ControlBarView.swift
//  HiddenAIClient
//
//  Created on 4/20/25.
//

import SwiftUI

/// View for the control buttons (Whisper, Screenshot) at the bottom of the conversation
struct ControlBarView: View {
    @ObservedObject var viewModel: ConversationViewModel
    var showSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Whisper record button
            Button(action: viewModel.toggleWhisperRecording) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isWhisperRecording ? "stop.circle.fill" : "waveform.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(viewModel.isWhisperRecording ? JetBrainsTheme.error : JetBrainsTheme.accentSecondary)
                    
                    Text(viewModel.isWhisperRecording ? "Stop Whisper" : "Whisper")
                        .font(.system(size: 14))
                        .foregroundColor(JetBrainsTheme.textPrimary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    viewModel.isWhisperRecording ? 
                        JetBrainsTheme.error.opacity(0.15) : 
                        JetBrainsTheme.backgroundTertiary
                )
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            viewModel.isWhisperRecording ? 
                                JetBrainsTheme.error.opacity(0.5) : 
                                JetBrainsTheme.border,
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .help("Record audio and transcribe with OpenAI Whisper (Cmd+R)")
            
            // Screenshot button
            Button(action: viewModel.captureScreenshot) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isProcessingScreenshot ? "hourglass" : "camera.fill")
                        .font(.system(size: 18))
                        .foregroundColor(viewModel.isProcessingScreenshot ? JetBrainsTheme.warning : JetBrainsTheme.accentPrimary)
                    
                    Text(viewModel.isProcessingScreenshot ? "Processing..." : "Screenshot")
                        .font(.system(size: 14))
                        .foregroundColor(JetBrainsTheme.textPrimary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    viewModel.isProcessingScreenshot ? 
                        JetBrainsTheme.warning.opacity(0.15) : 
                        JetBrainsTheme.backgroundTertiary
                )
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            viewModel.isProcessingScreenshot ? 
                                JetBrainsTheme.warning.opacity(0.5) : 
                                JetBrainsTheme.border,
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isProcessingScreenshot)
            .help("Capture screen and analyze with GPT-4o (Cmd+P)")
            
            Spacer()
            
            // Keyboard shortcuts
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Text("⌘+R")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(JetBrainsTheme.accentSecondary.opacity(0.15))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(JetBrainsTheme.accentSecondary.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("Whisper")
                        .font(.system(size: 12))
                        .foregroundColor(JetBrainsTheme.textSecondary)
                }
                
                HStack(spacing: 6) {
                    Text("⌘+P")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(JetBrainsTheme.accentPrimary.opacity(0.15))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(JetBrainsTheme.accentPrimary.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("Screenshot")
                        .font(.system(size: 12))
                        .foregroundColor(JetBrainsTheme.textSecondary)
                }
            }
            
            // Status indicators
            if viewModel.isProcessing {
                HStack(spacing: 5) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: JetBrainsTheme.textPrimary))
                        .scaleEffect(0.7)
                    
                    Text("Processing...")
                        .font(.system(size: 12))
                        .foregroundColor(JetBrainsTheme.textSecondary)
                }
            }
        }
        .padding(.vertical, 12)
    }
}
