//
//  PermissionManagerProtocol.swift
//  HiddenWindowMCP
//
//  Created on 4/11/25.
//

import Foundation

/// Protocol for handling system permissions
protocol PermissionManagerProtocol: SelfResolvable {
    /// Types of permissions managed
    typealias PermissionType = PermissionManager.PermissionType
    
    /// Status of a permission
    typealias PermissionStatus = PermissionManager.PermissionStatus
    
    /// Checks microphone permission status
    /// - Returns: Current permission status
    func microphonePermissionStatus() -> PermissionStatus
    
    /// Checks screen capture permission status
    /// - Parameter completion: Callback with permission status
    func screenCapturePermissionStatus(completion: @escaping (PermissionStatus) -> Void)
    
    /// Requests microphone permission
    /// - Parameter completion: Callback with permission result
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void)
    
    /// Requests screen capture permission
    /// - Parameter completion: Callback with permission result
    func requestScreenCapturePermission(completion: @escaping (Bool) -> Void)
    
    /// Requests all required permissions
    /// - Parameter completion: Callback with results for each permission type
    func requestAllPermissions(completion: @escaping ([PermissionType: Bool]) -> Void)
}
