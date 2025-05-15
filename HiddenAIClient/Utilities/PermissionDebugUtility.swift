//
//  PermissionDebugUtility.swift
//  HiddenAIClient
//
//  Created for debugging permission issues
//

import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit

class PermissionDebugUtility {
    
    static func checkAllPermissions() {
        print("\n============ PERMISSION DEBUG REPORT ============")
        
        // 1. Microphone permission
        print("\n1. MICROPHONE PERMISSION:")
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch micStatus {
        case .notDetermined:
            print("❓ Not determined - permission dialog will appear when needed")
        case .restricted:
            print("🔒 Restricted - access is restricted by parental controls or system settings")
        case .denied:
            print("❌ Denied - user denied access")
        case .authorized:
            print("✅ Authorized - access granted")
        @unknown default:
            print("❓ Unknown status")
        }
        
        // 2. Screen capture permission
        print("\n2. SCREEN CAPTURE PERMISSION:")
        Task {
            do {
                let content = try await SCShareableContent.current
                print("✅ Authorized - access granted")
                print("   Available displays: \(content.displays.count)")
                print("   Available windows: \(content.windows.count)")
                
                // Test if we can actually access display information
                if let firstDisplay = content.displays.first {
                    print("   Main display: \(firstDisplay.displayID) (\(firstDisplay.width)x\(firstDisplay.height))")
                }
            } catch {
                print("❌ Not authorized or error: \(error)")
                print("   Error details: \(error.localizedDescription)")
                
                if error.localizedDescription.contains("denied") || 
                   error.localizedDescription.contains("not authorized") {
                    print("\n📋 TO FIX: Go to System Settings → Privacy & Security → Screen Recording")
                    print("   Then enable permission for HiddenAI")
                }
            }
        }
        
        // 3. Check app sandboxing status
        print("\n3. SANDBOXING STATUS:")
        if let identifier = Bundle.main.bundleIdentifier {
            print("Bundle ID: \(identifier)")
            
            // Check if app is sandboxed
            let isContainer = FileManager.default.homeDirectoryForCurrentUser.path.contains("Containers")
            print("Sandboxed: \(isContainer ? "Yes" : "No")")
            
            if isContainer {
                print("   Container path: \(FileManager.default.homeDirectoryForCurrentUser.path)")
            }
        }
        
        // 4. Check current user
        print("\n4. USER CONTEXT:")
        print("User: \(NSUserName())")
        print("UID: \(getuid())")
        
        // 5. System audio capture capabilities
        print("\n5. SYSTEM AUDIO CAPABILITIES:")
        
        // Check if ScreenCaptureKit framework is available
        if #available(macOS 12.3, *) {
            print("✅ ScreenCaptureKit available (macOS 12.3+)")
        } else {
            print("❌ ScreenCaptureKit not available - requires macOS 12.3+")
        }
        
        print("\n================================================\n")
    }
    
    static func testAudioPermission() {
        print("\n============ AUDIO PERMISSION TEST ============")
        
        // Request microphone permission if not determined
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        if currentStatus == .notDetermined {
            print("Requesting microphone permission...")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    print("Microphone permission result: \(granted ? "GRANTED" : "DENIED")")
                }
            }
        } else {
            print("Microphone permission already determined: \(currentStatus)")
        }
    }
    
    static func testScreenCapturePermission() {
        print("\n============ SCREEN CAPTURE PERMISSION TEST ============")
        
        Task {
            do {
                print("Attempting to access screen content...")
                let content = try await SCShareableContent.current
                print("✅ SUCCESS: Screen capture permission granted")
                print("   Found \(content.displays.count) displays")
                print("   Found \(content.windows.count) windows")
                
                // Try to create a minimal stream to verify system audio capture
                await testSystemAudioStream(with: content)
            } catch {
                print("❌ FAILED: Screen capture permission denied")
                print("   Error: \(error)")
                print("\n📋 Action needed:")
                print("   1. Go to System Settings → Privacy & Security")
                print("   2. Click on 'Screen Recording' in the left sidebar")
                print("   3. Enable permission for HiddenAI")
                print("   4. Restart the application")
            }
        }
    }
    
    private static func testSystemAudioStream(with content: SCShareableContent) async {
        print("\n--- Testing System Audio Stream ---")
        
        guard let display = content.displays.first else {
            print("❌ No displays available")
            return
        }
        
        // Create a minimal filter and configuration
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = false
        config.sampleRate = 44100
        config.channelCount = 2
        
        // Minimize video capture (set to minimal size)
        config.width = 1
        config.height = 1
        config.minimumFrameInterval = CMTime(value: 1, timescale: 5)
        
        do {
            print("Creating test stream...")
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            
            print("Starting test stream...")
            try await stream.startCapture()
            
            print("✅ SUCCESS: System audio stream created and started")
            print("   This means system audio capture should work")
            
            // Wait a bit then stop
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            print("Stopping test stream...")
            try await stream.stopCapture()
            
            print("✅ Test stream stopped successfully")
        } catch {
            print("❌ FAILED: Could not create/start system audio stream")
            print("   Error: \(error)")
        }
    }
    
    static func openPrivacySettings() {
        print("Opening Privacy & Security settings...")
        
        // Try to open Screen Recording settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
