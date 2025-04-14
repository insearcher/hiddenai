//
//  ScreenshotService.swift
//  HiddenWindowMCP
//
//  Created on 4/10/25.
//

import Cocoa
import Foundation
import SwiftUI
import ScreenCaptureKit
import CoreMedia
import CoreImage

/// A service that handles capturing screenshots and sending them to OpenAI for processing
class ScreenshotService: NSObject, ScreenshotServiceProtocol, SCStreamOutput {
    // Singleton instance
    static let shared = ScreenshotService()
    
    // Reference to the AppDelegate using protocol for better abstraction
    private weak var appDelegate: AppDelegateProtocol?
    
    // Dependencies
    private let openAIClient: OpenAIClientProtocol
    private let notificationService: NotificationServiceProtocol
    private let permissionManager: PermissionManagerProtocol
    
    // Initialize with dependencies
    init(openAIClient: OpenAIClientProtocol, notificationService: NotificationServiceProtocol, permissionManager: PermissionManagerProtocol) {
        self.openAIClient = openAIClient
        self.notificationService = notificationService
        self.permissionManager = permissionManager
        super.init()
    }
    
    // Convenience initializer for singleton during transition to DI
    private convenience override init() {
        // During transition, fallback to shared instances
        let openAIClient = DIContainer.shared.resolve(OpenAIClientProtocol.self) ?? OpenAIClient.shared
        let notificationService = DIContainer.shared.resolve(NotificationServiceProtocol.self) ?? DefaultNotificationService()
        let permissionManager = DIContainer.shared.resolve(PermissionManagerProtocol.self) ?? PermissionManager.shared
        
        self.init(openAIClient: openAIClient, notificationService: notificationService, permissionManager: permissionManager)
    }
    
    // Method to set the AppDelegate reference using protocol
    func setAppDelegate(_ delegate: AppDelegateProtocol) {
        self.appDelegate = delegate
        print("ScreenshotService: AppDelegate reference set successfully")
    }
    
    // MARK: - Screenshot States and Notifications
    
    /// Notification names for screenshot-related events
    enum Notifications {
        static let screenshotCaptured = Notification.Name("ScreenshotCaptured")
        static let screenshotError = Notification.Name("ScreenshotError")
        static let screenshotProcessing = Notification.Name("ScreenshotProcessing")
    }
    
    // MARK: - Screenshot Methods
    
    /// Store context information for the screenshot
    private var currentContextInfo: [String: Any]?
    
    /// Set context information for the screenshot
    /// - Parameter contextInfo: Dictionary of context information
    func setContextInfo(_ contextInfo: [String: Any]?) {
        self.currentContextInfo = contextInfo
    }
    
    /// Take a screenshot of the screen, hiding the app's window
    /// - Returns: Boolean indicating success
    func captureScreenshot(contextInfo: [String: Any]? = nil) -> Bool {
        print("DEBUG: captureScreenshot called")
        
        // If contextInfo is provided, store it
        if let contextInfo = contextInfo {
            setContextInfo(contextInfo)
        }
        
        // This method must be called on the main thread
        assert(Thread.isMainThread, "captureScreenshot must be called on the main thread")
        
        // Get AppDelegate reference (using multiple fallback strategies)
        if self.appDelegate == nil {
            // Try to get from DI container first
            if let appDelegate = DIContainer.shared.resolve(AppDelegateProtocol.self) {
                self.appDelegate = appDelegate
                print("DEBUG: Retrieved AppDelegate from DI container")
            } else if let appDelegate = NSApp.delegate as? AppDelegateProtocol {
                // Fallback to NSApp.delegate but using protocol
                self.appDelegate = appDelegate
                print("DEBUG: Retrieved AppDelegate from NSApp.delegate")
            }
        }
        
        // Check if we have an appDelegate
        guard let appDelegate = self.appDelegate else {
            postScreenshotError("App delegate not available")
            print("DEBUG: AppDelegate reference is nil, could not recover from any source")
            return false
        }
        
        // Skip permission check since it seems unreliable
        // We'll just try the capture directly and let the system handle permission requests
        print("DEBUG: Taking screenshot with fallback method first")
        
        // Let user know we're processing
        notificationService.post(
            name: Notifications.screenshotProcessing,
            object: nil
        )
        
        // Track overall success
        var captureSuccess = false
        var capturedImage: NSImage? = nil
        
        // First try with direct ScreenCaptureKit - this is preferable but sometimes has permission issues
        print("DEBUG: Trying SCKit first...")
        if let screenshot = captureScreen() {
            print("DEBUG: Screenshot captured successfully with SCKit, processing...")
            captureSuccess = true
            capturedImage = screenshot
        }
        
        // If SCKit fails, try command-line
        if !captureSuccess {
            print("DEBUG: SCKit failed, trying command-line method...")
            if let screenshot = captureScreenWithNSBitmapImageRep() {
                print("DEBUG: Screenshot captured successfully with command-line method, processing...")
                captureSuccess = true
                capturedImage = screenshot
            }
        }
        
        // Process the screenshot if we have one
        if let finalImage = capturedImage {
            print("DEBUG: Screenshot captured successfully, processing...")
            processScreenshot(finalImage)
            return true
        } else {
            print("DEBUG: All screenshot capture methods failed")
            postScreenshotError("Failed to capture screenshot with all methods")
            return false
        }
    }
    
    /// Capture the entire screen using ScreenCaptureKit
    /// - Returns: NSImage if successful, nil otherwise
    private func captureScreen() -> NSImage? {
        // Try first with a simple method as fallback
        if let image = captureScreenWithNSBitmapImageRep() {
            print("DEBUG: Used NSBitmapImageRep fallback method")
            return image
        }
        
        print("DEBUG: NSBitmapImageRep fallback failed, trying SCKit...")
        print("DEBUG: Starting screen capture process")
        
        // Use a semaphore to make the async capture synchronous for our method
        let semaphore = DispatchSemaphore(value: 0)
        var capturedImage: NSImage? = nil
        
        // Capture the screenshot on a background queue
        Task {
            do {
                print("DEBUG: Requesting SCShareableContent.current")
                // Get available content and filter to show only screen content
                let availableContent = try await SCShareableContent.current
                print("DEBUG: Got SCShareableContent with \(availableContent.displays.count) displays and \(availableContent.windows.count) windows")
                
                // Filter out our app's window to avoid capturing it
                let contentToExclude = availableContent.windows.filter { window in
                    let isOurApp = window.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
                    if isOurApp {
                        print("DEBUG: Found our app window to exclude: \(window.title)")
                    }
                    return isOurApp
                }
                print("DEBUG: Excluding \(contentToExclude.count) windows from capture")
                
                // Configure the capture with the main display
                guard let mainDisplay = availableContent.displays.first else {
                    print("DEBUG: ERROR - No display found!")
                    semaphore.signal()
                    return
                }
                
                print("DEBUG: Using display: \(mainDisplay.width)x\(mainDisplay.height)")
                
                let configuration = SCStreamConfiguration()
                configuration.width = mainDisplay.width
                configuration.height = mainDisplay.height
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                configuration.queueDepth = 1
                
                // Create a filter to exclude our app's windows
                let filter = SCContentFilter(
                    display: mainDisplay,
                    excludingWindows: contentToExclude
                )
                
                print("DEBUG: Creating stream with filter")
                // Create the stream
                let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
                
                print("DEBUG: Adding stream output")
                // Add a stream output to capture frames
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
                
                print("DEBUG: Starting stream capture")
                // Start the stream - add await here
                try await stream.startCapture()
                print("DEBUG: Stream capture started")
                
                // Wait longer to capture a frame
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Increased timeout further
                    print("DEBUG: Stopping stream capture")
                    // Stop the stream after capturing the frame
                    Task {
                        do {
                            try await stream.stopCapture()
                            print("DEBUG: Stream capture stopped successfully")
                        } catch {
                            print("DEBUG: Error stopping capture: \(error.localizedDescription)")
                        }
                        
                        // If we didn't get an image by now, signal to continue
                        if capturedImage == nil {
                            print("DEBUG: No image captured, signaling to continue")
                            semaphore.signal()
                        }
                    }
                }
            } catch {
                print("DEBUG: Error setting up screen capture: \(error.localizedDescription)")
                semaphore.signal()
            }
        }
        
        print("DEBUG: Setting up capture handler")
        // Store captured image from stream output handler
        self.captureHandler = { image in
            print("DEBUG: Capture handler called with image")
            capturedImage = image
            semaphore.signal()
        }
        
        print("DEBUG: Waiting for capture to complete (timeout: 6.0 seconds)")
        // Increase timeout to wait for capture to complete
        _ = semaphore.wait(timeout: .now() + 6.0)
        
        if capturedImage == nil {
            print("DEBUG: Capture timed out - no image received")
        } else {
            print("DEBUG: Successfully captured screenshot")
        }
        
        self.captureHandler = nil
        
        return capturedImage
    }
    
    // Temporary storage for capture handler
    private var captureHandler: ((NSImage) -> Void)?
    
    /// Process a screenshot by saving it and sending to OpenAI
    /// - Parameter screenshot: The screenshot to process
    private func processScreenshot(_ screenshot: NSImage) {
        // Use TempFileManager to create and track a temporary file
        let tempURL = TempFileManager.shared.createTempFileURL(prefix: "Screenshot", extension: "png")
        
        // Save image to file
        guard let tiffData = screenshot.tiffRepresentation,
              let imageRep = NSBitmapImageRep(data: tiffData),
              let pngData = imageRep.representation(using: .png, properties: [:]) else {
            postScreenshotError("Failed to convert screenshot to PNG data")
            return
        }
        
        do {
            try pngData.write(to: tempURL)
            
            // Notify about captured screenshot with path
            DispatchQueue.main.async {
                var notificationData: [String: Any] = ["path": tempURL.path]
                
                // Add context info if available
                if let contextInfo = self.currentContextInfo {
                    for (key, value) in contextInfo {
                        notificationData[key] = value
                    }
                }
                
                self.notificationService.post(
                    name: Self.Notifications.screenshotCaptured,
                    object: notificationData
                )
            }
            
            // Send to OpenAI
            sendToOpenAI(imageURL: tempURL, contextInfo: currentContextInfo)
            
            // Clear context info after sending
            currentContextInfo = nil
        } catch {
            postScreenshotError("Failed to save screenshot: \(error.localizedDescription)")
        }
    }
    
    /// Send the screenshot to OpenAI for processing
    /// - Parameters:
    ///   - imageURL: The URL of the image file
    ///   - contextInfo: Optional context information for replied messages
    private func sendToOpenAI(imageURL: URL, contextInfo: [String: Any]? = nil) {
        // Notify that processing has begun
        DispatchQueue.main.async {
            self.notificationService.post(
                name: Self.Notifications.screenshotProcessing,
                object: nil
            )
        }
        
        // Create a prompt that includes context if available
        var prompt = "What's in this image?"
        
        // If we have context info, add a note about it
        if contextInfo != nil && (contextInfo?["replyChain"] as? [UUID])?.isEmpty == false {
            prompt = "What's in this image? (This is in response to a previous conversation context)"
        }
        
        // Send to OpenAI via the OpenAIClient - this is network operation so it's ok on background
        openAIClient.sendImageRequest(
            imageURL: imageURL, 
            prompt: prompt,
            contextInfo: contextInfo
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                print("Successfully processed image with OpenAI")
                
                // The response is already handled via notification in OpenAIClient
                
                // Clean up the temporary screenshot file
                DispatchQueue.global(qos: .background).async {
                    TempFileManager.shared.deleteTempFile(imageURL)
                }
                
            case .failure(let error):
                self.postScreenshotError("Error processing image: \(error.localizedDescription)")
                
                // Clean up the temporary screenshot file even on error
                DispatchQueue.global(qos: .background).async {
                    TempFileManager.shared.deleteTempFile(imageURL)
                }
            }
        }
    }
    
    /// Post an error notification
    /// - Parameter message: The error message
    private func postScreenshotError(_ message: String) {
        DispatchQueue.main.async {
            self.notificationService.post(
                name: Self.Notifications.screenshotError,
                object: ["error": message]
            )
        }
    }
    
    // MARK: - SCStreamOutput Implementation
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        print("DEBUG: Stream output callback received. Type: \(type)")
        
        // Only process screen content (not audio)
        guard type == .screen else {
            print("DEBUG: Ignoring non-screen sample buffer")
            return
        }
        
        // Check if we have a valid pixel buffer
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            print("DEBUG: No image buffer in sample buffer")
            return
        }
        
        print("DEBUG: Got image buffer: \(CVPixelBufferGetWidth(imageBuffer))x\(CVPixelBufferGetHeight(imageBuffer))")
        
        // Create a CIImage from the pixel buffer
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        print("DEBUG: Created CIImage: \(ciImage.extent.width)x\(ciImage.extent.height)")
        
        // Convert to CGImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("DEBUG: Failed to create CGImage from CIImage")
            return
        }
        
        print("DEBUG: Created CGImage: \(cgImage.width)x\(cgImage.height)")
        
        // Create NSImage from CGImage
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        print("DEBUG: Created NSImage: \(image.size.width)x\(image.size.height)")
        
        // Call the capture handler
        DispatchQueue.main.async {
            print("DEBUG: Calling capture handler on main thread")
            self.captureHandler?(image)
            print("DEBUG: Capture handler called")
        }
    }
    
    /// Fallback method to capture screen using NSScreen
    private func captureScreenWithNSBitmapImageRep() -> NSImage? {
        print("DEBUG: Trying to capture screen with AppKit")
        
        // Use Process to run screencapture CLI tool, which is more reliable
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture" // Correct path in macOS
        
        // Create a temporary file to save the screenshot
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_screenshot.png")
        
        // Set up arguments to capture silently to the temp file
        // -x: no sound (silent capture)
        task.arguments = ["-x", tempURL.path]
        
        print("DEBUG: Will save temp screenshot to: \(tempURL.path)")
        
        do {
            // Run the screencapture command
            try task.run()
            task.waitUntilExit()
            
            // Check if successful
            if task.terminationStatus == 0 {
                // Wait a moment for the file to be fully written
                Thread.sleep(forTimeInterval: 0.1)
                
                // Load the image from the temp file
                if let image = NSImage(contentsOf: tempURL) {
                    print("DEBUG: Successfully loaded screenshot from temp file: \(image.size.width)x\(image.size.height)")
                    
                    // Clean up the temp file
                    try? FileManager.default.removeItem(at: tempURL)
                    
                    return image
                } else {
                    print("DEBUG: Failed to load image from temp file")
                }
            } else {
                print("DEBUG: screencapture command failed with status: \(task.terminationStatus)")
            }
        } catch {
            print("DEBUG: Error running screencapture: \(error.localizedDescription)")
        }
        
        return nil
    }
}

// Import extension for TempFileManager
extension ScreenshotService {
    // Make TempFileManager available to ScreenshotService
    var tempFileManager: TempFileManager {
        return TempFileManager.shared
    }
}
