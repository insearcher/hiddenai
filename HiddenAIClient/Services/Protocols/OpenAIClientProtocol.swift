//
//  OpenAIClientProtocol.swift
//  HiddenWindowMCP
//
//  Created on 4/11/25.
//

import Foundation

/// Protocol for OpenAI API client services
protocol OpenAIClientProtocol: SelfResolvable {
    /// Indicates if the service has an API key configured
    var hasApiKey: Bool { get }
    
    /// Sets the API key for OpenAI requests
    /// - Parameter key: The API key string
    func setAPIKey(_ key: String)
    
    /// Sends a text request to OpenAI
    /// - Parameter prompt: The text prompt
    /// - Returns: The response string
    /// - Throws: An error if the request fails
    func sendRequest(prompt: String) async throws -> String
    
    /// Sends a request with conversation context
    /// - Parameters:
    ///   - prompt: The text prompt
    ///   - contextMessages: Previous messages for context
    /// - Returns: The response string
    /// - Throws: An error if the request fails
    func sendRequestWithContext(prompt: String, contextMessages: [Message]) async throws -> String
    
    /// Transcribes audio using OpenAI Whisper
    /// - Parameter fileURL: URL of the audio file
    /// - Returns: The transcription string
    /// - Throws: An error if transcription fails
    func transcribeAudio(fileURL: URL) async throws -> String
    
    /// Analyzes an image using OpenAI Vision
    /// - Parameters:
    ///   - imageURL: URL of the image file
    ///   - prompt: Text prompt for image analysis
    ///   - contextInfo: Optional additional context
    /// - Returns: The analysis string
    /// - Throws: An error if the analysis fails
    func sendImageRequest(imageURL: URL, prompt: String, contextInfo: [String: Any]?) async throws -> String
    
    /// Clears the conversation history
    func clearConversation()
    
    /// Checks if the client is properly configured
    /// - Returns: Boolean indicating configuration status
    func isConfigured() -> Bool
    
    // MARK: - Legacy callback-based methods for backward compatibility
    
    /// Legacy callback-based method - prefer async version
    func sendRequest(prompt: String, completion: @escaping (Result<String, Error>) -> Void)
    
    /// Legacy callback-based method - prefer async version
    func sendRequestWithContext(prompt: String, contextMessages: [Message], completion: @escaping (Result<String, Error>) -> Void)
    
    /// Legacy callback-based method - prefer async version
    func transcribeAudio(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void)
    
    /// Legacy callback-based method - prefer async version
    func sendImageRequest(imageURL: URL, prompt: String, contextInfo: [String: Any]?, completion: @escaping (Result<String, Error>) -> Void)
}
