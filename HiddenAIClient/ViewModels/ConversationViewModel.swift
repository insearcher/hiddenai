//
//  ConversationViewModel.swift
//  HiddenAIClient
//
//  Created on 4/20/25.
//

import Foundation
import SwiftUI
import Combine

class ConversationViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Messages displayed in the conversation
    @Published var messages: [Message] = []
    
    /// Whether the app is currently processing a request
    @Published var isProcessing: Bool = false
    
    /// Whether the API key is set
    @Published var apiKeyIsSet: Bool = false
    
    /// Input text from the text field
    @Published var inputText: String = ""
    
    /// Whether Whisper is currently recording
    @Published var isWhisperRecording: Bool = false
    
    /// Current Whisper recording time display
    @Published var whisperRecordingTime: String = "00:00"
    
    /// Whether a screenshot is being processed
    @Published var isProcessingScreenshot: Bool = false
    
    /// Path to the last captured screenshot
    @Published var screenshotPath: String? = nil
    
    /// Whether to automatically scroll to the bottom
    @Published var scrollToBottom: Bool = true
    
    /// ID of the latest message for scrolling
    @Published var latestMessageId: UUID? = nil
    
    /// Whether to show the scroll to bottom button
    @Published var showScrollToButton: Bool = false
    
    // MARK: - Dependencies
    
    private let openAIClient: OpenAIClientProtocol
    private let whisperService: WhisperTranscriptionServiceProtocol
    private var notificationService: NotificationServiceProtocol
    private var notificationObservers: [NSObjectProtocol] = []
    
    // MARK: - Initialization
    
    init(
        openAIClient: OpenAIClientProtocol = OpenAIClient.shared,
        whisperService: WhisperTranscriptionServiceProtocol = WhisperTranscriptionService.shared,
        notificationService: NotificationServiceProtocol = DefaultNotificationService()
    ) {
        self.openAIClient = openAIClient
        self.whisperService = whisperService
        self.notificationService = notificationService
        
        // Check API key on init
        checkAPIKey()
        
        // Setup notification observers
        setupNotifications()
    }
    
    deinit {
        // Remove all notification observers
        removeNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Send a text message from the input field
    func sendTextMessage() {
        // Get the trimmed text
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only process if there's text and we're not already processing
        guard !text.isEmpty && !isProcessing else { return }
        
        // Process the text input
        processTranscription(text)
        
        // Clear the input field
        inputText = ""
    }
    
    /// Clear the conversation
    func clearConversation() {
        messages.removeAll()
        openAIClient.clearConversation()
    }
    
    /// Toggle Whisper recording
    func toggleWhisperRecording() {
        // Check if we have an API key first
        if !openAIClient.hasApiKey {
            addMessage("OpenAI API key not set. Please configure in settings.", type: .assistant)
            return
        }
        
        // Toggle recording with Whisper service
        whisperService.toggleRecording(contextInfo: nil) { [weak self] result in
            if case .failure(let error) = result {
                DispatchQueue.main.async {
                    self?.addMessage("Error: \(error.localizedDescription)", type: .assistant)
                }
            }
        }
    }
    
    /// Capture a screenshot
    func captureScreenshot() {
        // Check if we have an API key first
        if !openAIClient.hasApiKey {
            addMessage("OpenAI API key not set. Please configure in settings.", type: .assistant)
            return
        }
        
        // Prevent multiple capture attempts
        if isProcessingScreenshot {
            return
        }
        
        isProcessingScreenshot = true
        
        // Request screenshot capture through notification
        notificationService.post(name: .captureScreenshotRequested, object: nil)
        
        // Add a message to indicate we're processing
        addMessage("Capturing and analyzing screenshot...", type: .user)
    }
    
    // MARK: - Message Handling
    
    /// Add a message to the conversation
    /// - Parameters:
    ///   - text: The message text
    ///   - type: The type of message (user or assistant)
    /// - Returns: The ID of the added message
    @discardableResult
    func addMessage(_ text: String, type: Message.MessageType) -> UUID {
        let message = Message(
            text: text, 
            type: type, 
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            self.messages.append(message)
            
            // Set the latest message ID for scrolling
            self.latestMessageId = message.id
            
            // Re-enable auto-scrolling when a new user message is added
            // This ensures new conversations start with auto-scroll enabled
            if type == .user {
                self.scrollToBottom = true
            }
        }
        
        return message.id
    }
    
    /// Process text input or transcription
    /// - Parameter text: The text to process
    private func processTranscription(_ text: String) {
        // Add the user's message to the conversation
        addMessage(text, type: .user)
        
        // Send to OpenAI for processing
        if openAIClient.hasApiKey {
            isProcessing = true
            
            // Send a regular request - no reply context needed
            openAIClient.sendRequest(prompt: text) { [weak self] result in
                // Only handle failures in the completion handler
                // Success responses are handled by the notification observer
                if case .failure(let error) = result {
                    DispatchQueue.main.async {
                        self?.addMessage("Error: \(error.localizedDescription)", type: .assistant)
                        self?.isProcessing = false
                    }
                }
                // We don't set isProcessing = false for success case 
                // as the notification handler will do that
            }
        } else {
            addMessage("Please set your OpenAI API key in settings to receive responses.", type: .assistant)
        }
    }
    
    // MARK: - Notification Handling
    
    /// Set up all notification observers
    private func setupNotifications() {
        // Screenshot notifications
        addNotificationObserver(
            forName: .screenshotCaptured,
            handler: { [weak self] notification in
                if let userInfo = notification.object as? [String: String],
                   let path = userInfo["path"] {
                    DispatchQueue.main.async {
                        self?.screenshotPath = path
                        print("Screenshot captured at path: \(path)")
                    }
                }
            }
        )
        
        addNotificationObserver(
            forName: .screenshotProcessing,
            handler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isProcessingScreenshot = true
                    
                    // Optionally add the processing message if it doesn't exist yet
                    if !(self?.messages.contains(where: { $0.contents.first?.content.contains("Capturing and analyzing screenshot") == true }) ?? false) {
                        self?.addMessage("Capturing and analyzing screenshot...", type: .user)
                    }
                }
            }
        )
        
        addNotificationObserver(
            forName: .screenshotError,
            handler: { [weak self] notification in
                if let userInfo = notification.object as? [String: String],
                   let errorMessage = userInfo["error"] {
                    DispatchQueue.main.async {
                        self?.isProcessingScreenshot = false
                        self?.addMessage("Screenshot error: \(errorMessage)", type: .assistant)
                    }
                }
            }
        )
        
        // Whisper recording state
        addNotificationObserver(
            forName: .whisperRecordingStarted,
            handler: { [weak self] notification in
                DispatchQueue.main.async {
                    self?.isWhisperRecording = true
                    // Get initial time from notification if provided
                    if let userInfo = notification.object as? [String: String],
                       let initialTime = userInfo["timeString"] {
                        self?.whisperRecordingTime = initialTime
                    } else {
                        self?.whisperRecordingTime = "00:00"
                    }
                }
            }
        )
        
        addNotificationObserver(
            forName: .whisperRecordingStopped,
            handler: { [weak self] notification in
                DispatchQueue.main.async {
                    self?.isWhisperRecording = false
                }
            }
        )
        
        // Whisper recording time updates
        addNotificationObserver(
            forName: .whisperRecordingTimeUpdated,
            handler: { [weak self] notification in
                if let userInfo = notification.object as? [String: String],
                   let timeString = userInfo["timeString"] {
                    DispatchQueue.main.async {
                        self?.whisperRecordingTime = timeString
                    }
                }
            }
        )
        
        // Whisper transcription results
        addNotificationObserver(
            forName: .whisperTranscriptionReceived,
            handler: { [weak self] notification in
                if let userInfo = notification.object as? [String: Any],
                   let transcript = userInfo["transcript"] as? String,
                   !transcript.isEmpty {
                    DispatchQueue.main.async {
                        self?.processTranscription(transcript)
                    }
                }
            }
        )
        
        // Whisper transcription errors
        addNotificationObserver(
            forName: .whisperTranscriptionError,
            handler: { [weak self] notification in
                if let userInfo = notification.object as? [String: Any],
                   let errorMessage = userInfo["error"] as? String {
                    DispatchQueue.main.async {
                        self?.addMessage("Whisper transcription error: \(errorMessage)", type: .assistant)
                    }
                }
            }
        )
        
        // OpenAI API responses
        addNotificationObserver(
            forName: Notification.Name("OpenAIResponseReceived"),
            handler: { [weak self] notification in
                if let userInfo = notification.object as? [String: Any],
                   let response = userInfo["response"] as? String {
                    DispatchQueue.main.async {
                        self?.addMessage(response, type: .assistant)
                        
                        // Always stop processing indicators after a response
                        self?.isProcessing = false
                        self?.isProcessingScreenshot = false
                    }
                }
            }
        )
        
        // OpenAI error notifications
        addNotificationObserver(
            forName: Notification.Name("OpenAIError"),
            handler: { [weak self] notification in
                if let userInfo = notification.object as? [String: Any],
                   let error = userInfo["error"] as? String {
                    DispatchQueue.main.async {
                        self?.addMessage("Error: \(error)", type: .assistant)
                        self?.isProcessing = false
                        self?.isProcessingScreenshot = false
                    }
                }
            }
        )
    }
    
    /// Helper to add notification observers and keep track of them
    private func addNotificationObserver(forName name: Notification.Name, handler: @escaping (Notification) -> Void) {
        let observer = notificationService.addObserverForName(name, object: nil, queue: .main, using: handler)
        notificationObservers.append(observer)
    }
    
    /// Remove all notification observers
    private func removeNotifications() {
        for observer in notificationObservers {
            notificationService.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }
    
    /// Check if the API key is set
    private func checkAPIKey() {
        apiKeyIsSet = openAIClient.hasApiKey
    }
}
