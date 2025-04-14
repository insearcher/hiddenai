//
//  WindowSecurityManager.swift
//  HiddenWindowMCP
//
//  Created on 4/9/25.
//

import Cocoa

/// A manager class that handles window security and privacy features,
/// including preventing windows from appearing in screen recordings.
class WindowSecurityManager {
    
    /// Techniques that can be used to secure a window
    enum SecurityTechnique {
        case sharingTypeNone          // Sets window.sharingType = .none
        case specialWindowLevel       // Uses a special window level that's excluded from recordings
        case windowMenuExclusion      // Excludes from window menu and window lists
        case specialCollectionBehavior // Sets specific collection behavior flags
        case accessibilityHidden      // Hides from accessibility tools
    }
    
    /// Constants for window configuration
    private struct Constants {
        // Window level that's typically excluded from screen recordings
        // This level is just below the assistive tech high window level
        static let secureWindowLevel = NSWindow.Level(rawValue: 
            Int(CGWindowLevelForKey(.assistiveTechHighWindow)) - 1)
            
        // Collection behavior for secure windows
        static let secureCollectionBehavior: NSWindow.CollectionBehavior = [
            .transient,              // Hide from Exposé
            .ignoresCycle,           // Skip in Cmd+Tab app switching
            .stationary,             // Don't move when spaces change
            .canJoinAllSpaces        // Show on all spaces
        ]
    }
    
    /// Apply all security techniques to a window to prevent it from appearing
    /// in screen recordings and other system UI elements
    ///
    /// - Parameter window: The window to secure
    /// - Returns: Whether all techniques were successfully applied
    @discardableResult
    static func secureWindow(_ window: NSWindow) -> Bool {
        var success = true
        
        // Apply each technique, collecting any failures
        for technique in getAllTechniques() {
            if !applySecurityTechnique(technique, to: window) {
                success = false
                print("WARNING: Failed to apply security technique: \(technique)")
            }
        }
        
        return success
    }
    
    /// Apply a specific security technique to a window
    ///
    /// - Parameters:
    ///   - technique: The security technique to apply
    ///   - window: The window to secure
    /// - Returns: Whether the technique was successfully applied
    @discardableResult
    static func applySecurityTechnique(_ technique: SecurityTechnique, to window: NSWindow) -> Bool {
        do {
            switch technique {
            case .sharingTypeNone:
                // Set window sharing type to 'none' to hide from screen capture
                window.sharingType = .none
                
            case .specialWindowLevel:
                // Set window level to a level that's often excluded from screen recording
                window.level = Constants.secureWindowLevel
                
            case .windowMenuExclusion:
                // Hide from window list and windows menu
                window.isExcludedFromWindowsMenu = true
                
            case .specialCollectionBehavior:
                // Set specific collection behaviors for security
                window.collectionBehavior = Constants.secureCollectionBehavior
                
            case .accessibilityHidden:
                // Modified to not interfere with mouse interactions
                // Only set accessibility properties that don't affect clickability
                if let contentView = window.contentView {
                    // Don't set these as they can interfere with interaction
                    // contentView.setAccessibilityElement(false)
                    // contentView.setAccessibilityHidden(true)
                    
                    // Alternative approach - just set a role description
                    contentView.setAccessibilityRole(.window)
                    contentView.setAccessibilityRoleDescription("Hidden Window")
                } else {
                    return false
                }
            }
            
            return true
        } catch {
            print("ERROR applying security technique \(technique): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Get all available security techniques
    ///
    /// - Returns: Array of all security techniques
    static func getAllTechniques() -> [SecurityTechnique] {
        return [
            .sharingTypeNone,
            .specialWindowLevel,
            .windowMenuExclusion,
            .specialCollectionBehavior,
            .accessibilityHidden
        ]
    }
    
    /// Check if a window is likely to be secure from screen recording
    ///
    /// - Parameter window: The window to check
    /// - Returns: Whether the window appears to be secure
    static func isWindowSecured(_ window: NSWindow) -> Bool {
        // Check key security properties
        let hasSecureSharingType = window.sharingType == .none
        let hasSecureWindowLevel = window.level == Constants.secureWindowLevel
        let isExcludedFromMenu = window.isExcludedFromWindowsMenu
        
        // Check collection behavior (all required behaviors must be present)
        let hasAllSecureBehaviors = Constants.secureCollectionBehavior.rawValue & window.collectionBehavior.rawValue == Constants.secureCollectionBehavior.rawValue
        
        // Check accessibility properties
        let accessibilitySecured = window.contentView?.isAccessibilityElement() == false
        
        // Window is considered secured if most techniques are applied
        // We don't require all because some might not be applicable in all contexts
        let securityChecks = [
            hasSecureSharingType,
            hasSecureWindowLevel,
            isExcludedFromMenu,
            hasAllSecureBehaviors,
            accessibilitySecured
        ]
        
        // Consider secure if at least 80% of techniques are applied
        let securityScore = securityChecks.filter { $0 }.count
        let requiredScore = Int(Double(securityChecks.count) * 0.8)
        
        return securityScore >= requiredScore
    }
    
    /// Print a diagnostic report of the window's security status
    ///
    /// - Parameter window: The window to diagnose
    static func printSecurityDiagnostics(for window: NSWindow) {
        print("=== Window Security Diagnostics ===")
        print("Window: \(window)")
        print("Window Number: \(window.windowNumber)")
        print("Title: \(window.title)")
        
        // Sharing Type
        let sharingTypeSecure = window.sharingType == .none
        print("Sharing Type: \(window.sharingType) - \(sharingTypeSecure ? "✓" : "✗")")
        
        // Window Level
        let windowLevelSecure = window.level == Constants.secureWindowLevel
        print("Window Level: \(window.level.rawValue) (Secure: \(Constants.secureWindowLevel.rawValue)) - \(windowLevelSecure ? "✓" : "✗")")
        
        // Window Menu Exclusion
        let menuExcluded = window.isExcludedFromWindowsMenu
        print("Excluded from Window Menu: \(menuExcluded) - \(menuExcluded ? "✓" : "✗")")
        
        // Collection Behavior
        let collectionBehaviorRaw = window.collectionBehavior.rawValue
        let requiredBehaviorRaw = Constants.secureCollectionBehavior.rawValue
        let hasRequiredBehaviors = (collectionBehaviorRaw & requiredBehaviorRaw) == requiredBehaviorRaw
        
        print("Collection Behavior:")
        print("  - Transient: \(window.collectionBehavior.contains(.transient) ? "✓" : "✗")")
        print("  - Ignores Cycle: \(window.collectionBehavior.contains(.ignoresCycle) ? "✓" : "✗")")
        print("  - Stationary: \(window.collectionBehavior.contains(.stationary) ? "✓" : "✗")")
        print("  - Can Join All Spaces: \(window.collectionBehavior.contains(.canJoinAllSpaces) ? "✓" : "✗")")
        print("  - Overall: \(hasRequiredBehaviors ? "✓" : "✗")")
        
        // Accessibility
        let accessibilityHidden = window.contentView?.isAccessibilityElement() == false
        print("Accessibility Hidden: \(accessibilityHidden) - \(accessibilityHidden ? "✓" : "✗")")
        
        // Overall Security
        let isSecure = isWindowSecured(window)
        print("Overall Security Status: \(isSecure ? "SECURE ✓" : "NOT SECURE ✗")")
        print("===============================")
    }
}

// Extension to apply security directly to NSWindow
extension NSWindow {
    /// Apply all security techniques to prevent this window from
    /// appearing in screen recordings and other system UI elements
    func secure() {
        WindowSecurityManager.secureWindow(self)
    }
    
    /// Legacy support for the old method name from ScreenCaptureHelper
    func excludeFromScreenCapture() {
        secure()
    }
    
    /// Check if this window is secured from screen recording
    var isSecured: Bool {
        return WindowSecurityManager.isWindowSecured(self)
    }
}
