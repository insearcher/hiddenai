//
//  SettingsManager.swift
//  HiddenWindowMCP
//
//  Created by Claude on 4/9/25.
//

import Foundation

class SettingsManager: SettingsManagerProtocol {
    // Singleton instance
    static let shared = SettingsManager()
    
    // UserDefaults keys
    private struct Keys {
        static let apiKey = "openai_api_key"
        // model key removed - only using GPT-4o now
        static let windowTransparency = "window_transparency"
        static let position = "user_position"
        static let voiceContext = "voice_context"
        static let screenshotContext = "screenshot_context" 
        static let textContext = "text_context"
    }
    
    // Notification service for dependency injection
    private let notificationService: NotificationServiceProtocol
    
    // Default initializer with dependencies
    init(notificationService: NotificationServiceProtocol) {
        self.notificationService = notificationService
    }
    
    // Convenience initializer for singleton during transition to DI
    private convenience init() {
        // During transition, fallback to a default notification service
        let notificationService = DIContainer.shared.resolve(NotificationServiceProtocol.self) ?? DefaultNotificationService()
        self.init(notificationService: notificationService)
    }
    
    // MARK: - API Key
    
    var apiKey: String {
        get {
            return UserDefaults.standard.string(forKey: Keys.apiKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.apiKey)
        }
    }
    
    // Model selection removed - always using GPT-4o
    
    // Speech recognition feature toggles have been removed - now only using Whisper
    
    // MARK: - Window Settings
    
    var windowTransparency: Double {
        get {
            return UserDefaults.standard.double(forKey: Keys.windowTransparency)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.windowTransparency)
            // Post a notification that transparency has changed using DI
            notificationService.post(
                name: Notification.Name("WindowTransparencyChanged"),
                object: ["transparency": newValue]
            )
        }
    }
    
    // MARK: - Context Settings
    
    // Global/default context for all interactions
    var position: String {
        get {
            // If no custom context is set, provide a helpful default for first-time users
            let defaultContext = "You are a helpful assistant that provides clear, informative responses. " + 
                                "Explain concepts thoroughly and provide examples when appropriate."
            
            return UserDefaults.standard.string(forKey: Keys.position) ?? defaultContext
        }
        set {
            // Enforce character limit - maximum of 2000 characters
            let limitedValue = String(newValue.prefix(2000))
            UserDefaults.standard.set(limitedValue, forKey: Keys.position)
        }
    }
    
    // Voice/Whisper-specific context
    var voiceContext: String {
        get {
            // If not set, provide a voice-specific default
            let defaultVoiceContext = "You are responding to transcribed voice input. Prioritize concise responses. " +
                                     "Be forgiving of transcription errors and unclear phrases."
            
            return UserDefaults.standard.string(forKey: Keys.voiceContext) ?? defaultVoiceContext
        }
        set {
            // Enforce character limit
            let limitedValue = String(newValue.prefix(2000))
            UserDefaults.standard.set(limitedValue, forKey: Keys.voiceContext)
        }
    }
    
    // Screenshot-specific context
    var screenshotContext: String {
        get {
            // If not set, provide a screenshot-specific default that includes the enhanced coding focus
            let defaultScreenshotContext = """
            You are a highly skilled assistant analyzing images and screenshots. When analyzing images, you specialize in:
            1. Recognizing programming problems, code, and technical content
            2. Providing complete, working solutions to coding problems
            3. Explaining algorithms and their time/space complexity
            4. Offering code implementations in the appropriate language
            
            When you see a programming problem, provide the full solution code with explanations, not just a description of what's in the image. Always include the optimal solution and its time/space complexity analysis.
            """
            
            return UserDefaults.standard.string(forKey: Keys.screenshotContext) ?? defaultScreenshotContext
        }
        set {
            // Enforce character limit
            let limitedValue = String(newValue.prefix(2000)) // Allow 2000 characters for screenshot context
            UserDefaults.standard.set(limitedValue, forKey: Keys.screenshotContext)
        }
    }
    
    // Text input-specific context
    var textContext: String {
        get {
            // If not set, provide a text-specific default
            let defaultTextContext = "You are responding to text input in a conversation. " +
                                    "Provide helpful, concise answers based on the user's query."
            
            return UserDefaults.standard.string(forKey: Keys.textContext) ?? defaultTextContext
        }
        set {
            // Enforce character limit
            let limitedValue = String(newValue.prefix(2000))
            UserDefaults.standard.set(limitedValue, forKey: Keys.textContext)
        }
    }
    
    // MARK: - Reset Settings
    
    func resetAll() {
        UserDefaults.standard.removeObject(forKey: Keys.apiKey)
        // Model key removed since we're only using GPT-4o
        UserDefaults.standard.removeObject(forKey: Keys.windowTransparency)
        UserDefaults.standard.removeObject(forKey: Keys.position)
        UserDefaults.standard.removeObject(forKey: Keys.voiceContext)
        UserDefaults.standard.removeObject(forKey: Keys.screenshotContext)
        UserDefaults.standard.removeObject(forKey: Keys.textContext)
    }
}
