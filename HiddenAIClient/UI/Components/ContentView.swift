//
//  ContentView.swift
//  HiddenWindowMCP
//
//  Created by Maxim Frolov on 4/8/25.
//

import SwiftUI

struct ContentView: View {
    @State private var currentTime = Date()
    @State private var isRecording = false
    @State private var recordingTime = "00:00"
    @State private var lastRecordingInfo: String? = nil
    @State private var pulseEffect = false
    @State private var isClickThrough = false
    
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
                    .padding(8)
                    .background(JetBrainsTheme.backgroundSecondary)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(JetBrainsTheme.border, lineWidth: 1)
                    )
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
                
                Spacer()
            }
            .padding(12)
            .background(JetBrainsTheme.backgroundSecondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(JetBrainsTheme.border, lineWidth: 1)
            )
            
            // Last recording info message
            if let info = lastRecordingInfo {
                Text(info)
                    .font(.system(size: 13))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(JetBrainsTheme.success.opacity(0.1))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(JetBrainsTheme.success.opacity(0.5), lineWidth: 1)
                    )
                    .onAppear {
                        // Auto-dismiss after 10 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            lastRecordingInfo = nil
                        }
                    }
            }
            
            // System information display
            VStack(alignment: .leading, spacing: 12) {
                Text("System Information")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                    .padding(.bottom, 4)
                
                VStack(spacing: 6) {
                    InfoRow(title: "CPU Usage", value: "32%")
                    InfoRow(title: "Memory", value: "8.5 GB / 16 GB")
                    InfoRow(title: "Network", value: "↓ 1.2 MB/s  ↑ 0.3 MB/s")
                    InfoRow(title: "Battery", value: "75% (3:42 remaining)")
                }
                
                Divider()
                    .background(JetBrainsTheme.border)
                    .padding(.vertical, 8)
                
                // Window Movement instructions
                HStack(spacing: 8) {
                    Text("Move Window")
                        .foregroundColor(JetBrainsTheme.textSecondary)
                        .frame(width: 100, alignment: .leading)
                        .font(.system(size: 13))
                    
                    HStack(spacing: 6) {
                        Text("Press")
                            .foregroundColor(JetBrainsTheme.textPrimary)
                            .font(.system(size: 13))
                        
                        // Command key
                        Text("⌘")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(JetBrainsTheme.backgroundTertiary)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(JetBrainsTheme.border, lineWidth: 1)
                            )
                        
                        Text("+")
                            .foregroundColor(JetBrainsTheme.textPrimary)
                            .font(.system(size: 13))
                        
                        // Arrow keys
                        Text("↑↓←→")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(JetBrainsTheme.backgroundTertiary)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(JetBrainsTheme.border, lineWidth: 1)
                            )
                    }
                }
                .padding(.vertical, 4)
                
                // Key shortcuts indicators
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keyboard Shortcuts")
                        .foregroundColor(JetBrainsTheme.textSecondary)
                        .font(.system(size: 13))
                        .padding(.bottom, 2)
                    
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
                        
                        Text("Toggle Window Visibility")
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
                        
                        Text("Toggle Whisper Transcription")
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
                        
                        Text("Quit Application")
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
                // Handle T key (click-through toggle) only
                // (R key is handled directly by the notification system)
                if userInfo["key"] == "t" {
                    // Find WindowManager and toggle click-through
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
                       let windowManager = Mirror(reflecting: appDelegate).children
                          .first(where: { $0.label == "windowManager" })?.value as? WindowManager {
                        windowManager.toggleClickThroughMode()
                    }
                }
            }
        }
        
        // Listen for click-through mode changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name.clickThroughModeChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.object as? [String: Bool],
               let clickThrough = userInfo["clickThrough"] {
                self.isClickThrough = clickThrough
            }
        }
        
        // Listen for click-through mode change notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name.clickThroughModeChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.object as? [String: Bool] {
                self.isClickThrough = userInfo["isClickThrough"] ?? true
            }
        }
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}

struct InfoRow: View {
    var title: String
    var value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(JetBrainsTheme.textSecondary)
                .font(.system(size: 13))
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .foregroundColor(JetBrainsTheme.textPrimary)
                .font(.system(size: 13))
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
