//
//  AppDelegateProtocol.swift
//  HiddenWindowMCP
//
//  Created on 4/11/25.
//

import Foundation
import AppKit

/// Protocol defining the public interface of the AppDelegate
/// This allows for better testability and dependency management
protocol AppDelegateProtocol: AnyObject {
    /// Toggle window visibility (shows if hidden, hides if visible)
    func toggleWindowVisibility()
    
    /// Explicitly hide the window without destroying content
    func hideWindow()
    
    /// Explicitly show/restore the window
    func restoreWindow()
    
    /// Check if window is currently hidden
    func isWindowHidden() -> Bool
    
    /// Capture a screenshot and send to OpenAI
    func captureScreenshot(_ notification: Notification?)
    
    /// Toggle Whisper transcription recording
    func toggleWhisperTranscription()
    
    /// Access to the audio service
    var audioService: AudioServiceProtocol { get }
    
    /// Shows settings window
    func showSettings()
    
    /// Quit the application
    func quitApp()
    
    /// Clean up all temporary files
    func cleanupTempFiles()
}
