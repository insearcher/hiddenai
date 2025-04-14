//
//  AudioServiceProtocol.swift
//  HiddenWindowMCP
//
//  Created on 4/11/25.
//

import Foundation

/// Protocol for audio recording services
protocol AudioServiceProtocol: SelfResolvable {
    /// Starts recording audio
    /// - Returns: Success status of recording start
    func startRecording() -> Bool
    
    /// Stops the current recording
    /// - Returns: Optional message about the recording details
    func stopRecording() -> String?
    
    /// Checks if recording is currently active
    /// - Returns: Boolean indicating recording state
    func isCurrentlyRecording() -> Bool
    
    /// Gets the current recording duration as formatted string
    /// - Returns: Recording time string in format "MM:SS"
    func recordingTime() -> String
    
    /// Toggles recording state (starts if stopped, stops if recording)
    func toggleRecording()
    
    /// Sets up the audio components (initializes but doesn't start recording)
    func setup()
}
