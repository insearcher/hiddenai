//
//  SystemAudioRecorder.swift
//  HiddenWindowMCP
//
//  Created for system audio recording with proper error handling
//

import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreMedia
import AppKit

/// A simplified audio recorder that captures system audio using ScreenCaptureKit
/// This version handles common errors and provides fallback strategies
class SystemAudioRecorder: NSObject, AudioServiceProtocol, SCStreamOutput, SCStreamDelegate {
    private var screamStream: SCStream?
    private var audioWriter: AVAssetWriter?
    private var audioWriterInput: AVAssetWriterInput?
    private var recording = false
    private var startTime: Date?
    private var recordingURL: URL?
    private var streamConfiguration: SCStreamConfiguration?
    
    // Debounce mechanism to prevent rapid toggling
    private var lastActionTime: Date?
    private let minimumActionInterval: TimeInterval = 1.0
    private var lastStopTime: Date?
    
    // Debugging
    private var audioSampleCount = 0
    private var lastAudioReceived: Date?
    
    // Dependencies
    private let notificationService: NotificationServiceProtocol
    private let permissionManager: PermissionManagerProtocol
    
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
        
        print("SystemAudioRecorder initialized")
    }
    
    convenience override init() {
        let notificationService = DIContainer.shared.resolve(NotificationServiceProtocol.self) ?? DefaultNotificationService()
        let permissionManager = DIContainer.shared.resolve(PermissionManagerProtocol.self) ?? PermissionManager.shared
        
        self.init(notificationService: notificationService, permissionManager: permissionManager)
    }
    
    @objc func handleDirectToggle() {
        print("SystemAudioRecorder received direct toggle notification - current state: \(recording ? "recording" : "not recording")")
        toggleRecording()
    }
    
    deinit {
        print("SystemAudioRecorder deinit")
        notificationService.removeObserver(self)
        cleanupResources()
    }
    
    func setup() {
        print("SystemAudioRecorder setup - checking initial permissions...")
        
        // Check permissions immediately
        checkAllPermissions()
    }
    
    private func checkAllPermissions() {
        print("\n=== Permission Status Check ===")
        
        // Check microphone permission
        let micStatus = permissionManager.microphonePermissionStatus()
        print("Microphone permission: \(micStatus)")
        
        // Check screen capture permission
        permissionManager.screenCapturePermissionStatus { status in
            print("Screen capture permission: \(status)")
            
            if status != .authorized {
                print("WARNING: Screen capture permission not granted - system audio will not work!")
            }
        }
    }
    
    func startRecording() -> Bool {
        print("\n=== Starting SystemAudioRecorder ===")
        
        guard !recording else {
            print("Already recording")
            return true
        }
        
        // Reset debugging counters
        audioSampleCount = 0
        lastAudioReceived = nil
        
        // Create recording file
        recordingURL = TempFileManager.shared.createTempFileURL(prefix: "SystemRecording", extension: "m4a")
        guard let url = recordingURL else {
            print("Failed to create recording file URL")
            return false
        }
        
        print("Recording will be saved to: \(url.path)")
        
        recording = true
        startTime = Date()
        
        // Start recording asynchronously
        Task { @MainActor in
            await startSystemAudioRecording()
        }
        
        notificationService.post(name: Notification.Name.recordingStarted, object: nil)
        print("SystemAudioRecording start initiated")
        return true
    }
    
    @MainActor
    private func startSystemAudioRecording() async {
        guard let url = recordingURL else { 
            recording = false
            return 
        }
        
        do {
            print("\n--- Step 1: Checking permissions ---")
            
            // Check permissions first
            let hasScreenCapture = await checkScreenCapturePermission()
            if !hasScreenCapture {
                print("❌ Screen capture permission required but not granted")
                recording = false
                notificationService.post(
                    name: Notification.Name.openaiError,
                    object: ["error": "Screen recording permission required for system audio. Please grant permission in System Settings → Privacy & Security → Screen Recording"]
                )
                return
            }
            print("✅ Screen capture permission verified")
            
            print("\n--- Step 2: Getting shareable content ---")
            let content = try await SCShareableContent.current
            
            // Debug: List displays
            print("Found \(content.displays.count) displays")
            for (i, display) in content.displays.enumerated() {
                print("  Display \(i): \(display.displayID) - \(display.width)x\(display.height)")
            }
            
            // Get the main display
            guard let display = content.displays.first else {
                print("❌ No display found")
                recording = false
                return
            }
            print("✅ Using main display: \(display.displayID)")
            
            print("\n--- Step 3: Configuring filter ---")
            
            // Create content filter - exclude our own app windows
            let excludedWindows = content.windows.filter { window in
                let isOurApp = window.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
                if isOurApp {
                    print("  Excluding our window: \(window.title ?? "unnamed")")
                }
                return isOurApp
            }
            
            let filter = SCContentFilter(
                display: display,
                excludingWindows: excludedWindows
            )
            print("Created filter excluding \(excludedWindows.count) windows")
            
            print("\n--- Step 4: Configuring stream ---")
            
            // Configure stream for audio capture with more robust settings
            let streamConfig = SCStreamConfiguration()
            streamConfig.capturesAudio = true
            streamConfig.excludesCurrentProcessAudio = false  // We want to capture system audio
            streamConfig.sampleRate = 44100
            streamConfig.channelCount = 2
            
            // IMPORTANT: For system audio capture, we need some video capture
            // Setting to 0x0 can cause the stream to fail
            streamConfig.width = 100  // Small but not zero
            streamConfig.height = 100  // Small but not zero
            streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 1)  // Very low framerate
            
            // Audio specific settings
            streamConfig.queueDepth = 8  // Increase queue depth for better audio handling
            
            // Store configuration for debugging
            self.streamConfiguration = streamConfig
            
            print("Stream configuration:")
            print("  ✓ Captures audio: \(streamConfig.capturesAudio)")
            print("  ✓ Excludes current process audio: \(streamConfig.excludesCurrentProcessAudio)")
            print("  ✓ Sample rate: \(streamConfig.sampleRate) Hz")
            print("  ✓ Channel count: \(streamConfig.channelCount)")
            print("  ✓ Queue depth: \(streamConfig.queueDepth)")
            print("  ✓ Video dimensions: \(streamConfig.width)x\(streamConfig.height)")
            print("  ✓ Min frame interval: \(streamConfig.minimumFrameInterval.seconds) seconds")
            
            print("\n--- Step 5: Creating stream ---")
            
            // Create the stream
            screamStream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
            
            // Verify the stream was created
            guard screamStream != nil else {
                print("❌ Failed to create SCStream")
                recording = false
                return
            }
            print("✅ Created SCStream with delegate")
            
            print("\n--- Step 6: Setting up audio writer ---")
            
            // Setup audio writer
            audioWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
            
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
            audioWriterInput?.expectsMediaDataInRealTime = true
            
            if let writerInput = audioWriterInput,
               audioWriter?.canAdd(writerInput) == true {
                audioWriter?.add(writerInput)
                print("✅ Added audio input to writer")
            } else {
                print("❌ Cannot add audio input to writer")
                recording = false
                return
            }
            
            print("\n--- Step 7: Adding stream output ---")
            
            // Add stream output
            try screamStream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue.global(qos: .default))
            print("✅ Added stream output")
            
            print("\n--- Step 8: Starting capture ---")
            
            // Add a small delay before starting capture to ensure everything is ready
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Start capturing
            try await screamStream?.startCapture()
            print("✅ Stream capture started")
            
            // Start writing
            if audioWriter?.startWriting() == true {
                audioWriter?.startSession(atSourceTime: CMTime.zero)
                print("✅ Audio writer started successfully")
                
                // Set up a timer to check if we're receiving audio
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.checkAudioReception()
                }
            } else {
                print("❌ Failed to start audio writer")
                if let error = audioWriter?.error {
                    print("  Writer error: \(error)")
                }
                recording = false
            }
            
        } catch {
            print("❌ Error starting system audio recording: \(error)")
            
            // Handle specific error codes
            if let nsError = error as NSError? {
                print("  Error domain: \(nsError.domain)")
                print("  Error code: \(nsError.code)")
                
                if nsError.domain == "CoreGraphicsErrorDomain" && nsError.code == 1003 {
                    print("  This is a common SCStream error - try the following:")
                    print("  1. Make sure you're not already recording screen with another app")
                    print("  2. Check System Settings → Privacy & Security → Screen Recording")
                    print("  3. Try restarting the app")
                    
                    // Try to restart screen capture permission
                    notificationService.post(
                        name: Notification.Name.openaiError,
                        object: ["error": "Screen capture failed. Please check Screen Recording permission in System Settings and restart the app."]
                    )
                } else if nsError.code == -16665 {
                    print("  Error -16665: Audio capture permission issue")
                    print("  Try restarting the app and granting permissions again")
                    
                    notificationService.post(
                        name: Notification.Name.openaiError,
                        object: ["error": "Audio capture permission error. Please restart the app and grant permissions."]
                    )
                }
            }
            
            recording = false
            cleanupResources()
            
            // Post general error notification
            notificationService.post(
                name: Notification.Name.openaiError,
                object: ["error": "Failed to start system audio recording: \(error.localizedDescription)"]
            )
        }
    }
    
    private func checkScreenCapturePermission() async -> Bool {
        do {
            let _ = try await SCShareableContent.current
            return true
        } catch {
            print("Screen capture permission check failed: \(error)")
            return false
        }
    }
    
    private func checkAudioReception() {
        print("\n=== Audio Reception Check ===")
        print("Audio samples received: \(audioSampleCount)")
        
        if audioSampleCount == 0 {
            print("⚠️  WARNING: No audio samples received after 3 seconds")
            print("This could mean:")
            print("1. No audio is playing on the system")
            print("2. Screen recording permission was not properly granted")
            print("3. The system audio capture is not working correctly")
            
            // Post a warning notification
            notificationService.post(
                name: Notification.Name.openaiError,
                object: ["error": "No audio detected. Make sure audio is playing and screen recording permission is granted."]
            )
        } else {
            print("✅ Audio reception is working - \(audioSampleCount) samples received")
            if let lastReceived = lastAudioReceived {
                let timeSinceLastAudio = Date().timeIntervalSince(lastReceived)
                print("Last audio received: \(String(format: "%.1f", timeSinceLastAudio)) seconds ago")
            }
        }
    }
    
    func stopRecording() -> String? {
        print("\n=== Stopping SystemAudioRecorder ===")
        
        guard recording else {
            print("Not recording")
            return nil
        }
        
        recording = false
        
        // Record when we stopped to enforce delay before starting again
        lastStopTime = Date()
        
        // Calculate duration
        let duration: String
        if let startTime = startTime {
            let elapsed = Date().timeIntervalSince(startTime)
            let minutes = Int(elapsed) / 60
            let seconds = Int(elapsed) % 60
            duration = String(format: "%02d:%02d", minutes, seconds)
        } else {
            duration = "unknown"
        }
        
        print("Recording duration: \(duration)")
        print("Total audio samples captured: \(audioSampleCount)")
        
        // Stop stream and writer
        Task { @MainActor in
            do {
                print("Stopping capture...")
                try await screamStream?.stopCapture()
                print("✅ Stream stopped")
            } catch {
                print("❌ Error stopping stream: \(error)")
            }
            
            // Finish writing
            print("Finalizing audio file...")
            audioWriterInput?.markAsFinished()
            audioWriter?.finishWriting { [weak self] in
                guard let self = self else { return }
                
                if let url = self.recordingURL {
                    TempFileManager.shared.registerTempFile(url)
                    print("✅ System audio recording saved to: \(url.path)")
                    
                    // Check file size
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                        if let fileSize = attributes[.size] as? Int64 {
                            print("File size: \(fileSize) bytes")
                            if fileSize < 1000 {
                                print("⚠️  WARNING: File size is very small (\(fileSize) bytes)")
                                print("This usually means no audio was captured")
                            }
                        }
                    } catch {
                        print("Error checking file size: \(error)")
                    }
                } else {
                    print("❌ No recording URL")
                }
                
                self.cleanupResources()
            }
        }
        
        notificationService.post(name: Notification.Name.recordingStopped, object: nil)
        
        return "System audio recorded (\(duration))"
    }
    
    func isCurrentlyRecording() -> Bool {
        return recording
    }
    
    func recordingTime() -> String {
        guard let startTime = startTime, recording else { return "00:00" }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func toggleRecording() {
        print("SystemAudioRecorder - Toggle recording (current: \(recording))")
        
        // Prevent rapid toggling that can cause device conflicts
        let now = Date()
        if let lastAction = lastActionTime, now.timeIntervalSince(lastAction) < minimumActionInterval {
            print("Ignoring rapid toggle - preventing device conflicts")
            notificationService.post(
                name: Notification.Name.openaiError,
                object: ["error": "Please wait a moment before toggling recording again"]
            )
            return
        }
        lastActionTime = now
        
        if recording {
            _ = stopRecording()
        } else {
            // Check if we recently stopped - add delay if needed
            if let lastStop = lastStopTime, now.timeIntervalSince(lastStop) < 1.0 {
                print("Recently stopped recording - adding delay before starting again")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !self.recording { // Double-check we haven't started in the meantime
                        _ = self.startRecording()
                    }
                }
                return
            }
            
            _ = startRecording()
        }
    }
    
    private func cleanupResources() {
        print("Cleaning up resources...")
        screamStream = nil
        audioWriter = nil
        audioWriterInput = nil
        streamConfiguration = nil
    }
    
    // MARK: - SCStreamOutput
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        // Check if we're still recording
        guard recording, let writerInput = audioWriterInput else { return }
        
        // Count samples
        audioSampleCount += 1
        lastAudioReceived = Date()
        
        // Write to file if ready
        if writerInput.isReadyForMoreMediaData {
            writerInput.append(sampleBuffer)
            
            // Log first few samples for debugging
            if audioSampleCount <= 5 {
                print("✅ Received audio sample \(audioSampleCount)")
                
                // Debug: Sample buffer info
                if audioSampleCount == 1 {
                    if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
                        print("Audio format: \(formatDescription)")
                    }
                }
            } else if audioSampleCount == 6 {
                print("... continuing to receive audio samples")
                
                // Set up periodic logging
                DispatchQueue.main.async {
                    Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
                        if !self.recording {
                            timer.invalidate()
                            return
                        }
                        print("Audio samples: \(self.audioSampleCount)")
                    }
                }
            }
        } else {
            // Log if we can't write samples
            if audioSampleCount % 100 == 0 {  // Log every 100th time to avoid spam
                print("⚠️  WARNING: Audio writer not ready for more data (sample \(audioSampleCount))")
            }
        }
    }
    
    // MARK: - SCStreamDelegate
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("❌ Stream stopped with error: \(error)")
        recording = false
        cleanupResources()
        
        notificationService.post(
            name: Notification.Name.openaiError,
            object: ["error": "Audio stream stopped with error: \(error.localizedDescription)"]
        )
    }
}
