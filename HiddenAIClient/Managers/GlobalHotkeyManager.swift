//
//  GlobalHotkeyManager.swift
//  HiddenWindowMCP
//
//  Created on 4/10/25.
//

import Cocoa
import Carbon

/// A manager class that registers and handles global hotkeys that work system-wide,
/// even when the application doesn't have focus.
class GlobalHotkeyManager {
    // Singleton instance
    static let shared = GlobalHotkeyManager()
    
    // EventHotKeyRef for the registered hotkeys
    private var toggleWindowHotKeyRef: EventHotKeyRef?
    
    // Unique IDs for our hotkeys
    private enum HotKeyID: UInt32 {
        case toggleWindow = 1
    }
    
    // Private initializer for singleton
    private init() {}
    
    // Register global hotkeys - simplified to only try Cmd+B
    func registerHotkeys() {
        // Only try to register Cmd+B as it's the primary shortcut we need
        let registered = tryRegisterHotkey(keyCode: 11, modifiers: UInt32(1 << 8), name: "Cmd+B")
        
        if !registered {
            // If unable to register Cmd+B, try Cmd+Opt+B as a fallback
            _ = tryRegisterHotkey(keyCode: 11, modifiers: UInt32(1 << 8 | 1 << 11), name: "Cmd+Opt+B")
        }
        
        // Install event handler even if registration fails
        installEventHandler()
    }
    
    // Unregister all global hotkeys
    func unregisterHotkeys() {
        if let hotKeyRef = toggleWindowHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            toggleWindowHotKeyRef = nil
            print("Unregistered global hotkey")
        }
    }
    
    // Try to register a hotkey with given parameters
    private func tryRegisterHotkey(keyCode: UInt32, modifiers: UInt32, name: String) -> Bool {
        // Create the hotkey ID
        var toggleWindowHotKeyID = EventHotKeyID()
        toggleWindowHotKeyID.signature = OSType(bitPattern: 0x4852444D) // 'HRDM' signature
        toggleWindowHotKeyID.id = HotKeyID.toggleWindow.rawValue
        
        // Register the hotkey
        var result = RegisterEventHotKey(
            keyCode,
            modifiers,
            toggleWindowHotKeyID,
            GetApplicationEventTarget(),
            0,
            &toggleWindowHotKeyRef
        )
        
        if result == noErr {
            print("Successfully registered \(name) hotkey for window toggling")
            return true
        } else {
            print("Failed to register \(name) hotkey. Error: \(result)")
            
            // If error is -9878 (eventHotKeyExistsErr), the key is already registered by another app
            if result == -9878 {
                print("This hotkey is already registered by another application")
            }
            
            return false
        }
    }
    
    // Install event handler for processing hotkey events
    private func installEventHandler() {
        // Define the event types we want to handle
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // Install the callback handler
        let callback: EventHandlerUPP = { (_, eventRef, userData) -> OSStatus in
            guard let eventRef = eventRef else { return OSStatus(eventNotHandledErr) }
            
            // Extract the hotkey ID
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                eventRef,
                UInt32(kEventParamDirectObject),
                UInt32(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if err != noErr {
                print("Error getting hotkey ID: \(err)")
                return err
            }
            
            // Determine which hotkey was pressed
            switch hotKeyID.id {
            case HotKeyID.toggleWindow.rawValue:
                print("Global hotkey detected - toggling window visibility")
                
                // Post a notification to toggle the window
                DispatchQueue.main.async {
                    print("GlobalHotkeyManager: Starting toggle sequence")
                    
                    // First unhide the application if needed
                    NSApp.unhide(nil)
                    
                    // Then try to make the app active to ensure it can handle commands
                    NSApp.activate(ignoringOtherApps: true)
                    print("GlobalHotkeyManager: Activated app")
                    
                    // Force a better delay to make sure activation completes before we toggle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        // Then send command to toggle window visibility using the protocol
                        if let appDelegate = DIContainer.shared.resolve(AppDelegateProtocol.self) {
                            print("GlobalHotkeyManager: Calling toggleWindowVisibility on AppDelegate")
                            appDelegate.toggleWindowVisibility()
                        } else if let appDelegate = NSApp.delegate as? AppDelegateProtocol {
                            // Fallback to NSApp.delegate but using the protocol
                            print("GlobalHotkeyManager: Calling toggleWindowVisibility on AppDelegate (fallback)")
                            appDelegate.toggleWindowVisibility()
                        } else {
                            print("ERROR: GlobalHotkeyManager could not get AppDelegate")
                        }
                    }
                }
                
                return noErr
                
            default:
                return OSStatus(eventNotHandledErr)
            }
        }
        
        // Create and install the event handler
        var handlerRef: EventHandlerRef?
        let err = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            nil,
            &handlerRef
        )
        
        if err != noErr {
            print("Failed to install event handler. Error: \(err)")
        } else {
            print("Successfully installed event handler for hotkeys")
        }
    }
}
