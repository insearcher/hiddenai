//
//  WindowManager.swift
//  HiddenWindowMCP
//
//  Created by Maxim Frolov on 4/8/25.
//

import SwiftUI
import AppKit
import Cocoa

class WindowManager: NSObject, WindowManagerProtocol {
    var window: NSWindow?
    private var globalKeyboardMonitor: Any?
    private var localKeyboardMonitor: Any?
    private let moveDistance: CGFloat = 50 // Increased from 20 to make keyboard movement more effective
    private var isWindowHidden: Bool = false // Track window visibility state
    
    // Dependencies
    private let audioService: AudioServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private let settingsManager: SettingsManagerProtocol
    
    // Initialize with dependencies
    init(audioService: AudioServiceProtocol, notificationService: NotificationServiceProtocol, settingsManager: SettingsManagerProtocol) {
        self.audioService = audioService
        self.notificationService = notificationService
        self.settingsManager = settingsManager
        
        super.init()
        
        // Listen for window transparency change notifications
        notificationService.addObserver(
            self,
            selector: #selector(handleTransparencyChange),
            name: .windowTransparencyChanged,
            object: nil
        )
    }
    
    // Convenience initializer for backward compatibility during transition to DI
    convenience override init() {
        // Fallback to shared instances during transition to DI
        let audioService = DIContainer.shared.resolve(AudioServiceProtocol.self) ?? AudioRecorder()
        let notificationService = DIContainer.shared.resolve(NotificationServiceProtocol.self) ?? DefaultNotificationService()
        let settingsManager = DIContainer.shared.resolve(SettingsManagerProtocol.self) ?? SettingsManager.shared
        
        self.init(audioService: audioService, notificationService: notificationService, settingsManager: settingsManager)
    }
    
    @objc func handleTransparencyChange(_ notification: Notification) {
        if let userInfo = notification.object as? [String: Double],
           let transparency = userInfo["transparency"],
           let window = self.window {
            
            // Apply transparency value (1.0 = fully opaque, 0.0 = fully transparent)
            // We invert the slider value to match user expectation (0% = fully opaque)
            let alphaValue = 1.0 - transparency
            window.alphaValue = CGFloat(alphaValue)
            
            print("Window transparency updated to: \(transparency) (alpha: \(alphaValue))")
        }
    }
    
    @objc func toggleWindowVisibility() {
        guard let window = self.window else { 
            print("ERROR: Cannot toggle window visibility - window is nil")
            return 
        }
        
        // Toggle window visibility state
        isWindowHidden = !isWindowHidden
        print("WindowManager.toggleWindowVisibility() called - changing to \(isWindowHidden ? "hidden" : "visible")")
        
        if isWindowHidden {
            // First save the window's current position and size
            let frame = window.frame
            
            // Hide the window without disposing it - this preserves its content
            window.orderOut(nil)
            print("Window hidden while preserving content")
        } else {
            // For showing, make sure window is visible and in front
            window.makeKeyAndOrderFront(nil)
            
            // Force activate the app to ensure it gets focus
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            // Wait a brief moment before making it main to avoid event loops
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !self.isWindowHidden { // Double-check we haven't toggled again
                    window.makeMain()
                    window.makeKey() // Ensure it has keyboard focus
                    print("Window shown and activated")
                    
                    // Post a notification to focus text field if needed
                    self.notificationService.post(name: .focusTextFieldNotification, object: nil)
                }
            }
        }
    }
    
    /// Explicitly hide the window without destroying content
    func hideWindow() {
        guard let window = self.window else { return }
        
        // Save window state if needed
        // let frame = window.frame
        
        // Hide the window without destroying it
        window.orderOut(nil)
        isWindowHidden = true
        print("Window explicitly hidden (content preserved)")
    }
    
    func createTransparentWindow() -> NSWindow {
        // Set a fixed window size of 400x300
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 300
        
        // Get screen dimensions for centering
        let screenSize = NSScreen.main?.frame.size ?? .zero
        
        // Calculate position (centered on screen)
        let xPos = (screenSize.width - windowWidth) / 2
        let yPos = (screenSize.height - windowHeight) / 2
        
        // Create the window with minimal style mask to reduce visibility
        let window = NSWindow(
            contentRect: NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Set window properties
        window.title = "Hidden AI"
        window.backgroundColor = NSColor.black.withAlphaComponent(0.0) // Fully transparent background
        window.isOpaque = false                          // Make the window not opaque
        
        // Set minimum size constraint to maintain dimensions
        window.minSize = NSSize(width: 400, height: 300)
        
        // Enforce content size
        window.setContentSize(NSSize(width: windowWidth, height: windowHeight))
        
        // Get transparency from settings or use default (1.0 for fully opaque)
        let transparency = settingsManager.windowTransparency
        let alphaValue = transparency > 0 ? 1.0 - transparency : 1.0 // Default to opaque if not set
        window.alphaValue = CGFloat(alphaValue)
        
        window.hasShadow = false                         // Remove shadow
        
        // Apply basic security settings - we'll apply the full security later in showWindow
        applyBasicSecurity(to: window)
        
        // Window should be interactive by default
        window.ignoresMouseEvents = false
        
        return window
    }
    
    @discardableResult
    func showWindow<Content: View>(with rootView: Content) -> NSWindow {
        // Create the window if it doesn't exist
        if window == nil {
            window = createTransparentWindow()
        }
        
        // Set the content view using SwiftUI's hosting controller
        let hostingController = NSHostingController(rootView: rootView)
        
        // Make the background of the hosting view controller transparent
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Allow the content view to receive mouse events
        // hostingController.view.allowedTouchTypes = [] // This line was preventing mouse interaction
        
        window?.contentViewController = hostingController
        
        // Ensure content size is maintained even after content view is set (800x600)
        if let window = window {
            window.setContentSize(NSSize(width: 400, height: 300))
            
            // Pin size to prevent autoresizing
            let windowFrame = window.frame
            window.setFrame(windowFrame, display: true)
        }
        
        // Secure the window from screen capture using the improved WindowSecurityManager
        window?.secure()
        
        // Show the window and make it key window to receive keyboard events
        window?.makeKeyAndOrderFront(nil)
        window?.becomeKey()
        
        // Ensure window is on all spaces
        window?.collectionBehavior.insert(.canJoinAllSpaces)
        
        // We no longer need to apply accessibility security as it can interfere with mouse interaction
        // WindowSecurityManager.applySecurityTechnique(.accessibilityHidden, to: window!)
        
        // Setup keyboard monitoring
        setupKeyboardMonitoring()
        
        return window!
    }
    
    func setupKeyboardMonitoring() {
        // Remove existing monitors if any
        if let existingMonitor = globalKeyboardMonitor {
            NSEvent.removeMonitor(existingMonitor)
        }
        
        if let existingMonitor = localKeyboardMonitor {
            NSEvent.removeMonitor(existingMonitor)
        }
        
        // Create a local monitor that handles window-specific keyboard shortcuts
        // and passes application shortcuts to AppDelegate
        localKeyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Get the first responder
            let firstResponder = self.window?.firstResponder
            let isEditingTextField = firstResponder is NSTextField || firstResponder is NSTextView
            
            // Check for Fn+Command key modifier
            if event.modifierFlags.contains(.function) && event.modifierFlags.contains(.command) {
                // Handle app-level Fn+command shortcuts
                switch event.keyCode {
                    case 11: // Fn+Cmd+B (window visibility)
                        print("WindowManager passing Fn+Cmd+B to application")
                        return event
                    case 12: // Fn+Cmd+Q (quit)
                        return event
                    case 15: // Fn+Cmd+R (Whisper transcription)
                        print("WindowManager passing Fn+Cmd+R to application")
                        return event
                    case 2: // Fn+Cmd+D (clear chat)
                        print("WindowManager passing Fn+Cmd+D to application")
                        return event
                    case 123, 124, 125, 126: // Arrow keys with Fn+Cmd for window movement
                        if self.handleKeyEvent(event) {
                            // If we handled the arrow key movement, don't pass it along
                            return nil
                        }
                        return event
                    default:
                        // For other Fn+command combinations in text fields, let them pass through
                        if isEditingTextField {
                            return event
                        }
                        // Otherwise, ignore other Fn+command combinations
                        return nil
                }
            }
            
            // If typing in a text field, let all regular typing go through
            if isEditingTextField {
                return event
            }
            
            // For all other keys, pass the event through
            return event
        }
        
        // We still need a global monitor to capture Fn+Cmd+Arrow for window movement
        // when the application doesn't have focus
        globalKeyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            // Only handle Fn+Command+Arrow combinations for window movement
            if event.modifierFlags.contains(.function) && event.modifierFlags.contains(.command) {
                switch event.keyCode {
                    case 123, 124, 125, 126: // Arrow keys
                        self.handleKeyEvent(event)
                    default:
                        break
                }
            }
        }
        
        // Make the window key window to receive keyboard events
        if window?.canBecomeKey == true {
            window?.makeKey()
        }
        
        print("WindowManager: Keyboard monitoring setup completed with Fn+Cmd+Arrow support")
    }
    
    // Focus detection is no longer needed since we only use Command key combinations
    
    @discardableResult
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let window = self.window else { return false }
        
        // Debug info
        print("Key pressed in WindowManager: \(event.keyCode), flags: \(event.modifierFlags)")
        
        // Pass specific Fn+command shortcuts to AppDelegate
        if event.modifierFlags.contains(.function) && event.modifierFlags.contains(.command) {
            // For Fn+Cmd+B (window visibility toggle), pass it through to the AppDelegate handler
            if event.keyCode == 11 {
                print("WindowManager detected Fn+Cmd+B, allowing AppDelegate to handle it")
                return false
            }
            
            // Pass Whisper transcription to AppDelegate (Fn+Cmd+R)
            if event.keyCode == 15 {
                print("WindowManager detected Fn+Cmd+R, allowing AppDelegate to handle it")
                return false
            }
            
            // Pass clear chat to AppDelegate (Fn+Cmd+D)
            if event.keyCode == 2 {
                print("WindowManager detected Fn+Cmd+D, allowing AppDelegate to handle it")
                return false
            }
            
            // Handle Fn+Command+Arrow keys for window movement
            // Only proceed if it's an arrow key
            switch event.keyCode {
                case 123, 124, 125, 126: // Arrow keys
                    // Get current frame
                    var frame = window.frame
                    
                    // Move window based on arrow key
                    switch event.keyCode {
                        case 123: // Left arrow
                            print("Moving window left with Fn+Cmd+Left Arrow")
                            frame.origin.x -= moveDistance
                        case 124: // Right arrow
                            print("Moving window right with Fn+Cmd+Right Arrow")
                            frame.origin.x += moveDistance
                        case 125: // Down arrow
                            print("Moving window down with Fn+Cmd+Down Arrow")
                            frame.origin.y -= moveDistance
                        case 126: // Up arrow
                            print("Moving window up with Fn+Cmd+Up Arrow")
                            frame.origin.y += moveDistance
                        default:
                            return false
                    }
                    
                    // Keep window within screen bounds
                    if let screenFrame = NSScreen.main?.visibleFrame {
                        // Make sure the window doesn't move completely off screen
                        frame.origin.x = max(screenFrame.minX - frame.width + 100, min(frame.origin.x, screenFrame.maxX - 100))
                        frame.origin.y = max(screenFrame.minY - frame.height + 100, min(frame.origin.y, screenFrame.maxY - 100))
                    }
                    
                    // Set new frame (which moves the window)
                    window.setFrame(frame, display: true)
                    return true
                default:
                    break
            }
        }
        
        // We only handle Fn+Cmd+Arrow combinations now
        return false
    }
    

    // Apply basic security settings to a window
    private func applyBasicSecurity(to window: NSWindow) {
        // Apply essential security techniques individually
        
        // Set a window level that's typically excluded from screen recording
        WindowSecurityManager.applySecurityTechnique(.specialWindowLevel, to: window)
        
        // Set specific collection behaviors
        WindowSecurityManager.applySecurityTechnique(.specialCollectionBehavior, to: window)
        
        // Exclude from window menu
        WindowSecurityManager.applySecurityTechnique(.windowMenuExclusion, to: window)
        
        // Set sharing type to none
        WindowSecurityManager.applySecurityTechnique(.sharingTypeNone, to: window)
    }
    
    // Restored functionality to toggle click-through mode
    public func toggleClickThroughMode() {
        guard let window = self.window else { return }
        
        // Toggle ignoresMouseEvents to enable/disable click-through mode
        let isClickThrough = !window.ignoresMouseEvents
        window.ignoresMouseEvents = isClickThrough
        
        let statusText = isClickThrough ? "Click-through mode enabled" : "Click-through mode disabled"
        
        // Create a temporary overlay label to show message
        let overlayLabel = NSTextField(string: statusText)
        overlayLabel.isEditable = false
        overlayLabel.isSelectable = false
        overlayLabel.isBezeled = false
        overlayLabel.drawsBackground = true
        overlayLabel.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        overlayLabel.textColor = NSColor.white
        overlayLabel.alignment = .center
        overlayLabel.font = NSFont.boldSystemFont(ofSize: 14)
        
        // Position at the top of the window
        if let contentView = window.contentView {
            let labelWidth: CGFloat = 300
            let labelHeight: CGFloat = 30
            let xPos = (contentView.bounds.width - labelWidth) / 2
            overlayLabel.frame = NSRect(x: xPos, y: contentView.bounds.height - labelHeight - 20, 
                                      width: labelWidth, height: labelHeight)
            
            // Add to view
            contentView.addSubview(overlayLabel)
            
            // Remove after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                overlayLabel.removeFromSuperview()
            }
        }
        
        // Notify about click-through mode change
        notificationService.post(
            name: .clickThroughModeChanged,
            object: ["isClickThrough": isClickThrough]
        )
        
        print("Click-through mode \(isClickThrough ? "enabled" : "disabled")")
    }
    
    deinit {
        // Clean up monitors when the manager is deallocated
        if let monitor = globalKeyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        if let monitor = localKeyboardMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Remove notification observers
        notificationService.removeObserver(self)
    }
}
