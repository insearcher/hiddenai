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
    @State private var isHoveringWhisper = false
    @State private var isHoveringScreenshot = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Enhanced Whisper record button with animations
            Button(action: viewModel.toggleWhisperRecording) {
                HStack(spacing: 8) {
                    Image(systemName: whisperIconName)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(whisperIconColor)
                        .scaleEffect(viewModel.isWhisperRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: viewModel.isWhisperRecording)
                    
                    Text(whisperButtonText)
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(whisperTextColor)
                    
                    // Recording time display
                    if viewModel.isWhisperRecording {
                        Text(viewModel.whisperRecordingTime)
                            .font(.system(size: 10, weight: .light, design: .monospaced))
                            .foregroundColor(JetBrainsTheme.error.opacity(0.7))
                            .transition(.opacity.combined(with: .slide))
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(whisperBackgroundColor)
                .cornerRadius(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(whisperBorderColor, lineWidth: 0.5)
                )
                .scaleEffect(isHoveringWhisper ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHoveringWhisper)
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                isHoveringWhisper = hovering
            }
            .help("Record audio and transcribe with OpenAI Whisper (Fn+Cmd+R)")
            .accessibilityLabel(viewModel.isWhisperRecording ? "Stop recording" : "Start whisper recording")
            .accessibilityHint("Records audio and transcribes it using OpenAI Whisper")
            .accessibilityAddTraits(.isButton)
            
            // Enhanced Screenshot button with animations
            Button(action: viewModel.captureScreenshot) {
                HStack(spacing: 8) {
                    Image(systemName: screenshotIconName)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(screenshotIconColor)
                        .rotationEffect(.degrees(viewModel.isProcessingScreenshot ? 360 : 0))
                        .animation(
                            viewModel.isProcessingScreenshot ? 
                                .linear(duration: 2).repeatForever(autoreverses: false) : 
                                .default, 
                            value: viewModel.isProcessingScreenshot
                        )
                    
                    Text(screenshotButtonText)
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(screenshotTextColor)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(screenshotBackgroundColor)
                .cornerRadius(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(screenshotBorderColor, lineWidth: 0.5)
                )
                .scaleEffect(isHoveringScreenshot ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHoveringScreenshot)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isProcessingScreenshot)
            .onHover { hovering in
                isHoveringScreenshot = hovering && !viewModel.isProcessingScreenshot
            }
            .help("Capture screen and analyze with GPT-4o (Fn+Cmd+P)")
            .accessibilityLabel(viewModel.isProcessingScreenshot ? "Processing screenshot" : "Capture screenshot")
            .accessibilityHint("Captures a screenshot and analyzes it using GPT-4o Vision")
            .accessibilityAddTraits(viewModel.isProcessingScreenshot ? [] : .isButton)
            
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
    
    // MARK: - Enhanced UI Computed Properties
    
    // Whisper Button Properties
    private var whisperIconName: String {
        if viewModel.isWhisperRecording {
            return "stop.fill"
        } else {
            return "waveform"
        }
    }
    
    private var whisperButtonText: String {
        viewModel.isWhisperRecording ? "STOP" : "WHISPER"
    }
    
    private var whisperIconColor: Color {
        if viewModel.isWhisperRecording {
            return JetBrainsTheme.error.opacity(0.8)
        } else if isHoveringWhisper {
            return JetBrainsTheme.accentPrimary.opacity(0.8)
        } else {
            return JetBrainsTheme.textSecondary
        }
    }
    
    private var whisperTextColor: Color {
        if viewModel.isWhisperRecording {
            return JetBrainsTheme.error.opacity(0.7)
        } else if isHoveringWhisper {
            return JetBrainsTheme.textPrimary.opacity(0.9)
        } else {
            return JetBrainsTheme.textSecondary
        }
    }
    
    private var whisperBackgroundColor: Color {
        if viewModel.isWhisperRecording {
            return JetBrainsTheme.error.opacity(0.1)
        } else if isHoveringWhisper {
            return JetBrainsTheme.accentPrimary.opacity(0.1)
        } else {
            return JetBrainsTheme.backgroundTertiary
        }
    }
    
    private var whisperBorderColor: Color {
        if viewModel.isWhisperRecording {
            return JetBrainsTheme.error.opacity(0.3)
        } else if isHoveringWhisper {
            return JetBrainsTheme.accentPrimary.opacity(0.3)
        } else {
            return JetBrainsTheme.border.opacity(0.3)
        }
    }
    
    // Screenshot Button Properties
    private var screenshotIconName: String {
        viewModel.isProcessingScreenshot ? "camera.rotate" : "camera.fill"
    }
    
    private var screenshotButtonText: String {
        viewModel.isProcessingScreenshot ? "PROCESSING" : "SCREENSHOT"
    }
    
    private var screenshotIconColor: Color {
        if viewModel.isProcessingScreenshot {
            return JetBrainsTheme.warning.opacity(0.8)
        } else if isHoveringScreenshot {
            return JetBrainsTheme.accentPrimary.opacity(0.8)
        } else {
            return JetBrainsTheme.textSecondary
        }
    }
    
    private var screenshotTextColor: Color {
        if viewModel.isProcessingScreenshot {
            return JetBrainsTheme.warning.opacity(0.7)
        } else if isHoveringScreenshot {
            return JetBrainsTheme.textPrimary.opacity(0.9)
        } else {
            return JetBrainsTheme.textSecondary
        }
    }
    
    private var screenshotBackgroundColor: Color {
        if viewModel.isProcessingScreenshot {
            return JetBrainsTheme.warning.opacity(0.1)
        } else if isHoveringScreenshot {
            return JetBrainsTheme.accentPrimary.opacity(0.1)
        } else {
            return JetBrainsTheme.backgroundTertiary
        }
    }
    
    private var screenshotBorderColor: Color {
        if viewModel.isProcessingScreenshot {
            return JetBrainsTheme.warning.opacity(0.3)
        } else if isHoveringScreenshot {
            return JetBrainsTheme.accentPrimary.opacity(0.3)
        } else {
            return JetBrainsTheme.border.opacity(0.3)
        }
    }
}
