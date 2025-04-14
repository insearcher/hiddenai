//
//  WhisperTranscriptionServiceProtocol.swift
//  HiddenWindowMCP
//
//  Created on 4/11/25.
//

import Foundation

/// Protocol for Whisper transcription services
protocol WhisperTranscriptionServiceProtocol: SelfResolvable {
    /// Current recording state
    var isRecording: Bool { get }
    
    /// Starts recording audio for transcription
    /// - Returns: Success status of recording start
    func startRecording() -> Bool
    
    /// Stops recording and transcribes the audio
    /// - Parameters:
    ///   - contextInfo: Optional context information
    ///   - completion: Callback with transcription result
    func stopRecordingAndTranscribe(contextInfo: [String: Any]?, completion: @escaping (Result<String, Error>) -> Void)
    
    /// Toggles recording state and transcribes if stopping
    /// - Parameters:
    ///   - contextInfo: Optional context information
    ///   - completion: Callback with transcription result if stopping
    func toggleRecording(contextInfo: [String: Any]?, completion: @escaping (Result<String, Error>?) -> Void)
    
    /// Get the current recording time as a formatted string
    /// - Returns: Recording time string in format "MM:SS"
    func recordingTime() -> String
}
