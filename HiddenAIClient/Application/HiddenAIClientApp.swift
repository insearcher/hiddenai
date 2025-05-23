//
//  HiddenAIClientApp.swift
//  HiddenAIClient
//
//  Created by Maxim Frolov on 4/8/25.
//  Updated to use SystemAudioRecorder for system + microphone audio recording
//  Updated all keyboard shortcuts to use Fn+Cmd+ combinations
//  Updated Whisper shortcut to Fn+Cmd+R and added Fn+Cmd+D for clear chat
//

import SwiftUI
import AppKit
import Cocoa
import ScreenCaptureKit

@main
struct HiddenAIClientApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Configure DI container to use system + microphone audio recorder
        DIRegistrar.configure(audioRecorderType: .systemAndMicrophone)
        
        // Register app delegate after it's created by SwiftUI
        // This works because @NSApplicationDelegateAdaptor initializes the delegate
        // before the App struct's init() is called
        DIContainer.shared.registerSingleton(AppDelegateProtocol.self, instance: appDelegate)
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, AppDelegateProtocol {
    // Dependencies - injected through initializer
    private let windowManager: WindowManagerProtocol
    let audioService: AudioServiceProtocol
    private let openAIClient: OpenAIClientProtocol
    private let whisperService: WhisperTranscriptionServiceProtocol
    private let screenshotService: ScreenshotServiceProtocol
    private let permissionManager: PermissionManagerProtocol
    private let notificationService: NotificationServiceProtocol
    private let viewFactory: ViewFactory
    
    // Other variables
    private var keyEventMonitor: Any?
    private var isProcessingToggle = false
    private var windowHidden = false
    private var globalHotkeyManager = GlobalHotkeyManager.shared
    
    // Primary initializer with dependencies
    init(windowManager: WindowManagerProtocol,
         audioService: AudioServiceProtocol,
         openAIClient: OpenAIClientProtocol,
         whisperService: WhisperTranscriptionServiceProtocol,
         screenshotService: ScreenshotServiceProtocol,
         permissionManager: PermissionManagerProtocol,
         notificationService: NotificationServiceProtocol,
         viewFactory: ViewFactory) {
        
        self.windowManager = windowManager
        self.audioService = audioService
        self.openAIClient = openAIClient
        self.whisperService = whisperService
        self.screenshotService = screenshotService
        self.permissionManager = permissionManager
        self.notificationService = notificationService
        self.viewFactory = viewFactory
        
        super.init()
    }
    
    // Convenience initializer for SwiftUI integration with @NSApplicationDelegateAdaptor
    convenience override init() {
        // Safely resolve dependencies from container with better error handling
        guard let windowManager = DIContainer.shared.resolve(WindowManagerProtocol.self) else {
            fatalError("Failed to resolve WindowManagerProtocol")
        }
        guard let audioService = DIContainer.shared.resolve(AudioServiceProtocol.self) else {
            fatalError("Failed to resolve AudioServiceProtocol")
        }
        guard let openAIClient = DIContainer.shared.resolve(OpenAIClientProtocol.self) else {
            fatalError("Failed to resolve OpenAIClientProtocol")
        }
        guard let whisperService = DIContainer.shared.resolve(WhisperTranscriptionServiceProtocol.self) else {
            fatalError("Failed to resolve WhisperTranscriptionServiceProtocol")
        }
        guard let screenshotService = DIContainer.shared.resolve(ScreenshotServiceProtocol.self) else {
            fatalError("Failed to resolve ScreenshotServiceProtocol")
        }
        guard let permissionManager = DIContainer.shared.resolve(PermissionManagerProtocol.self) else {
            fatalError("Failed to resolve PermissionManagerProtocol")
        }
        guard let notificationService = DIContainer.shared.resolve(NotificationServiceProtocol.self) else {
            fatalError("Failed to resolve NotificationServiceProtocol")
        }
        
        let viewFactory = DIRegistrar.createViewFactory()
        
        self.init(
            windowManager: windowManager,
            audioService: audioService,
            openAIClient: openAIClient,
            whisperService: whisperService,
            screenshotService: screenshotService,
            permissionManager: permissionManager,
            notificationService: notificationService,
            viewFactory: viewFactory
        )
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Allow app to be interactive and appear in dock for better keyboard handling
        ProcessInfo.processInfo.automaticTerminationSupportEnabled = true
        
        // Use .accessory to hide app from dock while maintaining functionality
        NSApp.setActivationPolicy(.accessory)
        
        // Setup direct reference to app delegate in ScreenshotService
        screenshotService.setAppDelegate(self)
        
        // Show main conversation view
        windowManager.showWindow(with: viewFactory.makeConversationView())
        print("Open source mode: Showing main UI")
        
        // Set up global key event monitoring
        setupKeyEventMonitoring()
        
        // Request accessibility permissions for hotkeys to work
        AccessibilityPermissions.requestAccessibilityPermissions()
        
        // Register global hotkeys that work system-wide even when app doesn't have focus
        globalHotkeyManager.registerHotkeys()
        
        // Request all required permissions at startup
        requestAppPermissions()
        
        // Listen for screenshot capture requests - pass notification to handle context
        notificationService.addObserver(
            self,
            selector: #selector(captureScreenshot(_:)),
            name: .captureScreenshotRequested,
            object: nil
        )
        
        // Pre-request screen capture permission (needed for system audio)
        permissionManager.requestScreenCapturePermission { granted in
            print("Screen capture permission \(granted ? "granted" : "denied")")
            
            if granted {
                print("System audio recording is now available")
            } else {
                print("System audio recording requires screen capture permission")
            }
        }
        
        // Perform additional setup after a slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.ensureAppIsHidden()
            
            // Reset the window hidden state to false on startup
            // This ensures a clean slate for toggling
            self.windowHidden = false
            print("Initial window hidden state reset to false")
        }
    }
    
    private func setupKeyEventMonitoring() {
        // Using both local and global event monitors for reliable key detection
        // Updated shortcuts: Fn+Cmd+B, Fn+Cmd+R, Fn+Cmd+P, Fn+Cmd+D, and Fn+Cmd+Q
        
        // Set up a local monitor to catch key events within our own app
        // This works even when text fields have focus
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Only handle Fn+Command key combinations
            let hasFnCommandModifier = event.modifierFlags.contains(.function) && event.modifierFlags.contains(.command)
            if hasFnCommandModifier {
                print("AppDelegate local monitor detected Fn+Command key: \(event.keyCode)")
                
                let handled = self.handleFnCommandKeyCombo(event)
                if handled {
                    return nil // Prevent the event from propagating if we handled it
                }
            }
            
            // Let other key events pass through
            return event
        }
        
        // Store the local monitor
        self.keyEventMonitor = localMonitor
        
        // Also set up a global monitor as a backup for system-wide shortcuts
        // This won't work for text fields but helps catch shortcuts when app doesn't have focus
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            // Only handle Fn+Command key combinations
            let hasFnCommandModifier = event.modifierFlags.contains(.function) && event.modifierFlags.contains(.command)
            if hasFnCommandModifier {
                print("AppDelegate global monitor detected Fn+Command key: \(event.keyCode)")
                self.handleFnCommandKeyCombo(event)
            }
        }
    }
    
    // Helper method to handle Fn+command key combinations
    @discardableResult
    private func handleFnCommandKeyCombo(_ event: NSEvent) -> Bool {
        switch event.keyCode {
            case 11: // Fn+Cmd+B (toggle window visibility)
                print("AppDelegate processing Fn+Cmd+B key - toggling window visibility")
                DispatchQueue.main.async {
                    self.toggleWindowVisibility()
                }
                return true
                
            case 15: // Fn+Cmd+R (toggle Whisper transcription) - changed back to R
                print("AppDelegate processing Fn+Cmd+R key - toggling Whisper transcription")
                DispatchQueue.main.async {
                    self.toggleWhisperTranscription()
                }
                return true
                
            case 35: // Fn+Cmd+P (capture screenshot)
                print("AppDelegate processing Fn+Cmd+P key - capturing screenshot")
                DispatchQueue.main.async {
                    self.captureScreenshot()
                }
                return true
                
            case 2: // Fn+Cmd+D (clear chat history)
                print("AppDelegate processing Fn+Cmd+D key - clearing chat history")
                DispatchQueue.main.async {
                    self.clearChatHistory()
                }
                return true
                
            case 12: // Fn+Cmd+Q (quit app)
                print("AppDelegate processing Fn+Cmd+Q key - quitting app")
                DispatchQueue.main.async {
                    self.quitApp()
                }
                return true
                
            default:
                return false
        }
    }
    
    // Helper to check if the app is currently editing text
    private func isCurrentlyEditingText() -> Bool {
        if let window = NSApplication.shared.keyWindow {
            let firstResponder = window.firstResponder
            return firstResponder is NSTextField || firstResponder is NSTextView
        }
        return false
    }
    
    private func ensureAppIsHidden() {
        // When using .accessory mode, we need to properly activate the window and app
        if let window = windowManager.window {
            // Make sure the window is key and main
            window.makeKeyAndOrderFront(nil)
            window.makeMain()
            
            // Activate the app to ensure it receives events properly
            NSApp.activate(ignoringOtherApps: true)
            
            // Hide the app from dock using LSUIElement (already set in Info.plist)
            // The window will still be visible but the app icon won't appear in dock
            print("AppDelegate: Window activated without showing in dock")
        } else {
            print("ERROR: AppDelegate could not find window to activate")
        }
        
        // Print a message to confirm keyboard shortcut handlers are active
        print("AppDelegate: Keyboard shortcut handlers are set up - shortcuts: Fn+Cmd+B, Fn+Cmd+R, Fn+Cmd+P, Fn+Cmd+D, and Fn+Cmd+Q")
    }
    
    // Add method to toggle Whisper transcription
    @objc func toggleWhisperTranscription() {
        print("AppDelegate toggleWhisperTranscription called")
        
        // Check if we have an API key first
        if !openAIClient.hasApiKey {
            // Show error as notification rather than opening settings
            notificationService.post(
                name: .openaiError, // Use the correct notification name (lowercase 'i')
                object: ["error": "OpenAI API key not set. Please configure in settings."]
            )
            
            // Open settings window to prompt for API key
            DispatchQueue.main.async {
                self.showSettings()
            }
            return
        }
        
        // Toggle Whisper recording through the service
        whisperService.toggleRecording(contextInfo: nil) { result in
            // Handle any errors by broadcasting a notification
            if case .failure(let error) = result {
                self.notificationService.post(
                    name: .whisperTranscriptionError,
                    object: ["error": error.localizedDescription]
                )
            }
            // Success handling is done through notifications in the service
        }
    }
    
    // Add method to show settings window
    @objc func showSettings() {
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        // Create settings view with the view factory
        settingsWindow.contentView = NSHostingView(
            rootView: viewFactory.makeSettingsView()
        )
        
        settingsWindow.center()
        settingsWindow.title = "Settings"
        settingsWindow.makeKeyAndOrderFront(nil)
    }
    
    @objc func toggleWindowVisibility() {
        print("AppDelegate toggleWindowVisibility called")
        
        // Skip if we're already processing a toggle
        if isProcessingToggle {
            print("Toggle already in progress, ignoring duplicate call")
            return
        }
        
        // Set flag to prevent reentrant calls
        isProcessingToggle = true
        
        // Make sure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                // Call self but on main thread
                self.isProcessingToggle = false  // Reset flag since we're recursing
                self.toggleWindowVisibility()
            }
            return
        }
        
        // Ensure app is active before toggling
        NSApp.activate(ignoringOtherApps: true)
        
        // Double check we have a window
        let hasWindow = (windowManager.window != nil)
        print("AppDelegate toggleWindowVisibility - Current hasWindow: \(hasWindow)")
        
        // Call the window manager's method directly
        print("AppDelegate directly calling windowManager.toggleWindowVisibility()")
        if hasWindow {
            // Window exists, proceed with toggling
            windowManager.toggleWindowVisibility()
            
            // Update our window visibility state
            windowHidden = !windowHidden
            print("Window visibility toggled - now \(windowHidden ? "hidden" : "visible")")
        } else {
            print("ERROR: Window is nil, attempting to recreate it")
            // If window doesn't exist, try to recreate it
            windowManager.showWindow(with: viewFactory.makeConversationView())
            print("Window recreated")
            
            // Wait a moment and then try to toggle visibility again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("Retrying toggle after window recreation")
                self.windowManager.toggleWindowVisibility()
                self.windowHidden = !self.windowHidden
                print("Window visibility toggled after recreation - now \(self.windowHidden ? "hidden" : "visible")")
            }
        }
        
        // Reset the flag after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isProcessingToggle = false
            print("Toggle processing completed")
        }
    }
    
    /// Check if the window is currently hidden
    func isWindowHidden() -> Bool {
        return windowHidden
    }
    
    /// Explicitly hide the window
    func hideWindow() {
        if !windowHidden {
            windowManager.hideWindow()
            windowHidden = true
        }
    }
    
    /// Explicitly show the window (used by screenshot service)
    func restoreWindow() {
        if windowHidden {
            // Use the existing window - don't create a new ConversationView
            if let window = windowManager.window {
                // First ensure the app is unhidden
                NSApplication.shared.unhide(nil)
                
                // For accessory apps, we need to ensure it can be activated
                // Make sure our activation policy allows window to be visible
                if NSApp.activationPolicy() != .regular && NSApp.activationPolicy() != .accessory {
                    // Temporarily switch to accessory if needed
                    NSApp.setActivationPolicy(.accessory)
                }
                
                // Show window without recreating content
                window.makeKeyAndOrderFront(nil)
                window.makeMain()
                
                // Activate app with force to ensure it gets focus
                NSApplication.shared.activate(ignoringOtherApps: true)
                
                // Update state
                windowHidden = false
                print("Window restored without recreating content")
            } else {
                // Only create a new window if we don't have one
                windowManager.showWindow(with: viewFactory.makeConversationView())
                windowHidden = false
                print("Window was nil, created new window")
            }
        }
    }
    
    /// Capture a screenshot and send it to OpenAI
    @objc func captureScreenshot(_ notification: Notification? = nil) {
        print("AppDelegate captureScreenshot called")
        
        // Check if we have an API key first
        if !openAIClient.hasApiKey {
            // Show error as notification
            notificationService.post(
                name: .openaiError, // Use the correct notification name (lowercase 'i')
                object: ["error": "OpenAI API key not set. Please configure in settings."]
            )
            
            // Open settings window to prompt for API key
            DispatchQueue.main.async {
                self.showSettings()
            }
            return
        }
        
        // Get context info from notification if available
        var contextInfo: [String: Any]?
        if let notificationObject = notification?.object as? [String: Any] {
            contextInfo = notificationObject
        }
        
        // Broadcast that we're starting the screenshot process
        notificationService.post(name: .screenshotProcessing, object: nil)
        
        // First check if we have screen capture permission
        permissionManager.screenCapturePermissionStatus { [weak self] status in
            guard let self = self else { return }
            
            if status == .authorized {
                // Execute the screenshot capture on the main thread
                DispatchQueue.main.async {
                    let success = self.screenshotService.captureScreenshot(contextInfo: contextInfo)
                    if !success {
                        print("Failed to capture screenshot")
                    }
                }
            } else {
                // Request permission
                self.permissionManager.requestScreenCapturePermission { [weak self] granted in
                    guard let self = self else { return }
                    
                    if granted {
                        // Execute on main thread after permission granted
                        DispatchQueue.main.async {
                            let success = self.screenshotService.captureScreenshot(contextInfo: contextInfo)
                            if !success {
                                print("Failed to capture screenshot")
                            }
                        }
                    } else {
                        print("Screen capture permission denied")
                        // Notify user about permission denied
                        DispatchQueue.main.async {
                            self.notificationService.post(
                                name: .screenshotError,
                                object: ["error": "Screen capture permission denied. Please enable in System Settings."]
                            )
                        }
                    }
                }
            }
        }
    }
    
    @objc func quitApp() {
        // Stop monitoring key events
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Unregister global hotkeys
        globalHotkeyManager.unregisterHotkeys()
        
        // Stop any active services
        whisperService.stopRecordingAndTranscribe(contextInfo: nil) { _ in }
        
        // Clean up temporary files before exit
        cleanupTempFiles()
        
        NSApplication.shared.terminate(nil)
    }
    
    /// Clean up all temporary files
    func cleanupTempFiles() {
        // Use TempFileManager to clean up all temporary files
        let deletedCount = TempFileManager.shared.cleanupAllTempFiles()
        
        // Show confirmation dialog
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Cleanup Complete"
            alert.informativeText = "Deleted \(deletedCount) temporary files."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    /// Clear chat history
    @objc func clearChatHistory() {
        print("AppDelegate clearChatHistory called")
        
        // Get the conversation view model and clear the conversation
        if let viewModel = DIContainer.shared.resolve(ConversationViewModel.self) {
            DispatchQueue.main.async {
                viewModel.clearConversation()
                print("Chat history cleared successfully")
            }
        } else {
            print("ERROR: Could not resolve ConversationViewModel to clear chat")
        }
    }
    
    // Request all permissions needed by the app
    private func requestAppPermissions() {
        // Request all permissions through the PermissionManager
        permissionManager.requestAllPermissions { results in
            print("Permission request results: \(results)")
            
            // Only set up permissions, we'll initialize components on demand
            if results[.microphone] != true {
                print("Microphone permission denied - recording functionality will be limited")
            }
            if results[.screenCapture] != true {
                print("Screen capture permission denied - system audio recording will not work")
            }
        }
    }
    
    // DEBUGGING: Add test function to diagnose system audio issues
    @objc private func testSystemAudio() {
        print("\n🔍 DEBUGGING: Testing system audio...")
        PermissionDebugUtility.checkAllPermissions()
        PermissionDebugUtility.testScreenCapturePermission()
    }
    
    // Application lifecycle events
    func applicationWillTerminate(_ notification: Notification) {
        // Ensure hotkeys are unregistered
        globalHotkeyManager.unregisterHotkeys()
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        // No need to unregister hotkeys when app goes to background
        // as we want them to work system-wide
    }
    
    deinit {
        // Clean up event monitor
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Unregister hotkeys
        globalHotkeyManager.unregisterHotkeys()
        
        // Remove notification observers
        notificationService.removeObserver(self)
    }
}
