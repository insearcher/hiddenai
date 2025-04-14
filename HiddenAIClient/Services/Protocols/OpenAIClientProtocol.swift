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
    /// - Parameters:
    ///   - prompt: The text prompt
    ///   - completion: Callback with result or error
    func sendRequest(prompt: String, completion: @escaping (Result<String, Error>) -> Void)
    
    /// Sends a request with conversation context
    /// - Parameters:
    ///   - prompt: The text prompt
    ///   - contextMessages: Previous messages for context
    ///   - completion: Callback with result or error
    func sendRequestWithContext(prompt: String, contextMessages: [Message], completion: @escaping (Result<String, Error>) -> Void)
    
    /// Transcribes audio using OpenAI Whisper
    /// - Parameters:
    ///   - fileURL: URL of the audio file
    ///   - completion: Callback with transcription or error
    func transcribeAudio(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void)
    
    /// Analyzes an image using OpenAI Vision
    /// - Parameters:
    ///   - imageURL: URL of the image file
    ///   - prompt: Text prompt for image analysis
    ///   - contextInfo: Optional additional context
    ///   - completion: Callback with analysis or error
    func sendImageRequest(imageURL: URL, prompt: String, contextInfo: [String: Any]?, completion: @escaping (Result<String, Error>) -> Void)
    
    /// Clears the conversation history
    func clearConversation()
    
    /// Checks if the client is properly configured
    /// - Returns: Boolean indicating configuration status
    func isConfigured() -> Bool
}
