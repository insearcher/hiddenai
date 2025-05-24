//
//  ConversationViewModel.swift
//  HiddenAIClient
//
//  Created on 4/20/25.
//

import Foundation
import SwiftUI
import Combine

/// Represents different processing stages
enum ProcessingStage: CaseIterable {
    case none
    case whisperRecording
    case whisperProcessing
    case openAIProcessing
    case screenshot
    case screenshotCapturing
    case screenshotAnalyzing
    
    var displayText: String {
        switch self {
        case .none:
            return ""
        case .whisperRecording:
            return "Recording..."
        case .whisperProcessing:
            return "Processing: Whisper"
        case .openAIProcessing:
            return "Processing: OpenAI"
        case .screenshot:
            return "Processing: Screenshot"
        case .screenshotCapturing:
            return "Capturing screenshot..."
        case .screenshotAnalyzing:
            return "Analyzing screenshot..."
        }
    }
    
    var isProcessing: Bool {
        self != .none
    }
}

final class ConversationViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Conversation tabs containing question-answer pairs
    @Published var conversationTabs: [ConversationTab] = []
    
    /// Currently selected tab index
    @Published var selectedTabIndex: Int = 0
    
    /// Current processing stage
    @Published var processingStage: ProcessingStage = .none
    
    /// Computed property for backward compatibility
    var isProcessing: Bool {
        return processingStage.isProcessing
    }
    
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
    
    // Legacy properties for compatibility (will be removed)
    @Published var messages: [Message] = []
    @Published var scrollToBottom: Bool = true
    @Published var latestMessageId: UUID? = nil
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
        conversationTabs.removeAll()
        selectedTabIndex = 0
        messages.removeAll() // Keep for compatibility
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
        processingStage = .screenshotCapturing
        
        // Request screenshot capture through notification
        notificationService.post(name: .captureScreenshotRequested, object: nil)
        
        // Don't add a permanent message - let the processing indicator handle the UI
        // The actual screenshot content will be added when we get the OpenAI response
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
            // Legacy compatibility
            self.messages.append(message)
            self.latestMessageId = message.id
            
            // Handle tabbed interface
            if type == .user {
                // Create a new tab for user message
                let newTab = ConversationTab(userMessage: message)
                self.conversationTabs.append(newTab)
                self.selectedTabIndex = self.conversationTabs.count - 1
                self.scrollToBottom = true
            } else if type == .assistant {
                // Add assistant response to the latest tab
                if !self.conversationTabs.isEmpty {
                    let lastTabIndex = self.conversationTabs.count - 1
                    let currentTab = self.conversationTabs[lastTabIndex]
                    let updatedTab = ConversationTab(
                        userMessage: currentTab.userMessage,
                        assistantMessage: message,
                        timestamp: currentTab.timestamp
                    )
                    self.conversationTabs[lastTabIndex] = updatedTab
                }
            }
        }
        
        return message.id
    }
    
    /// Select a specific tab
    func selectTab(at index: Int) {
        guard index >= 0 && index < conversationTabs.count else { return }
        selectedTabIndex = index
    }
    
    /// Get the currently selected tab
    var currentTab: ConversationTab? {
        guard selectedTabIndex >= 0 && selectedTabIndex < conversationTabs.count else { return nil }
        return conversationTabs[selectedTabIndex]
    }
    
    /// Get messages for the current tab
    var currentTabMessages: [Message] {
        guard let tab = currentTab else { return [] }
        var messages = [tab.userMessage]
        if let assistantMessage = tab.assistantMessage {
            messages.append(assistantMessage)
        }
        return messages
    }
    
    /// Process text input or transcription using async method (no duplicate responses)
    /// - Parameter text: The text to process
    private func processTranscription(_ text: String) {
        // Add the user's message to the conversation
        addMessage(text, type: .user)
        
        // Send to OpenAI for processing
        if openAIClient.hasApiKey {
            processingStage = .openAIProcessing
            
            Task {
                do {
                    let response = try await openAIClient.sendRequest(prompt: text)
                    DispatchQueue.main.async {
                        self.addMessage(response, type: .assistant)
                        self.processingStage = .none
                    }
                } catch {
                    let aiError = AIServiceError.from(error)
                    DispatchQueue.main.async {
                        self.addMessage(aiError.localizedDescription, type: .assistant)
                        self.processingStage = .none
                    }
                }
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
                        // Update processing stage to analyzing
                        self?.processingStage = .screenshotAnalyzing
                        // Add a user message indicating that a screenshot was taken and is being analyzed
                        self?.addMessage("📷 Screenshot captured", type: .user)
                    }
                }
            }
        )
        
        addNotificationObserver(
            forName: .screenshotProcessing,
            handler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isProcessingScreenshot = true
                    // Processing indicator is now handled by the screenshot capture notification
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
                        self?.processingStage = .none
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
                    self?.processingStage = .whisperRecording
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
                    self?.processingStage = .whisperProcessing
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
                        self?.processingStage = .none  // Reset processing stage
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
                        self?.processingStage = .none  // Reset processing stage on error
                        
                        // Better error handling with more user-friendly messages
                        let friendlyMessage: String
                        
                        // Network errors
                        if errorMessage.contains("cancelled") {
                            friendlyMessage = "Transcription was cancelled due to a network issue. Please try again."
                        } 
                        // Empty recordings
                        else if errorMessage.contains("too short") || errorMessage.contains("no audio") || errorMessage.contains("too small") {
                            friendlyMessage = "Recording was too short or no audio was detected. Please try again."
                        }
                        // Rate limit errors
                        else if errorMessage.contains("wait") || errorMessage.contains("429") {
                            friendlyMessage = errorMessage
                        }
                        // Default error
                        else {
                            friendlyMessage = "Whisper transcription error: \(errorMessage)"
                        }
                        
                        self?.addMessage(friendlyMessage, type: .assistant)
                    }
                }
            }
        )
        
        // OpenAI API responses (handles both async and legacy callback responses)
        addNotificationObserver(
            forName: Notification.Name("OpenAIResponseReceived"),
            handler: { [weak self] notification in
                if let userInfo = notification.object as? [String: Any],
                   let response = userInfo["response"] as? String {
                    DispatchQueue.main.async {
                        // Add the response message to the conversation
                        // This handles screenshot responses and other legacy callback-based responses
                        self?.addMessage(response, type: .assistant)
                        
                        // Clear processing state
                        self?.processingStage = .none
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
                        // Customize error messages for better UX
                        let friendlyMessage: String
                        
                        if error.contains("API key not set") {
                            friendlyMessage = "Please set your OpenAI API key in settings to use this feature."
                        } else if error.contains("cancelled") {
                            friendlyMessage = "Request was cancelled. Please try again."
                        } else if error.contains("timeout") || error.contains("timed out") {
                            friendlyMessage = "Connection timed out. Please check your internet connection and try again."
                        } else if error.contains("Screen") && error.contains("permission") {
                            friendlyMessage = "Screen recording permission is required. Please check your Privacy settings."
                        } else {
                            friendlyMessage = "Error: \(error)"
                        }
                        
                        self?.addMessage(friendlyMessage, type: .assistant)
                        self?.processingStage = .none
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
