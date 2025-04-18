//
//  DIRegistrar.swift
//  HiddenWindowMCP
//
//  Created on 4/11/25.
//

import Foundation
import SwiftUI

/// Class responsible for registering all services with the DI container
class DIRegistrar {
    /// Configures all dependencies in the DI container
    static func configure() {
        let container = DIContainer.shared
        
        // System services - no dependencies
        registerSystemServices(in: container)
        
        // Core services - depend on system services
        registerCoreServices(in: container)
        
        // Feature services - depend on core services
        registerFeatureServices(in: container)
        
        print("DI container configured with all services")
    }
    
    /// Register system-level services (no dependencies)
    private static func registerSystemServices(in container: DIContainer) {
        // NotificationService - facade for NotificationCenter
        let notificationService = DefaultNotificationService()
        container.registerSingleton(NotificationServiceProtocol.self, instance: notificationService)
        
        print("System services registered")
    }
    
    /// Register core services (may depend on system services)
    private static func registerCoreServices(in container: DIContainer) {
        // Get system services
        let notificationService = container.resolve(NotificationServiceProtocol.self)!
        
        // SettingsManager
        let settingsManager = SettingsManager(notificationService: notificationService)
        container.registerSingleton(SettingsManagerProtocol.self, instance: settingsManager)
        
        // PermissionManager
        let permissionManager = PermissionManager(notificationService: notificationService)
        container.registerSingleton(PermissionManagerProtocol.self, instance: permissionManager)
        
        print("Core services registered")
    }
    
    /// Register feature services (depend on core services)
    private static func registerFeatureServices(in container: DIContainer) {
        // Get dependencies
        let notificationService = container.resolve(NotificationServiceProtocol.self)!
        let settingsManager = container.resolve(SettingsManagerProtocol.self)!
        let permissionManager = container.resolve(PermissionManagerProtocol.self)!
        
        // OpenAIClient
        let openAIClient = OpenAIClient(settingsManager: settingsManager, notificationService: notificationService)
        container.registerSingleton(OpenAIClientProtocol.self, instance: openAIClient)
        
        // AudioRecorder
        let audioRecorder = AudioRecorder(notificationService: notificationService, permissionManager: permissionManager)
        container.registerSingleton(AudioServiceProtocol.self, instance: audioRecorder)
        
        // WhisperTranscriptionService
        let whisperService = WhisperTranscriptionService(
            permissionManager: permissionManager,
            openAIClient: openAIClient,
            notificationService: notificationService
        )
        container.registerSingleton(WhisperTranscriptionServiceProtocol.self, instance: whisperService)
        
        // ScreenshotService
        let screenshotService = ScreenshotService(
            openAIClient: openAIClient,
            notificationService: notificationService,
            permissionManager: permissionManager
        )
        container.registerSingleton(ScreenshotServiceProtocol.self, instance: screenshotService)
        
        // WindowManager
        let windowManager = WindowManager(
            audioService: audioRecorder,
            notificationService: notificationService,
            settingsManager: settingsManager
        )
        container.registerSingleton(WindowManagerProtocol.self, instance: windowManager)
        
        // Register the AppDelegate as a singleton once it's created
        // This will be done in the HiddenAIClientApp.swift
        
        print("Feature services registered")
    }
    
    /// Create a view factory for SwiftUI views
    static func createViewFactory() -> ViewFactory {
        return ViewFactory()
    }
}

/// Factory for creating SwiftUI views with dependencies injected
class ViewFactory {
    /// Create a conversation view with dependencies
    func makeConversationView() -> some View {
        return ConversationView()
    }
    
    /// Create a settings view with dependencies
    func makeSettingsView() -> some View {
        return SettingsView()
    }
}
