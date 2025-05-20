//
//  WhisperTranscriptionService.swift
//  HiddenWindowMCP
//
//  Created on 4/10/25.
//

import Foundation
import AVFoundation
import Cocoa

/// A service that handles audio recording and transcription using OpenAI's Whisper API
class WhisperTranscriptionService: NSObject, WhisperTranscriptionServiceProtocol, AVAudioRecorderDelegate {
    // Singleton instance
    static let shared = WhisperTranscriptionService()
    
    // Audio recording components
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    
    // Transcription state
    private(set) var isRecording = false
    
    // Private backing field for recordingTimeString property
    private var _recordingTimeString: String = "00:00"
    
    // Debounce mechanism to prevent rapidly toggling recording
    private var lastActionTime: Date?
    private let minimumActionInterval: TimeInterval = 1.0
    
    // Last time recording was stopped - to enforce delay before starting again
    private var lastStopTime: Date?
    
    // Dependencies
    private let permissionManager: PermissionManagerProtocol
    private let openAIClient: OpenAIClientProtocol
    private let notificationService: NotificationServiceProtocol
    
    // Initialize with dependencies
    init(permissionManager: PermissionManagerProtocol, openAIClient: OpenAIClientProtocol, notificationService: NotificationServiceProtocol) {
        self.permissionManager = permissionManager
        self.openAIClient = openAIClient
        self.notificationService = notificationService
        
        super.init()
        
        // Only request permissions, don't set up audio session yet
        // to avoid showing the microphone indicator when not needed
        requestMicrophonePermission()
    }
    
    // Convenience initializer for singleton during transition to DI
    private convenience override init() {
        // During transition, fallback to shared instances
        let permissionManager = DIContainer.shared.resolve(PermissionManagerProtocol.self) ?? PermissionManager.shared
        let openAIClient = DIContainer.shared.resolve(OpenAIClientProtocol.self) ?? OpenAIClient.shared
        let notificationService = DIContainer.shared.resolve(NotificationServiceProtocol.self) ?? DefaultNotificationService()
        
        self.init(permissionManager: permissionManager, openAIClient: openAIClient, notificationService: notificationService)
    }
    
    // MARK: - Audio Session Setup
    
    private func requestMicrophonePermission() {
        // Just request permission without activating the microphone
        permissionManager.requestMicrophonePermission { granted in
            if granted {
                print("Microphone access granted for Whisper transcription")
            } else {
                print("Microphone access denied - Whisper transcription will not work")
            }
        }
    }
    
    // MARK: - Recording Methods
    
    /// Start recording audio for transcription
    func startRecording() -> Bool {
        // Check if already recording
        if isRecording {
            print("Already recording audio for transcription")
            return true
        }
        
        // Make sure any previous timer is stopped first
        stopTimer()
        
        // Generate a temporary file URL for the recording using TempFileManager
        recordingURL = TempFileManager.shared.createTempFileURL(prefix: "whisper_recording", extension: "m4a")
        
        guard let fileURL = recordingURL else {
            print("Failed to create recording file URL")
            return false
        }
        
        print("Will save Whisper recording to: \(fileURL.path)")
        
        // Recording settings for AAC format (optimal for Whisper API)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]
        
        do {
            // Create the audio recorder
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            
            if audioRecorder?.record() == true {
                isRecording = true
                recordingStartTime = Date()
                _recordingTimeString = "00:00"
                
                // Start a timer to update the recording time
                startTimer()
                
                // Notify that recording has started
                notificationService.post(
                    name: .whisperRecordingStarted, 
                    object: ["timeString": _recordingTimeString]
                )
                print("Started recording for Whisper transcription")
                return true
            } else {
                print("Failed to start recording for Whisper transcription")
                return false
            }
        } catch {
            print("Error creating audio recorder: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Stop recording and transcribe the audio
    func stopRecordingAndTranscribe(contextInfo: [String: Any]? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        guard isRecording, let recorder = audioRecorder, let fileURL = recordingURL else {
            let error = NSError(domain: "WhisperTranscriptionService", code: 400, 
                               userInfo: [NSLocalizedDescriptionKey: "No active recording found"])
            completion(.failure(error))
            return
        }
        
        // Always ensure we stop the timer first to prevent timer multiplication
        stopTimer()
        
        // Calculate recording duration
        var durationString = "unknown"
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            durationString = String(format: "%02d:%02d", minutes, seconds)
        }
        
        // Stop the recording
        recorder.stop()
        isRecording = false
        
        // Record when we stopped to enforce delay before starting again
        lastStopTime = Date()
        
        // Notify that recording has stopped
        notificationService.post(
            name: .whisperRecordingStopped, 
            object: ["finalDuration": durationString]
        )
        print("Stopped recording for Whisper transcription. Duration: \(durationString)")
        
        // Keep a reference to the file URL
        let finalFileURL = fileURL
        
        // Release the recorder to free up microphone resources
        audioRecorder = nil
        
        // Check file size before sending to API - prevents empty file errors
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: finalFileURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                print("Recording file size: \(fileSize) bytes")
                
                if fileSize < 1000 {
                    // File is too small, likely no audio was recorded
                    let error = NSError(domain: "WhisperTranscriptionService", code: 400, 
                                     userInfo: [NSLocalizedDescriptionKey: "Recording too short or no audio detected"])
                    
                    // Clean up the file
                    TempFileManager.shared.deleteTempFile(finalFileURL)
                    
                    // Return the error
                    completion(.failure(error))
                    return
                }
            }
        } catch {
            print("Warning: Could not check file size: \(error.localizedDescription)")
            // Continue anyway, let OpenAI try to process it
        }
        
        // Add a small delay to ensure audio file is properly finalized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Send the audio file to OpenAI for transcription
            self.openAIClient.transcribeAudio(fileURL: finalFileURL) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let transcript):
                    print("Received transcript from Whisper API: \(transcript)")
                    completion(.success(transcript))
                    
                    // Post notification with transcript and include any context
                    var notificationData: [String: Any] = ["transcript": transcript]
                    
                    // Add context info if available
                    if let contextInfo = contextInfo {
                        for (key, value) in contextInfo {
                            notificationData[key] = value
                        }
                    }
                    
                    self.notificationService.post(
                        name: .whisperTranscriptionReceived,
                        object: notificationData
                    )
                    
                    // Clean up the temporary audio file
                    DispatchQueue.global(qos: .background).async {
                        TempFileManager.shared.deleteTempFile(finalFileURL)
                    }
                    
                case .failure(let error):
                    print("Error transcribing audio: \(error.localizedDescription)")
                    
                    // Check if this is a network error that might be resolved with a retry
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain {
                        if nsError.code == NSURLErrorCancelled {
                            print("Network request was cancelled - possibly app state changed")
                        } else {
                            print("Network error encountered during transcription")
                        }
                    }
                    
                    completion(.failure(error))
                    
                    // Post notification about error
                    self.notificationService.post(
                        name: .whisperTranscriptionError,
                        object: ["error": error.localizedDescription]
                    )
                    
                    // Clean up the temporary audio file even on failure
                    DispatchQueue.global(qos: .background).async {
                        TempFileManager.shared.deleteTempFile(finalFileURL)
                    }
                }
            }
        }
    }
    
    /// Toggle recording state
    func toggleRecording(contextInfo: [String: Any]? = nil, completion: @escaping (Result<String, Error>?) -> Void) {
        // Prevent rapid toggling that can cause device conflicts
        let now = Date()
        if let lastAction = lastActionTime, now.timeIntervalSince(lastAction) < minimumActionInterval {
            print("Ignoring rapid toggle - preventing device conflicts")
            let error = NSError(domain: "WhisperTranscriptionService", code: 429, 
                              userInfo: [NSLocalizedDescriptionKey: "Please wait a moment before toggling recording again"])
            completion(.failure(error))
            return
        }
        lastActionTime = now
        
        if isRecording {
            // When stopping, add a small delay to ensure clean audio device shutdown
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.stopRecordingAndTranscribe(contextInfo: contextInfo) { result in
                    completion(result)
                }
            }
        } else {
            // Check if we recently stopped - add delay if needed
            if let lastStop = lastStopTime, now.timeIntervalSince(lastStop) < 1.0 {
                print("Recently stopped recording - adding delay before starting again")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !self.isRecording { // Double-check we haven't started in the meantime
                        let success = self.startRecording()
                        if success {
                            completion(nil) // No transcript when starting recording
                        } else {
                            completion(.failure(NSError(domain: "WhisperTranscriptionService", 
                                                    code: 500, 
                                                    userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"])))
                        }
                    }
                }
                return
            }
            
            let success = startRecording()
            if success {
                completion(nil) // No transcript when starting recording
            } else {
                completion(.failure(NSError(domain: "WhisperTranscriptionService", 
                                        code: 500, 
                                        userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"])))
            }
        }
    }
    
    /// Get the current recording time as a formatted string (implements protocol requirement)
    func recordingTime() -> String {
        return recordingTimeString
    }
    
    /// Current recording time as a formatted string (implements protocol property)
    var recordingTimeString: String {
        // This just returns the stored property, which is updated by the timer
        return _recordingTimeString
    }
    
    /// Starts a timer that updates the recording time
    private func startTimer() {
        // Stop any existing timer first
        stopTimer()
        
        // Create a new timer on the main thread
        DispatchQueue.main.async {
            self.recordingTimer = Timer.scheduledTimer(
                withTimeInterval: 1.0,
                repeats: true
            ) { [weak self] _ in
                self?.updateRecordingTime()
            }
            
            // Add the timer to the common run loop mode to ensure it fires even during UI events
            if let timer = self.recordingTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }
    
    /// Stops the recording timer
    private func stopTimer() {
        DispatchQueue.main.async {
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
        }
    }
    
    /// Updates the recording time and broadcasts it via notification
    private func updateRecordingTime() {
        guard let startTime = recordingStartTime, isRecording else { 
            _recordingTimeString = "00:00"
            return
        }
        
        let currentTime = Date()
        let duration = currentTime.timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        // Update the time string
        _recordingTimeString = String(format: "%02d:%02d", minutes, seconds)
        
        // Broadcast the updated time
        notificationService.post(
            name: .whisperRecordingTimeUpdated,
            object: ["timeString": _recordingTimeString]
        )
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording ended unsuccessfully")
            isRecording = false
            notificationService.post(
                name: .whisperTranscriptionError,
                object: ["error": "Recording ended unsuccessfully"]
            )
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Error during recording: \(error.localizedDescription)")
            isRecording = false
            notificationService.post(
                name: .whisperTranscriptionError,
                object: ["error": error.localizedDescription]
            )
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let whisperRecordingStarted = Notification.Name("WhisperRecordingStarted")
    static let whisperRecordingStopped = Notification.Name("WhisperRecordingStopped")
    static let whisperTranscriptionReceived = Notification.Name("WhisperTranscriptionReceived")
    static let whisperTranscriptionError = Notification.Name("WhisperTranscriptionError")
    static let whisperRecordingTimeUpdated = Notification.Name("WhisperRecordingTimeUpdated")
}

// Import extension for TempFileManager
extension WhisperTranscriptionService {
    // Make TempFileManager available to WhisperTranscriptionService
    var tempFileManager: TempFileManager {
        return TempFileManager.shared
    }
}
