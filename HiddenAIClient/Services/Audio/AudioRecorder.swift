//
//  AudioRecorder.swift
//  HiddenWindowMCP
//
//  Created by Maxim Frolov on 4/8/25.
//

import Foundation
import AVFoundation
import AppKit
// Import the PermissionManager
import Cocoa

class AudioRecorder: NSObject, AudioServiceProtocol {
    private var audioEngine: AVAudioEngine?
    private var mixerNode: AVAudioMixerNode?
    private var file: AVAudioFile?
    private(set) var isRecording = false
    private var startTime: Date?
    
    // Notification service for dependency injection
    private let notificationService: NotificationServiceProtocol
    private let permissionManager: PermissionManagerProtocol
    
    // Default initializer with dependencies
    init(notificationService: NotificationServiceProtocol, permissionManager: PermissionManagerProtocol) {
        self.notificationService = notificationService
        self.permissionManager = permissionManager
        
        super.init()
        
        // Add observer for direct recording toggle
        notificationService.addObserver(
            self,
            selector: #selector(handleDirectToggle),
            name: Notification.Name.directRecordingToggle,
            object: nil
        )
    }
    
    // Convenience initializer for backward compatibility and transitioning to DI
    convenience override init() {
        // During transition, fallback to shared instances if DI container is not fully set up
        let notificationService = DIContainer.shared.resolve(NotificationServiceProtocol.self) ?? DefaultNotificationService()
        let permissionManager = DIContainer.shared.resolve(PermissionManagerProtocol.self) ?? PermissionManager.shared
        
        self.init(notificationService: notificationService, permissionManager: permissionManager)
    }
    
    @objc func handleDirectToggle() {
        print("AudioRecorder received direct toggle notification - current state: \(isRecording ? "recording" : "not recording")")
        
        // SIMPLIFIED APPROACH: Just call toggleRecording directly
        // This removes all the debouncing that was causing issues
        toggleRecording()
    }
    
    deinit {
        notificationService.removeObserver(self)
    }
    
    func setup() {
        // Only request permission, don't set up audio engine yet
        // This prevents the microphone indicator from showing until recording is actually needed
        requestMicrophonePermission()
        print("AudioRecorder setup complete - engine will be initialized on demand")
    }
    
    private func verifySetup() {
        // Check if our audio engine is ready
        if let audioEngine = audioEngine {
            if !audioEngine.isRunning {
                do {
                    try audioEngine.start()
                    print("Audio engine started in verification")
                } catch {
                    print("ERROR: Could not start audio engine in verification: \(error.localizedDescription)")
                }
            } else {
                print("Audio engine verified as running")
            }
        } else {
            print("ERROR: Audio engine is nil in verification")
        }
        
        // Check if our mixer node is available
        if mixerNode == nil {
            print("ERROR: Mixer node is nil in verification")
            // Try to recreate
            setupAudioEngine()
        } else {
            print("Mixer node verified as available")
        }
    }
    
    private func setupAudioEngine() {
        // Only create the audio engine if it doesn't exist yet
        if audioEngine == nil {
            print("Creating new audio engine")
            audioEngine = AVAudioEngine()
            mixerNode = AVAudioMixerNode()
            
            guard let audioEngine = audioEngine, let mixerNode = mixerNode else { return }
            
            // Configure the audio session for recording
            audioEngine.attach(mixerNode)
            
            // Get the native format of the input device
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            
            print("Native hardware input format: \(inputFormat)")
            
            // Connect the input node (microphone) to the mixer using the native format
            audioEngine.connect(inputNode, to: mixerNode, format: inputFormat)
            
            // Set mixer output format to match input format
            // This is important to avoid format conversion issues
            mixerNode.outputFormat(forBus: 0) // This just gets the format
            
            // We'll start the engine only when actually recording
            print("Audio engine created but not started yet")
        } else {
            print("Audio engine already exists, not creating a new one")
        }
    }
    
    func startRecording() -> Bool {
        print("Starting recording...")
        
        // Check if we need to create the audio engine
        if audioEngine == nil || mixerNode == nil {
            print("Audio engine not initialized yet, creating now")
            setupAudioEngine()
        }
        
        // Get audio engine after initialization
        guard let audioEngine = audioEngine, let mixerNode = mixerNode else {
            print("Cannot start recording - failed to initialize audio engine")
            return false
        }
        
        if isRecording {
            print("Already recording - ignoring start recording call")
            return true // Return true since we're already recording
        }
        
        // Make sure audio engine is running
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
                print("Started audio engine")
            } catch {
                print("Failed to start audio engine: \(error.localizedDescription)")
                return false
            }
        }
        
        // Use TempFileManager to get a URL for the recording file
        let finalPath = TempFileManager.shared.createTempFileURL(prefix: "Recording", extension: "m4a")
        print("Will save recording to: \(finalPath.path)")
        
        // Get the actual input format from the hardware
        let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        print("Hardware input format: \(inputFormat)")
        
        // Use the hardware input format for our recording
        let recordingFormat = inputFormat
        print("Using recording format: \(recordingFormat)")
        
        do {
            // SIMPLIFIED APPROACH: Use simpler audio file settings from the start
            // This is more likely to work across different systems
            print("Creating audio file with simplified settings")
            
            // Try to create the parent directory if it doesn't exist
            let directory = finalPath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, 
                                                   withIntermediateDirectories: true,
                                                   attributes: nil)
            
            // Get hardware's native sample rate
            let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)
            let hardwareSampleRate = inputFormat.sampleRate
            print("Using hardware sample rate: \(hardwareSampleRate) Hz")
            
            // Use the hardware's native sample rate to ensure compatibility
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: hardwareSampleRate,               // Use hardware's sample rate
                AVNumberOfChannelsKey: 1,                          // Mono for simplicity
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: 128000                        // 128kbps bitrate
            ]
            
            print("Creating audio file with settings: \(settings)")
            
            do {
                file = try AVAudioFile(forWriting: finalPath, settings: settings)
                print("Successfully created audio file")
            } catch {
                print("Failed to create audio file: \(error.localizedDescription)")
                return false // Exit if we can't create the file
            }
            
            print("Created audio file for writing")
            
            // Get input node for direct capture
            let inputNode = audioEngine.inputNode
            
            // Install tap on input node with hardware's native format
            inputNode.installTap(onBus: 0, bufferSize: 8192, format: nil) { [weak self] (buffer, time) in
                guard let self = self, let file = self.file else {
                    print("Tap callback - self or file is nil")
                    return
                }
                
                do {
                    try file.write(from: buffer)
                } catch {
                    print("Error writing to file: \(error.localizedDescription)")
                }
            }
            
            print("Successfully installed tap on input node")
            
            isRecording = true
            startTime = Date()
            
            // Notify that recording has started
            notificationService.post(name: Notification.Name.recordingStarted, object: nil)
            print("Recording started successfully")
            return true
            
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            return false
        }
    }
    
    func stopRecording() -> String? {
        print("Stopping recording...")
        
        if !isRecording {
            print("Not currently recording - ignoring stop recording call")
            return nil
        }
        
        // No need to guard mixerNode since we're checking it again later
        
        guard let startTime = startTime else {
            print("Cannot stop recording - startTime is nil")
            return nil
        }
        
        // Remove taps from both possible sources to ensure cleanup
        if let audioEngine = audioEngine {
            // Remove tap from input node
            audioEngine.inputNode.removeTap(onBus: 0)
            print("Removed tap from input node")
            
            // Also remove from mixer if available
            if let mixerNode = mixerNode {
                mixerNode.removeTap(onBus: 0)
                print("Removed tap from mixer node")
            }
        } else {
            print("Warning: audioEngine is nil when stopping recording")
        }
        
        isRecording = false
        
        // Calculate recording duration
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let durationString = String(format: "%02d:%02d", minutes, seconds)
        
        // Get the file path
        guard let file = file else {
            print("Cannot get file details - file is nil")
            return nil
        }
        
        // Capture details before we lose the file reference
        let filePath = file.url.path
        let locationName = file.url.deletingLastPathComponent().lastPathComponent
        let fileURL = file.url
        
        // Properly finalize and close the file
        self.file = nil
        
        // Force the AVFoundation system to finalize file by trying to read it
        // This is a common technique to ensure file headers are written
        DispatchQueue.global(qos: .background).async {
            do {
                // This will force the file to be finalized
                let audioFile = try AVAudioFile(forReading: fileURL)
                print("File finalized successfully with \(audioFile.length) frames")
                
                // Now register this file with TempFileManager for cleanup
                TempFileManager.shared.registerTempFile(fileURL)
            } catch {
                print("Error finalizing file: \(error.localizedDescription)")
            }
        }
        
        // Stop the audio engine to avoid showing microphone indicator when not recording
        if let audioEngine = audioEngine {
            audioEngine.stop()
            print("Audio engine stopped to prevent microphone indicator from showing")
        }
        
        // Notify that recording has stopped
        notificationService.post(name: Notification.Name.recordingStopped, object: nil)
        print("Recording stopped and saved: \(filePath)")
        
        // We're now always using the temporary directory managed by TempFileManager
        let message = "Recording saved: \(file.url.lastPathComponent) (\(durationString))"
        print(message)
        
        // Note: We don't delete the recording immediately as the user might want to access it
        // It will be cleaned up by TempFileManager on app exit or after a period of time
        
        return message
    }
    
    func isCurrentlyRecording() -> Bool {
        return isRecording
    }
    
    func recordingTime() -> String {
        guard let startTime = startTime, isRecording else { return "00:00" }
        
        let currentTime = Date()
        let duration = currentTime.timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Toggle recording state
    func toggleRecording() {
        print("Toggle recording called. Current state: \(isRecording ? "recording" : "not recording")")
        
        // SIMPLIFIED APPROACH: Direct toggle without the processing flag
        
        if isRecording {
            let result = stopRecording()
            print("Recording stopped. Result: \(result ?? "none")")
            
            // Notify other components about state change
            notificationService.post(name: .recordingStopped, object: nil)
        } else {
            let success = startRecording()
            print("Recording started. Success: \(success), isRecording: \(isRecording)")
            
            // Notify other components about state change
            if isRecording {
                notificationService.post(name: .recordingStarted, object: nil)
            }
        }
    }
    
    // Request microphone permission using the centralized PermissionManager
    private func requestMicrophonePermission() {
        permissionManager.requestMicrophonePermission { granted in
            if granted {
                print("Microphone access granted")
            } else {
                print("Microphone access denied - PermissionManager will handle the alert")
            }
        }
    }
}

// Import extension for TempFileManager
extension AudioRecorder {
    // Make TempFileManager available to AudioRecorder
    var tempFileManager: TempFileManager {
        return TempFileManager.shared
    }
}
