//
//  ScreenshotServiceProtocol.swift
//  HiddenWindowMCP
//
//  Created on 4/11/25.
//

import Foundation
import AppKit

/// Protocol for screenshot services
protocol ScreenshotServiceProtocol: SelfResolvable {
    /// Sets the app delegate reference for window management
    /// - Parameter delegate: The AppDelegateProtocol instance
    func setAppDelegate(_ delegate: AppDelegateProtocol)
    
    /// Sets context information for the screenshot
    /// - Parameter contextInfo: Dictionary of context information
    func setContextInfo(_ contextInfo: [String: Any]?)
    
    /// Captures a screenshot of the screen
    /// - Parameter contextInfo: Optional context information
    /// - Returns: Success status of capture
    func captureScreenshot(contextInfo: [String: Any]?) -> Bool
}
