//
//  ControlBarView.swift
//  HiddenAIClient
//
//  Created on 4/20/25.
//  Updated to use Fn+Cmd+ shortcuts (Fn+Cmd+R for Whisper, Fn+Cmd+P for Screenshot, Fn+Cmd+D for Clear Chat)
//

import SwiftUI

/// View for the control buttons (Whisper, Screenshot) at the bottom of the conversation
struct ControlBarView: View {
    @ObservedObject var viewModel: ConversationViewModel
    var showSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Whisper record button - minimal style
            Button(action: viewModel.toggleWhisperRecording) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isWhisperRecording ? "stop.fill" : "waveform")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(
                            viewModel.isWhisperRecording ? 
                                JetBrainsTheme.error.opacity(0.8) : 
                                JetBrainsTheme.textSecondary
                        )
                    
                    Text(viewModel.isWhisperRecording ? "STOP" : "WHISPER")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(JetBrainsTheme.textSecondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    viewModel.isWhisperRecording ? 
                        JetBrainsTheme.error.opacity(0.1) : 
                        JetBrainsTheme.backgroundTertiary
                )
                .cornerRadius(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(
                            viewModel.isWhisperRecording ? 
                                JetBrainsTheme.error.opacity(0.3) : 
                                JetBrainsTheme.border.opacity(0.3),
                            lineWidth: 0.5
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .help("Record audio and transcribe with OpenAI Whisper (Fn+Cmd+R)")
            
            // Screenshot button - minimal style
            Button(action: viewModel.captureScreenshot) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isProcessingScreenshot ? "hourglass" : "camera.fill")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(
                            viewModel.isProcessingScreenshot ? 
                                JetBrainsTheme.warning.opacity(0.8) : 
                                JetBrainsTheme.textSecondary
                        )
                    
                    Text(viewModel.isProcessingScreenshot ? "PROCESSING" : "SCREENSHOT")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(JetBrainsTheme.textSecondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    viewModel.isProcessingScreenshot ? 
                        JetBrainsTheme.warning.opacity(0.1) : 
                        JetBrainsTheme.backgroundTertiary
                )
                .cornerRadius(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(
                            viewModel.isProcessingScreenshot ? 
                                JetBrainsTheme.warning.opacity(0.3) : 
                                JetBrainsTheme.border.opacity(0.3),
                            lineWidth: 0.5
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isProcessingScreenshot)
            .help("Capture screen and analyze with GPT-4o (Fn+Cmd+P)")
            
            // Processing indicator - minimal
            if viewModel.processingStage != .none {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: JetBrainsTheme.textSecondary))
                        .scaleEffect(0.6)
                    
                    Text(viewModel.processingStage.displayText.uppercased())
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(JetBrainsTheme.textSecondary.opacity(0.6))
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
            
            // Keyboard shortcuts - minimal display
            VStack(alignment: .trailing, spacing: 3) {
                ForEach([
                    ("FN+⌘+R", "WHISPER"),
                    ("FN+⌘+P", "SCREENSHOT"),
                    ("FN+⌘+D", "CLEAR")
                ], id: \.0) { shortcut, label in
                    HStack(spacing: 8) {
                        Text(shortcut)
                            .font(.system(size: 10, weight: .light, design: .monospaced))
                            .foregroundColor(JetBrainsTheme.textSecondary.opacity(0.5))
                        
                        Text(label)
                            .font(.system(size: 10, weight: .light, design: .monospaced))
                            .foregroundColor(JetBrainsTheme.textSecondary.opacity(0.4))
                            .tracking(1)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
