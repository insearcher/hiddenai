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
    
    // Transcription state
    private(set) var isRecording = false
    
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
                
                // Notify that recording has started
                notificationService.post(name: .whisperRecordingStarted, object: nil)
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
        
        // Notify that recording has stopped
        notificationService.post(name: .whisperRecordingStopped, object: nil)
        print("Stopped recording for Whisper transcription. Duration: \(durationString)")
        
        // Keep a reference to the file URL
        let finalFileURL = fileURL
        
        // Release the recorder to free up microphone resources
        audioRecorder = nil
        
        // Send the audio file to OpenAI for transcription
        openAIClient.transcribeAudio(fileURL: finalFileURL) { [weak self] result in
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
    
    /// Toggle recording state
    func toggleRecording(contextInfo: [String: Any]? = nil, completion: @escaping (Result<String, Error>?) -> Void) {
        if isRecording {
            stopRecordingAndTranscribe(contextInfo: contextInfo) { result in
                completion(result)
            }
        } else {
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
    
    /// Get the current recording time as a formatted string
    func recordingTime() -> String {
        guard let startTime = recordingStartTime, isRecording else { return "00:00" }
        
        let currentTime = Date()
        let duration = currentTime.timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        return String(format: "%02d:%02d", minutes, seconds)
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
}

// Import extension for TempFileManager
extension WhisperTranscriptionService {
    // Make TempFileManager available to WhisperTranscriptionService
    var tempFileManager: TempFileManager {
        return TempFileManager.shared
    }
}
