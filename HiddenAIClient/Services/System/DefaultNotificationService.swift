//
//  DefaultNotificationService.swift
//  HiddenWindowMCP
//
//  Created on 4/11/25.
//

import Foundation

/// Default implementation of NotificationServiceProtocol using NotificationCenter
class DefaultNotificationService: NotificationServiceProtocol {
    
    /// Posts a notification using NotificationCenter.default
    func post(name: Notification.Name, object: Any?) {
        NotificationCenter.default.post(name: name, object: object)
    }
    
    /// Adds an observer using NotificationCenter.default
    func addObserver(_ observer: Any, selector: Selector, name: Notification.Name?, object: Any?) {
        NotificationCenter.default.addObserver(observer, selector: selector, name: name, object: object)
    }
    
    /// Removes an observer using NotificationCenter.default
    func removeObserver(_ observer: Any) {
        NotificationCenter.default.removeObserver(observer)
    }
    
    /// Adds a block-based observer using NotificationCenter.default
    @discardableResult
    func addObserverForName(_ name: Notification.Name?, object: Any?, queue: OperationQueue?, using handler: @escaping (Notification) -> Void) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: name, object: object, queue: queue, using: handler)
    }
}
