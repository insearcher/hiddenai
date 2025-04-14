//
//  SettingsManagerProtocol.swift
//  HiddenWindowMCP
//
//  Created on 4/11/25.
//

import Foundation

/// Protocol for app settings management
protocol SettingsManagerProtocol: SelfResolvable {
    /// The OpenAI API key
    var apiKey: String { get set }
    
    /// Window transparency value (0.0 - 1.0)
    var windowTransparency: Double { get set }
    
    /// User position/role for interview context
    var position: String { get set }
    
    /// Resets all settings to default values
    func resetAll()
}
