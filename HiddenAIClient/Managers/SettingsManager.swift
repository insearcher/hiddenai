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
    
    // MARK: - Position Settings
    
    var position: String {
        get {
            // If no custom context is set, provide a helpful default for first-time users
            let defaultContext = "You are a helpful assistant that provides clear, informative responses. " + 
                                "Explain concepts thoroughly and provide examples when appropriate."
            
            return UserDefaults.standard.string(forKey: Keys.position) ?? defaultContext
        }
        set {
            // Enforce character limit - maximum of 1000 characters
            let limitedValue = String(newValue.prefix(1000))
            UserDefaults.standard.set(limitedValue, forKey: Keys.position)
        }
    }
    
    // MARK: - Reset Settings
    
    func resetAll() {
        UserDefaults.standard.removeObject(forKey: Keys.apiKey)
        // Model key removed since we're only using GPT-4o
        UserDefaults.standard.removeObject(forKey: Keys.windowTransparency)
        UserDefaults.standard.removeObject(forKey: Keys.position)
    }
}
