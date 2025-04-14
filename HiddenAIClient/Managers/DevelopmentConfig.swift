//
//  DevelopmentConfig.swift
//  HiddenWindowMCP
//
//  Created on 4/10/25.
//

import Foundation

/// Configuration options for development mode
struct DevelopmentConfig {
    /// Whether the app is running in development mode
    static let isDevelopmentMode = false
    
    /// Whether to auto-request permissions on launch
    static let autoRequestPermissions = true
    
    /// Whether to log debug messages to console
    static let enableVerboseLogging = false
    
    /// Whether to show developer tools in the UI
    static let showDeveloperTools = false
    
    /// Whether to use persistent permissions
    static let usePersistentPermissions = true
    
    /// The bundle identifier to use for permissions
    static let permissionBundleId = "io.github.insearcher.hiddenai"
}
