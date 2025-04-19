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
    
    /// User position/role for default context
    var position: String { get set }
    
    /// Context for voice/Whisper transcriptions
    var voiceContext: String { get set }
    
    /// Context for screenshot analysis
    var screenshotContext: String { get set }
    
    /// Context for text input
    var textContext: String { get set }
    
    /// Resets all settings to default values
    func resetAll()
}
