//
//  NotificationManager.swift
//  HiddenWindowMCP
//
//  Created on 4/9/25.
//

import Foundation

/// NotificationManager centralizes all notification definitions and provides
/// convenience methods for posting and observing notifications.
class NotificationManager {
    /// Singleton instance
    static let shared = NotificationManager()
    
    // Private initializer for singleton
    private init() {}
    
    // MARK: - Notification Names
    
    /// Namespace for all notification names used in the application.
    /// This ensures all notifications are defined in one place and prevents duplications.
    struct Names {
        // MARK: - Recording-related Notifications
        
        /// Posted when recording is started
        static let recordingStarted = Notification.Name("RecordingStarted")
        
        /// Posted when recording is stopped
        static let recordingStopped = Notification.Name("RecordingStopped")
        
        /// Posted when recording is toggled directly
        static let directRecordingToggle = Notification.Name("DirectRecordingToggle")
        
        /// Posted to request a recording toggle
        static let recordingToggleRequested = Notification.Name("RecordingToggleRequested")
        
        // MARK: - User Interface Notifications
        
        /// Posted when a key press is detected
        static let keyPressDetected = Notification.Name("KeyPressDetected")
        
        /// Posted when click-through mode changes
        static let clickThroughModeChanged = Notification.Name("ClickThroughModeChanged")
        
        /// Posted when text field focus state changes
        static let textFieldFocusChanged = Notification.Name("TextFieldFocusChanged")
        
        /// Posted to request focusing a text field
        static let focusTextFieldRequested = Notification.Name("FocusTextFieldRequested")
        
        // Speech Recognition Notifications have been removed - now only using Whisper
        
        // MARK: - OpenAI Notifications
        
        /// Posted when a response is received from OpenAI
        static let openAIResponseReceived = Notification.Name("OpenAIResponseReceived")
        
        /// Posted when an error occurs with OpenAI
        static let openAIError = Notification.Name("OpenAIError")
        
        // MARK: - Permission Notifications
        
        /// Posted when permission status changes
        static let permissionStatusChanged = Notification.Name("PermissionStatusChanged")
        
        // MARK: - Window Notifications
        
        /// Posted when window transparency is changed
        static let windowTransparencyChanged = Notification.Name("WindowTransparencyChanged")
        
        /// Posted when window visibility should be toggled
        static let windowVisibilityToggle = Notification.Name("WindowVisibilityToggle")
        
        // MARK: - Screenshot Notifications
        
        /// Posted when a screenshot is captured
        static let screenshotCaptured = Notification.Name("ScreenshotCaptured")
        
        /// Posted when there's an error during screenshot capture or processing
        static let screenshotError = Notification.Name("ScreenshotError")
        
        /// Posted when a screenshot is being processed
        static let screenshotProcessing = Notification.Name("ScreenshotProcessing")
        
        /// Posted to request a screenshot capture
        static let captureScreenshotRequested = Notification.Name("CaptureScreenshotRequested")
    }
    
    // MARK: - Convenience Methods for Posting Notifications
    
    /// Post a notification that recording has started
    func postRecordingStarted() {
        NotificationCenter.default.post(name: Names.recordingStarted, object: nil)
    }
    
    /// Post a notification that recording has stopped
    func postRecordingStopped() {
        NotificationCenter.default.post(name: Names.recordingStopped, object: nil)
    }
    
    /// Post a notification for a key press
    /// - Parameter key: The key that was pressed
    func postKeyPress(key: String) {
        NotificationCenter.default.post(
            name: Names.keyPressDetected,
            object: ["key": key]
        )
    }
    
    /// Post a notification that click-through mode has changed
    /// - Parameter isClickThrough: Whether click-through mode is enabled
    func postClickThroughModeChanged(isClickThrough: Bool) {
        NotificationCenter.default.post(
            name: Names.clickThroughModeChanged,
            object: ["isClickThrough": isClickThrough]
        )
    }
    
    /// Post a notification that text field focus has changed
    /// - Parameter focused: Whether the text field is focused
    func postTextFieldFocusChanged(focused: Bool) {
        NotificationCenter.default.post(
            name: Names.textFieldFocusChanged,
            object: ["focused": focused]
        )
    }
    
    /// Post a notification to request focusing a text field
    func postFocusTextFieldRequest() {
        NotificationCenter.default.post(name: Names.focusTextFieldRequested, object: nil)
    }
    
    // Speech Recognition posting methods have been removed - now only using Whisper
    
    /// Post a notification with an OpenAI response
    /// - Parameter response: The response from OpenAI
    func postOpenAIResponse(response: String) {
        NotificationCenter.default.post(
            name: Names.openAIResponseReceived,
            object: ["response": response]
        )
    }
    
    /// Post a notification with an OpenAI error
    /// - Parameter error: The error message
    func postOpenAIError(error: String) {
        NotificationCenter.default.post(
            name: Names.openAIError,
            object: ["error": error]
        )
    }
    
    /// Post a notification that permission status has changed
    /// - Parameters:
    ///   - type: The type of permission
    ///   - granted: Whether the permission was granted
    func postPermissionStatusChanged(type: String, granted: Bool) {
        NotificationCenter.default.post(
            name: Names.permissionStatusChanged,
            object: ["type": type, "granted": granted]
        )
    }
    
    /// Post a notification that window transparency has changed
    /// - Parameter transparency: The new transparency value (0.0 to 1.0)
    func postWindowTransparencyChanged(transparency: Double) {
        NotificationCenter.default.post(
            name: Names.windowTransparencyChanged,
            object: ["transparency": transparency]
        )
    }
    
    /// Post a notification to toggle window visibility
    func postWindowVisibilityToggle() {
        NotificationCenter.default.post(name: Names.windowVisibilityToggle, object: nil)
    }
    
    /// Post a notification that a screenshot was captured
    /// - Parameter path: Path to the saved screenshot
    func postScreenshotCaptured(path: String) {
        NotificationCenter.default.post(
            name: Names.screenshotCaptured,
            object: ["path": path]
        )
    }
    
    /// Post a notification that there was an error with screenshot processing
    /// - Parameter error: The error message
    func postScreenshotError(error: String) {
        NotificationCenter.default.post(
            name: Names.screenshotError,
            object: ["error": error]
        )
    }
    
    /// Post a notification that screenshot processing has started
    func postScreenshotProcessing() {
        NotificationCenter.default.post(name: Names.screenshotProcessing, object: nil)
    }
    
    /// Post a notification to request a screenshot capture
    func requestScreenshotCapture() {
        NotificationCenter.default.post(name: Names.captureScreenshotRequested, object: nil)
    }
    
    // MARK: - Convenience Methods for Observing Notifications
    
    /// Observe a notification with a closure
    /// - Parameters:
    ///   - name: The notification name to observe
    ///   - object: The object posting the notification (optional)
    ///   - queue: The operation queue for the handler (default is main)
    ///   - handler: The closure to call when the notification is received
    /// - Returns: An observer token that can be used to stop observing
    @discardableResult
    func observe(
        name: Notification.Name,
        object: Any? = nil,
        queue: OperationQueue = .main,
        handler: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(
            forName: name,
            object: object,
            queue: queue,
            using: handler
        )
    }
    
    /// Stop observing a notification
    /// - Parameter observer: The observer token returned by observe()
    func stopObserving(_ observer: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer)
    }
    
    /// Stop observing all notifications for a given object
    /// - Parameter object: The object to stop observing
    func stopObserving(object: Any) {
        NotificationCenter.default.removeObserver(object)
    }
}

// MARK: - Legacy Support

/// Extension to support direct access to notification names
/// This makes it easier to transition from the old notification system
extension Notification.Name {
    // Recording
    static let recordingStarted = NotificationManager.Names.recordingStarted
    static let recordingStopped = NotificationManager.Names.recordingStopped
    static let directRecordingToggle = NotificationManager.Names.directRecordingToggle
    static let recordingToggleNotification = NotificationManager.Names.recordingToggleRequested
    
    // User Interface
    static let keyPressNotification = NotificationManager.Names.keyPressDetected
    static let clickThroughModeChanged = NotificationManager.Names.clickThroughModeChanged
    static let textFieldFocusChanged = NotificationManager.Names.textFieldFocusChanged
    static let focusTextFieldNotification = NotificationManager.Names.focusTextFieldRequested
    
    // Speech Recognition notifications removed - now only using Whisper
    
    // OpenAI
    static let openAIResponseReceived = NotificationManager.Names.openAIResponseReceived
    static let openaiError = NotificationManager.Names.openAIError
    
    // Window
    static let windowTransparencyChanged = NotificationManager.Names.windowTransparencyChanged
    static let windowVisibilityToggle = NotificationManager.Names.windowVisibilityToggle
    
    // Screenshot
    static let captureScreenshotRequested = NotificationManager.Names.captureScreenshotRequested
    static let screenshotCaptured = NotificationManager.Names.screenshotCaptured
    static let screenshotError = NotificationManager.Names.screenshotError
    static let screenshotProcessing = NotificationManager.Names.screenshotProcessing
}
