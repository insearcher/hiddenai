//
//  TempFileManager.swift
//  HiddenAIClient
//
//  Created on 4/15/25.
//

import Foundation
import AppKit

/// A manager class for handling temporary files created by the application
/// Ensures proper lifecycle management and cleanup of sensitive data
class TempFileManager {
    
    // Singleton instance
    static let shared = TempFileManager()
    
    // Registry of temporary files created by the application
    private var tempFileRegistry: [URL] = []
    
    // Base directory for app-specific temporary files
    private let appTempDirectory: URL
    
    // Timer for periodic cleanup
    private var cleanupTimer: Timer?
    
    // How often to clean up old files (in seconds)
    private let cleanupInterval: TimeInterval = 3600 // 1 hour
    
    // How old files should be to be considered for cleanup (in seconds)
    private let fileAgeThreshold: TimeInterval = 86400 // 24 hours
    
    private init() {
        // Create a dedicated directory for app temp files
        let tempDir = FileManager.default.temporaryDirectory
        appTempDirectory = tempDir.appendingPathComponent("io.github.insearcher.hiddenai", isDirectory: true)
        
        // Create the directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: appTempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Register for app termination to clean up files
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        
        // Start periodic cleanup timer
        startCleanupTimer()
        
        print("TempFileManager initialized with directory: \(appTempDirectory.path)")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        cleanupTimer?.invalidate()
    }
    
    /// Starts the timer for periodic cleanup of old temporary files
    private func startCleanupTimer() {
        // Stop any existing timer
        cleanupTimer?.invalidate()
        
        // Create a new timer that fires periodically
        cleanupTimer = Timer.scheduledTimer(
            timeInterval: cleanupInterval,
            target: self,
            selector: #selector(periodicCleanup),
            userInfo: nil,
            repeats: true
        )
        
        // Add the timer to the common run loop mode to ensure it fires even when UI is busy
        RunLoop.current.add(cleanupTimer!, forMode: .common)
        
        print("TempFileManager: Started cleanup timer - will clean files older than \(fileAgeThreshold/3600) hours every \(cleanupInterval/3600) hours")
    }
    
    /// Periodic cleanup handler called by the timer
    @objc private func periodicCleanup() {
        print("TempFileManager: Running periodic cleanup")
        DispatchQueue.global(qos: .background).async {
            let deletedCount = self.cleanupOldTempFiles(olderThan: self.fileAgeThreshold)
            print("TempFileManager: Periodic cleanup removed \(deletedCount) old files")
        }
    }
    
    /// Register a file URL that should be tracked for cleanup
    /// - Parameter fileURL: The URL of the temporary file
    func registerTempFile(_ fileURL: URL) {
        tempFileRegistry.append(fileURL)
        print("Registered temporary file: \(fileURL.lastPathComponent)")
    }
    
    /// Create a new temporary file URL for the given purpose and register it
    /// - Parameters:
    ///   - prefix: A prefix to identify the file type (e.g., "recording", "screenshot")
    ///   - extension: The file extension (e.g., "m4a", "png")
    /// - Returns: A URL for a new temporary file
    func createTempFileURL(prefix: String, extension: String) -> URL {
        // Generate a unique filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "\(prefix)_\(dateString).\(`extension`)"
        
        // Create the full URL in our app temp directory
        let fileURL = appTempDirectory.appendingPathComponent(fileName)
        
        // Register this file automatically
        registerTempFile(fileURL)
        
        return fileURL
    }
    
    /// Delete a specific temporary file
    /// - Parameter fileURL: URL of the file to delete
    /// - Returns: Whether the deletion was successful
    @discardableResult
    func deleteTempFile(_ fileURL: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                
                // Remove from registry
                if let index = tempFileRegistry.firstIndex(of: fileURL) {
                    tempFileRegistry.remove(at: index)
                }
                
                print("Deleted temporary file: \(fileURL.lastPathComponent)")
                return true
            } else {
                print("File doesn't exist, no need to delete: \(fileURL.lastPathComponent)")
                // Still remove from registry
                if let index = tempFileRegistry.firstIndex(of: fileURL) {
                    tempFileRegistry.remove(at: index)
                }
                return true
            }
        } catch {
            print("Error deleting temporary file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Clean up all registered temporary files
    /// - Returns: Number of successfully deleted files
    @discardableResult
    func cleanupAllTempFiles() -> Int {
        var deletedCount = 0
        
        // Create a copy of the registry to iterate over
        let filesToDelete = tempFileRegistry
        
        for fileURL in filesToDelete {
            if deleteTempFile(fileURL) {
                deletedCount += 1
            }
        }
        
        print("Cleaned up \(deletedCount) temporary files")
        return deletedCount
    }
    
    /// Clean up old temporary files (older than the specified time interval)
    /// - Parameter olderThan: Time interval (in seconds) for file age threshold
    /// - Returns: Number of successfully deleted files
    @discardableResult
    func cleanupOldTempFiles(olderThan timeInterval: TimeInterval = 3600) -> Int {
        var deletedCount = 0
        let currentDate = Date()
        
        do {
            // Get all files in the temporary directory
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: appTempDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            
            for fileURL in fileURLs {
                do {
                    // Get file creation date
                    let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey])
                    if let creationDate = resourceValues.creationDate {
                        // Delete if older than threshold
                        if currentDate.timeIntervalSince(creationDate) > timeInterval {
                            try FileManager.default.removeItem(at: fileURL)
                            deletedCount += 1
                            print("Deleted old temp file: \(fileURL.lastPathComponent)")
                            
                            // Update registry
                            if let index = tempFileRegistry.firstIndex(of: fileURL) {
                                tempFileRegistry.remove(at: index)
                            }
                        }
                    }
                } catch {
                    print("Error processing file \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        } catch {
            print("Error scanning temp directory: \(error.localizedDescription)")
        }
        
        print("Cleaned up \(deletedCount) old temporary files")
        return deletedCount
    }
    
    /// Handles application termination by cleaning up all temporary files
    @objc private func applicationWillTerminate(_ notification: Notification) {
        print("Application terminating, cleaning up temporary files...")
        cleanupAllTempFiles()
    }
}
