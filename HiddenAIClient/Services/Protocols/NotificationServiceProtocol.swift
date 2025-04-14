//
//  NotificationServiceProtocol.swift
//  HiddenWindowMCP
//
//  Created on 4/11/25.
//

import Foundation

/// Protocol for notification services
protocol NotificationServiceProtocol: SelfResolvable {
    /// Posts a notification
    /// - Parameters:
    ///   - name: Notification name
    ///   - object: Optional object to include with notification
    func post(name: Notification.Name, object: Any?)
    
    /// Adds an observer for notifications
    /// - Parameters:
    ///   - observer: The observer object
    ///   - selector: Method to call on notification
    ///   - name: Notification name to observe
    ///   - object: Optional object to filter notifications
    func addObserver(_ observer: Any, selector: Selector, name: Notification.Name?, object: Any?)
    
    /// Removes an observer
    /// - Parameter observer: Observer to remove
    func removeObserver(_ observer: Any)
    
    /// Add block-based observer
    /// - Parameters:
    ///   - name: Notification name to observe
    ///   - object: Optional object to filter notifications
    ///   - queue: Operation queue for handler execution
    ///   - handler: Block to execute on notification
    /// - Returns: Observer token
    @discardableResult
    func addObserverForName(_ name: Notification.Name?, object: Any?, queue: OperationQueue?, using handler: @escaping (Notification) -> Void) -> NSObjectProtocol
}
