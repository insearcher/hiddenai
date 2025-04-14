//
//  AccessibilityPermissions.swift
//  HiddenWindowMCP
//
//  Created on 4/10/25.
//

import Cocoa

/// A helper class to check and request accessibility permissions
/// which are required for global hotkeys and screen recording features
class AccessibilityPermissions {
    /// Checks if the application has accessibility permissions
    static func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return accessibilityEnabled
    }
    
    /// Checks permissions and shows a dialog to guide the user if needed
    static func requestAccessibilityPermissions() {
        if !checkAccessibilityPermissions() {
            // Show a dialog guiding the user to enable accessibility permissions
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "HiddenWindowMCP needs accessibility permissions to register global hotkeys that work system-wide. Please go to System Settings → Privacy & Security → Accessibility and enable HiddenWindowMCP."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open system preferences to the accessibility section
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        }
    }
}
