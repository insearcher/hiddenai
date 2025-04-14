//
//  PermissionManager.swift
//  HiddenWindowMCP
//
//  Created on 4/9/25.
//

import Foundation
import AVFoundation
import Speech
import AppKit
import ScreenCaptureKit
// Import for centralized notification handling
import Cocoa

/// A centralized manager for handling all permission requests in the application.
/// This eliminates scattered permission handling code across multiple files.
class PermissionManager: PermissionManagerProtocol {
    // Singleton instance
    static let shared = PermissionManager()
    
    // Use the centralized notification name from NotificationManager
    // This class is itself a centralized manager, so we'll keep our own constant
    // but make sure it matches the one in NotificationManager
    static let permissionStatusChanged = NotificationManager.Names.permissionStatusChanged
    
    // Dependencies
    private let notificationService: NotificationServiceProtocol
    
    // Initialize with dependencies
    init(notificationService: NotificationServiceProtocol) {
        self.notificationService = notificationService
    }
    
    // Convenience initializer for singleton during transition to DI
    private convenience init() {
        // During transition, fallback to default notification service
        let notificationService = DIContainer.shared.resolve(NotificationServiceProtocol.self) ?? DefaultNotificationService()
        self.init(notificationService: notificationService)
    }
    
    // MARK: - Permission Status
    
    /// Represents the current status of a permission
    enum PermissionStatus {
        case notDetermined
        case denied
        case restricted
        case authorized
        case unknown
    }
    
    /// Types of permissions managed by this class
    enum PermissionType: String {
        case microphone
        case screenCapture
    }
    
    // MARK: - Current Status Checking
    
    /// Check the current status of microphone permission
    func microphonePermissionStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .unknown
        }
    }
    
    // Speech recognition permission status method has been removed - now only using Whisper
    
    /// Check the current status of screen capture permission
    func screenCapturePermissionStatus(completion: @escaping (PermissionStatus) -> Void) {
        Task {
            do {
                // This call will trigger permission prompt if not already authorized
                let _ = try await SCShareableContent.current
                
                // If we reach here, permission was granted
                DispatchQueue.main.async {
                    completion(.authorized)
                }
            } catch {
                // Check error to determine permission status
                // The error might not be a specific SCStreamError code, so we need to check the message
                if error.localizedDescription.contains("denied") || 
                   error.localizedDescription.contains("declined") ||
                   error.localizedDescription.contains("not authorized") {
                    DispatchQueue.main.async {
                        completion(.denied)
                    }
                } else {
                    // Other errors might indicate system issues
                    DispatchQueue.main.async {
                        completion(.restricted)
                    }
                }
            }
        }
    }
    
    // MARK: - Permission Requests
    
    /// Request microphone permission
    /// - Parameter completion: Callback with result of the permission request
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        // If already determined, return current status
        if microphonePermissionStatus() != .notDetermined {
            completion(microphonePermissionStatus() == .authorized)
            return
        }
        
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Notify about the permission status change using NotificationService
                self.notificationService.post(
                    name: Self.permissionStatusChanged,
                    object: ["type": PermissionType.microphone.rawValue, "granted": granted]
                )
                
                completion(granted)
                
                // If permission denied, show settings alert
                if !granted {
                    self.showPermissionSettingsAlert(
                        title: "Microphone Access Required",
                        message: "This app needs microphone access to record audio. Please enable it in System Settings → Privacy & Security → Microphone."
                    )
                }
            }
        }
    }
    
    // Speech recognition permission request method has been removed - now only using Whisper
    
    /// Request screen capture permission
    /// - Parameter completion: Callback with result of the permission request
    func requestScreenCapturePermission(completion: @escaping (Bool) -> Void) {
        // Check current status by trying to access screen content
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // This call will trigger the permission prompt if not already authorized
                let _ = try await SCShareableContent.current
                
                // If we reach here, permission was granted
                DispatchQueue.main.async {
                    // Notify about permission status change
                    self.notificationService.post(
                        name: Self.permissionStatusChanged,
                        object: ["type": PermissionType.screenCapture.rawValue, "granted": true]
                    )
                    
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    // Notify about permission status change
                    self.notificationService.post(
                        name: Self.permissionStatusChanged,
                        object: ["type": PermissionType.screenCapture.rawValue, "granted": false]
                    )
                    
                    completion(false)
                    
                    // Show settings alert
                    self.showPermissionSettingsAlert(
                        title: "Screen Recording Access Required",
                        message: "This app needs screen recording access to capture screenshots for AI analysis. Please enable it in System Settings → Privacy & Security → Screen Recording."
                    )
                }
            }
        }
    }
    
    /// Request all required permissions for the app
    /// - Parameter completion: Callback with dictionary of permission types and their granted status
    func requestAllPermissions(completion: @escaping ([PermissionType: Bool]) -> Void) {
        var results = [PermissionType: Bool]()
        let group = DispatchGroup()
        
        // Request microphone permission
        group.enter()
        requestMicrophonePermission { granted in
            results[.microphone] = granted
            group.leave()
        }
        
        // Request screen capture permission
        group.enter()
        requestScreenCapturePermission { granted in
            results[.screenCapture] = granted
            group.leave()
        }
        
        // Call completion when all requests are done
        group.notify(queue: .main) {
            completion(results)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Show an alert guiding the user to system settings
    /// - Parameters:
    ///   - title: Alert title
    ///   - message: Alert message
    private func showPermissionSettingsAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open system settings
            openSystemSettings(for: getPermissionTypeFromTitle(title))
        }
    }
    
    /// Determine permission type from alert title
    private func getPermissionTypeFromTitle(_ title: String) -> PermissionType {
        if title.contains("Microphone") {
            return .microphone
        } else if title.contains("Screen") {
            return .screenCapture
        } else {
            return .microphone // Default case
        }
    }
    
    /// Open system settings for the specific permission type
    /// - Parameter permissionType: Type of permission to open settings for
    private func openSystemSettings(for permissionType: PermissionType) {
        let urlString: String
        
        switch permissionType {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .screenCapture:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
