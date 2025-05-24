//
//  NetworkConfiguration.swift
//  HiddenAIClient
//
//  Created on 5/23/25.
//

import Foundation

/// Configuration for network operations
struct NetworkConfiguration {
    let requestTimeout: TimeInterval
    let resourceTimeout: TimeInterval
    let maxRetries: Int
    let baseRetryDelay: TimeInterval
    
    static let `default` = NetworkConfiguration(
        requestTimeout: 60.0,
        resourceTimeout: 120.0,
        maxRetries: 3,
        baseRetryDelay: 0.5
    )
    
    static let whisper = NetworkConfiguration(
        requestTimeout: 60.0,
        resourceTimeout: 120.0,
        maxRetries: 3,
        baseRetryDelay: 1.0
    )
}

/// Network utility for creating configured URL sessions
final class NetworkSessionProvider {
    static func createSession(with config: NetworkConfiguration) -> URLSession {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.requestTimeout
        sessionConfig.timeoutIntervalForResource = config.resourceTimeout
        sessionConfig.waitsForConnectivity = true
        return URLSession(configuration: sessionConfig)
    }
}

/// Retry mechanism for network operations
actor RetryManager {
    private let maxRetries: Int
    private let baseDelay: TimeInterval
    
    init(maxRetries: Int, baseDelay: TimeInterval) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
    }
    
    func executeWithRetry<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                let aiError = AIServiceError.from(error)
                
                // Don't retry non-retryable errors
                guard aiError.isRetryable && attempt < maxRetries else {
                    throw aiError
                }
                
                // Exponential backoff
                let delay = baseDelay * pow(2.0, Double(attempt))
                if #available(macOS 13.0, *) {
                    try await Task.sleep(for: .seconds(delay))
                } else {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? AIServiceError.unknown(NSError(domain: "RetryManager", code: 0, userInfo: nil))
    }
}