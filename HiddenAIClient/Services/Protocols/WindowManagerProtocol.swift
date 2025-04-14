//
//  WindowManagerProtocol.swift
//  HiddenWindowMCP
//
//  Created on 4/11/25.
//

import Foundation
import SwiftUI
import AppKit

/// Protocol for window management services
protocol WindowManagerProtocol: SelfResolvable {
    /// The main application window
    var window: NSWindow? { get }
    
    /// Creates a transparent window
    /// - Returns: The created NSWindow
    func createTransparentWindow() -> NSWindow
    
    /// Shows a window with the provided SwiftUI root view
    /// - Parameter rootView: The SwiftUI view to display
    /// - Returns: The displayed NSWindow
    @discardableResult
    func showWindow<Content: View>(with rootView: Content) -> NSWindow
    
    /// Toggles window visibility (shows if hidden, hides if visible)
    func toggleWindowVisibility()
    
    /// Explicitly hides the window without destroying content
    func hideWindow()
    
    /// Toggles click-through mode for the window
    func toggleClickThroughMode()
}
