//
//  EnhancedContentView.swift
//  HiddenWindowMCP
//
//  Created by Claude on 4/9/25.
//

import SwiftUI

// Notification names are now defined in NotificationManager.swift

struct EnhancedContentView: View {
    // Original states
    @State private var currentTime = Date()
    @State private var isRecording = false
    @State private var recordingTime = "00:00"
    @State private var lastRecordingInfo: String? = nil
    @State private var pulseEffect = false
    @State private var isClickThrough = false
    
    // Settings
    @State private var showSettings = false
    
    // Authentication service removed for open source version
    
    // OpenAI client reference
    private let openAIClient = OpenAIClient.shared
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with title and time
            HStack {
                Text("Hidden AI")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                
                Spacer()
                
                Text(timeString(date: currentTime))
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                    .padding(6)
                    .background(JetBrainsTheme.backgroundSecondary)
                    .cornerRadius(4)
                    .onReceive(timer) { _ in
                        currentTime = Date()
                        if isRecording, let delegate = (NSApplication.shared.delegate as? AppDelegate) {
                            let audioService = delegate.audioService as? AudioRecorder
                            recordingTime = audioService?.recordingTime() ?? "00:00"
                        }
                    }
            }
            .padding(12)
            .background(JetBrainsTheme.backgroundSecondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(JetBrainsTheme.border, lineWidth: 1)
            )
            
            // Status indicators section
            HStack(spacing: 20) {
                // Recording status
                if isRecording {
                    HStack(spacing: 8) {
                        // Animated recording indicator
                        Circle()
                            .fill(JetBrainsTheme.error)
                            .frame(width: 10, height: 10)
                            .opacity(pulseEffect ? 1.0 : 0.5)
                        
                        Text("RECORDING")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(JetBrainsTheme.error)
                        
                        Text(recordingTime)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(JetBrainsTheme.textPrimary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(JetBrainsTheme.backgroundTertiary)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(JetBrainsTheme.error.opacity(0.5), lineWidth: 1)
                    )
                    .onAppear {
                        // Start pulsing animation
                        withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulseEffect = true
                        }
                    }
                }
                
                // Voice recognition status has been removed - now only using Whisper
                
                Spacer()
                
                // Settings button
                Button(action: {
                    showSettings.toggle()
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                        .foregroundColor(JetBrainsTheme.textPrimary)
                        .padding(6)
                        .background(JetBrainsTheme.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(JetBrainsTheme.border, lineWidth: 1)
                        )
                }
            }
            .padding(12)
            .background(JetBrainsTheme.backgroundSecondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(JetBrainsTheme.border, lineWidth: 1)
            )
            
            // Speech recognition UI section has been removed - now only using Whisper
            
            // Keyboard shortcuts section
            VStack(alignment: .leading, spacing: 10) {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                    .padding(.bottom, 4)
                
                // Window controls
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("⌘+B")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(JetBrainsTheme.accentPrimary.opacity(0.15))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(JetBrainsTheme.accentPrimary.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text("Toggle window visibility")
                            .font(.system(size: 13))
                            .foregroundColor(JetBrainsTheme.textPrimary)
                    }
                    
                    HStack(spacing: 8) {
                        Text("⌘+Arrow")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(JetBrainsTheme.accentPrimary.opacity(0.15))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(JetBrainsTheme.accentPrimary.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text("Move window")
                            .font(.system(size: 13))
                            .foregroundColor(JetBrainsTheme.textPrimary)
                    }
                    
                    HStack(spacing: 8) {
                        Text("⌘+R")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(JetBrainsTheme.accentSecondary.opacity(0.15))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(JetBrainsTheme.accentSecondary.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text("Toggle Whisper transcription")
                            .font(.system(size: 13))
                            .foregroundColor(JetBrainsTheme.textPrimary)
                    }
                    
                    HStack(spacing: 8) {
                        Text("⌘+Q")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(JetBrainsTheme.error.opacity(0.15))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(JetBrainsTheme.error.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text("Quit application")
                            .font(.system(size: 13))
                            .foregroundColor(JetBrainsTheme.textPrimary)
                    }
                }
            }
            .padding(12)
            .background(JetBrainsTheme.backgroundSecondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(JetBrainsTheme.border, lineWidth: 1)
            )
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        .background(JetBrainsTheme.backgroundPrimary)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            setupNotifications()
        }
        .onDisappear {
            removeNotifications()
        }
    }
    
    private func timeString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // Speech recognition methods have been removed - now only using Whisper
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name.recordingStarted,
            object: nil,
            queue: .main
        ) { _ in
            isRecording = true
            recordingTime = "00:00"
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name.recordingStopped,
            object: nil,
            queue: .main
        ) { _ in
            isRecording = false
            if let delegate = (NSApplication.shared.delegate as? AppDelegate) {
                let audioService = delegate.audioService as? AudioRecorder
                lastRecordingInfo = audioService?.stopRecording()
            }
        }
        
        // Listen for key press notifications (r, t, etc.)
        NotificationCenter.default.addObserver(
            forName: Notification.Name.keyPressNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.object as? [String: String] {
                // Handle T key (click-through toggle)
                if userInfo["key"] == "t" {
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
                       let windowManager = Mirror(reflecting: appDelegate).children
                          .first(where: { $0.label == "windowManager" })?.value as? WindowManager {
                        windowManager.toggleClickThroughMode()
                    }
                }
                
                // V key handler for voice recognition has been removed - now only using Whisper
            }
        }
        
        // Listen for click-through mode changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name.clickThroughModeChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.object as? [String: Bool] {
                self.isClickThrough = userInfo["isClickThrough"] ?? false
            }
        }
        
        // Removed speech recognition notification listeners - now only using Whisper
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}

#Preview {
    EnhancedContentView()
}
