//
//  OpenAIClient.swift
//  HiddenWindowMCP
//
//  Created by Claude on 4/9/25.
//

import Foundation
import SwiftUI
// Import for centralized notification handling
import Cocoa

class OpenAIClient: OpenAIClientProtocol {
    // Singleton instance
    static let shared = OpenAIClient()
    
    // API endpoints
    private let chatCompletionsURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let whisperTranscriptionURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private let visionCompletionsURL = URL(string: "https://api.openai.com/v1/chat/completions")! // Same endpoint, different format
    
    // API key - should be provided by the user
    private var apiKey: String = ""
    
    // Fixed model - always using GPT-4o
    private let model: String = "gpt-4o"
    private let whisperModel: String = "whisper-1"
    private let visionModel: String = "gpt-4o"  // Vision model for image processing
    
    // To track conversation context
    private var messages: [[String: String]] = []
    
    // Dependencies
    private var settingsManager: SettingsManagerProtocol
    private let notificationService: NotificationServiceProtocol
    
    // Flag to check if API key is set
    var hasApiKey: Bool {
        return !apiKey.isEmpty
    }
    
    // Initialize with dependencies
    init(settingsManager: SettingsManagerProtocol, notificationService: NotificationServiceProtocol) {
        self.settingsManager = settingsManager
        self.notificationService = notificationService
        
        // Load API key from settings
        self.apiKey = settingsManager.apiKey
        
        // Add system message to start the conversation with user-defined context
        messages.append(["role": "system", "content": createSystemContext(questionType: "general")])
    }
    
    // Convenience initializer for singleton during transition to DI
    private convenience init() {
        // During transition, fallback to shared instances
        let settingsManager = DIContainer.shared.resolve(SettingsManagerProtocol.self) ?? SettingsManager.shared
        let notificationService = DIContainer.shared.resolve(NotificationServiceProtocol.self) ?? DefaultNotificationService()
        
        self.init(settingsManager: settingsManager, notificationService: notificationService)
    }
    
    // Helper method to create the system context message
    private func createSystemContext(questionType: String) -> String {
        // Select the appropriate context based on the input type
        let contextPrompt: String
        switch questionType {
        case "screenshot":
            // Use the screenshot-specific context
            contextPrompt = settingsManager.screenshotContext
        case "whisper":
            // Use the voice-specific context
            contextPrompt = settingsManager.voiceContext
        case "text":
            // Use the text-specific context
            contextPrompt = settingsManager.textContext
        default:
            // Fallback to the general context for any other type
            contextPrompt = settingsManager.position
        }
        
        return contextPrompt
    }
    
    // Set or update the API key
    func setAPIKey(_ key: String) {
        self.apiKey = key
        // Also update in settings
        settingsManager.apiKey = key
    }
    
    // This method has been removed as we're only using GPT-4o now
    
    // MARK: - Chat Completions API
    
    // Send a request to the OpenAI API with conversation context
    func sendMessage(_ message: String, questionType: String = "text", completion: @escaping (String?, Error?) -> Void) {
        // Check if API key is set
        guard !apiKey.isEmpty else {
            let error = NSError(domain: "OpenAIClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not set"])
            completion(nil, error)
            
            // Post error notification using NotificationManager
            notificationService.post(
                name: Notification.Name("OpenAIError"),
                object: ["error": "API key not set. Please configure in settings."]
            )
            return
        }
        
        // Update system message with the user-defined context
        if messages.count > 0 && messages[0]["role"] == "system" {
            let contextMessage = createSystemContext(questionType: questionType)
            messages[0] = ["role": "system", "content": contextMessage]
        }
        
        // Add user message to the conversation
        messages.append(["role": "user", "content": message])
        
        // Prepare request body
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.7
        ]
        
        // Convert request body to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            let error = NSError(domain: "OpenAIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body"])
            completion(nil, error)
            return
        }
        
        // Create request
        var request = URLRequest(url: chatCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Send request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Handle network errors
            if let error = error {
                completion(nil, error)
                return
            }
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                completion(nil, error)
                return
            }
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                var errorMessage = "HTTP Error: \(httpResponse.statusCode)"
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    errorMessage += " - \(responseBody)"
                }
                let error = NSError(domain: "OpenAIClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                completion(nil, error)
                return
            }
            
            // Parse response
            guard let data = data else {
                let error = NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                completion(nil, error)
                return
            }
            
            do {
                // Parse JSON response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    // Add assistant response to the conversation history
                    self.messages.append(["role": "assistant", "content": content])
                    
                    // Return the response via callback only - let the caller post notifications
                    // to avoid duplicates
                    completion(content, nil)
                    
                } else {
                    let error = NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
                    completion(nil, error)
                    
                    // Post error notification
                    self.notificationService.post(
                        name: Notification.Name("OpenAIError"),
                        object: ["error": "Failed to parse response from OpenAI."]
                    )
                }
            } catch {
                completion(nil, error)
                
                // Post error notification
                self.notificationService.post(
                    name: Notification.Name("OpenAIError"),
                    object: ["error": error.localizedDescription]
                )
            }
        }
        
        task.resume()
    }
    
    // Updated sendRequest method with notification posting
    func sendRequest(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        sendMessage(prompt) { [weak self] response, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
            } else if let response = response {
                // Post notification about the response
                DispatchQueue.main.async {
                    // This notification will add the message to the conversation view
                    self.notificationService.post(
                        name: Notification.Name("OpenAIResponseReceived"),
                        object: ["response": response]
                    )
                }
                
                // Also call completion handler for callers that need the direct result
                // The ConversationView has been updated to avoid adding duplicates
                completion(.success(response))
            } else {
                completion(.failure(NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])))
            }
        }
    }
    
    // Send a request with context from replied messages
    func sendRequestWithContext(prompt: String, contextMessages: [Message], completion: @escaping (Result<String, Error>) -> Void) {
        // First check API key
        guard !apiKey.isEmpty else {
            let error = NSError(domain: "OpenAIClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not set"])
            completion(.failure(error))
            
            // Post error notification
            notificationService.post(
                name: Notification.Name("OpenAIError"),
                object: ["error": "API key not set. Please configure in settings."]
            )
            return
        }
        
        // Create a temporary message array for this request
        var tempMessages: [[String: String]] = []
        
        // Add system message (same as the one in our main messages array)
        if let systemMessage = messages.first(where: { $0["role"] == "system" }) {
            tempMessages.append(systemMessage)
        } else {
            // Add default system message if none exists
            tempMessages.append(["role": "system", "content": createSystemContext(questionType: "text")])
        }
        
        // Add context messages in sequence
        for contextMessage in contextMessages {
            let role = contextMessage.type == .user ? "user" : "assistant"
            
            // Combine all content parts into a single string
            let content = contextMessage.contents.map { content -> String in
                switch content.type {
                case .text:
                    return content.content
                case .code(let language):
                    return "```\(language)\n\(content.content)\n```"
                }
            }.joined(separator: "\n\n")
            
            tempMessages.append(["role": role, "content": content])
        }
        
        // Add the current prompt as a user message
        tempMessages.append(["role": "user", "content": prompt])
        
        // Prepare request body
        let requestBody: [String: Any] = [
            "model": model,
            "messages": tempMessages,
            "temperature": 0.7
        ]
        
        // Convert request body to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            let error = NSError(domain: "OpenAIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body"])
            completion(.failure(error))
            return
        }
        
        // Create request
        var request = URLRequest(url: chatCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Send request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Handle network errors
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                completion(.failure(error))
                return
            }
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                var errorMessage = "HTTP Error: \(httpResponse.statusCode)"
                if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                    errorMessage += " - \(responseBody)"
                }
                let error = NSError(domain: "OpenAIClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                completion(.failure(error))
                return
            }
            
            // Parse response
            guard let data = data else {
                let error = NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                completion(.failure(error))
                return
            }
            
            do {
                // Parse JSON response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    // Add the messages to our main conversation history
                    // First the user prompt (which was already added in the UI)
                    self.messages.append(["role": "user", "content": prompt])
                    
                    // Then the assistant response
                    self.messages.append(["role": "assistant", "content": content])
                    
                    // Post notification about the response
                    DispatchQueue.main.async {
                        self.notificationService.post(
                            name: Notification.Name("OpenAIResponseReceived"),
                            object: ["response": content]
                        )
                    }
                    
                    // Return the result
                    completion(.success(content))
                } else {
                    let error = NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
                    completion(.failure(error))
                    
                    // Post error notification
                    self.notificationService.post(
                        name: Notification.Name("OpenAIError"),
                        object: ["error": "Failed to parse response from OpenAI."]
                    )
                }
            } catch {
                completion(.failure(error))
                
                // Post error notification
                self.notificationService.post(
                    name: Notification.Name("OpenAIError"),
                    object: ["error": error.localizedDescription]
                )
            }
        }
        
        task.resume()
    }
    
    // MARK: - Whisper API (Audio Transcription)
    
    /// Transcribe an audio file using OpenAI's Whisper API
    func transcribeAudio(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        // Check if API key is set
        guard !apiKey.isEmpty else {
            let error = NSError(domain: "OpenAIClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not set"])
            completion(.failure(error))
            return
        }
        
        // Verify the file exists and has content
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let error = NSError(domain: "OpenAIClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "Audio file not found"])
            completion(.failure(error))
            return
        }
        
        // Check file size - too small files will cause errors
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? Int64, fileSize < 1000 {
                let error = NSError(domain: "OpenAIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Audio file too small (possibly no audio recorded)"])
                completion(.failure(error))
                return
            }
        } catch {
            print("Error checking file size: \(error)")
            // Continue anyway, don't fail here
        }
        
        // Create a multipart form request
        let boundary = UUID().uuidString
        
        var request = URLRequest(url: whisperTranscriptionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Set longer timeout to 60 seconds instead of default 60
        request.timeoutInterval = 60.0
        
        // Create the request body
        var requestData = Data()
        
        // Add the model parameter
        requestData.append("--\(boundary)\r\n".data(using: .utf8)!)
        requestData.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        requestData.append("\(whisperModel)\r\n".data(using: .utf8)!)
        
        // Add the file
        requestData.append("--\(boundary)\r\n".data(using: .utf8)!)
        requestData.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        requestData.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        
        // Use retry mechanism for network operations
        let maxRetries = 3
        func performRequestWithRetry(retryCount: Int = 0) {
            do {
                // Read the file data
                let fileData = try Data(contentsOf: fileURL)
                
                // Add file data
                var fullRequestData = requestData
                fullRequestData.append(fileData)
                fullRequestData.append("\r\n".data(using: .utf8)!)
                
                // Add the final boundary
                fullRequestData.append("--\(boundary)--\r\n".data(using: .utf8)!)
                
                // Set the request body
                request.httpBody = fullRequestData
                
                // Create robust URLSession config with better timeout handling
                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 60.0
                config.timeoutIntervalForResource = 120.0
                config.waitsForConnectivity = true
                let session = URLSession(configuration: config)
                
                // Send the request
                let task = session.dataTask(with: request) { [weak self] data, response, error in
                    guard let self = self else { return }
                    
                    // Handle explicit cancellation error more gracefully
                    if let error = error as NSError?, error.code == NSURLErrorCancelled {
                        print("Request was cancelled, possibly due to app state transition")
                        let cancelError = NSError(domain: "OpenAIClient", 
                                                code: NSURLErrorCancelled,
                                                userInfo: [NSLocalizedDescriptionKey: "Request was cancelled"])
                        completion(.failure(cancelError))
                        return
                    }
                    
                    // Handle other network errors with retry logic
                    if let error = error {
                        print("Network error: \(error.localizedDescription)")
                        
                        if retryCount < maxRetries {
                            print("Retrying transcription request (\(retryCount + 1)/\(maxRetries))")
                            
                            // Exponential backoff - wait longer between each retry
                            let delay = Double(pow(2.0, Double(retryCount))) * 0.5
                            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                                performRequestWithRetry(retryCount: retryCount + 1)
                            }
                            return
                        } else {
                            print("Max retries reached, failing with error")
                            completion(.failure(error))
                            return
                        }
                    }
                    
                    // Check HTTP response
                    guard let httpResponse = response as? HTTPURLResponse else {
                        let error = NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                        completion(.failure(error))
                        return
                    }
                    
                    // Check status code
                    guard (200...299).contains(httpResponse.statusCode) else {
                        var errorMessage = "HTTP Error: \(httpResponse.statusCode)"
                        if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                            errorMessage += " - \(responseBody)"
                        }
                        let error = NSError(domain: "OpenAIClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                        completion(.failure(error))
                        return
                    }
                    
                    // Parse response
                    guard let data = data else {
                        let error = NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                        completion(.failure(error))
                        return
                    }
                    
                    do {
                        // Parse JSON response
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let transcript = json["text"] as? String {
                            
                            // Return the transcript
                            completion(.success(transcript))
                            
                        } else {
                            let error = NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse transcription response"])
                            completion(.failure(error))
                        }
                    } catch {
                        completion(.failure(error))
                    }
                }
                
                task.resume()
                
            } catch {
                completion(.failure(error))
            }
        }
        
        // Start the request with retry mechanism
        performRequestWithRetry()
    }
    
    // Clear conversation history (except for the system message)
    func clearConversation() {
        messages = messages.filter { $0["role"] == "system" }
    }
    
    // Function to check if API key is configured
    func isConfigured() -> Bool {
        return !apiKey.isEmpty
    }
    
    // MARK: - Vision API (Image Processing)
    
    /// Send an image to OpenAI for processing using the Vision API
    /// - Parameters:
    ///   - imageURL: URL of the image file
    ///   - prompt: Text prompt to guide image analysis
    ///   - contextInfo: Optional context information for replied messages
    ///   - completion: Callback with result
    func sendImageRequest(imageURL: URL, prompt: String, contextInfo: [String: Any]? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        // Check if API key is set
        guard !apiKey.isEmpty else {
            let error = NSError(domain: "OpenAIClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not set"])
            completion(.failure(error))
            
            // Post error notification
            notificationService.post(
                name: Notification.Name("OpenAIError"),
                object: ["error": "API key not set. Please configure in settings."]
            )
            return
        }
        
        // Verify the file exists
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            let error = NSError(domain: "OpenAIClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "Image file not found"])
            completion(.failure(error))
            return
        }
        
        do {
            // Read image data
            let imageData = try Data(contentsOf: imageURL)
            
            // Convert image data to base64
            let base64Image = imageData.base64EncodedString()
            
            // Create local messages array for this request
            var requestMessages: [[String: Any]] = []
            
            // Use the screenshot context from settings
            requestMessages.append([
                "role": "system", 
                "content": settingsManager.screenshotContext
            ])
            
            // Add context messages if available
            if let contextInfo = contextInfo,
               let replyChain = contextInfo["replyChain"] as? [UUID],
               !replyChain.isEmpty {
                
                // Find the referenced messages
                for messageId in replyChain {
                    // We need to search in our main messages array
                    if let messageIndex = self.messages.firstIndex(where: { 
                        if let jsonId = $0["id"] as? String,
                           let uuid = UUID(uuidString: jsonId) {
                            return uuid == messageId
                        }
                        return false
                    }) {
                        // Add this message to the context
                        requestMessages.append(self.messages[messageIndex])
                    }
                }
            }
            
            // Create the message content with text and image
            var messageContent: [[String: Any]] = []
            
            // Add text part
            messageContent.append([
                "type": "text",
                "text": prompt
            ])
            
            // Add image part
            messageContent.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/png;base64,\(base64Image)"
                ]
            ])
            
            // Create the image message
            let userMessage: [String: Any] = [
                "role": "user",
                "content": messageContent
            ]
            
            // Add the user message to our request messages
            requestMessages.append(userMessage)
            
            // Prepare request body
            let requestBody: [String: Any] = [
                "model": visionModel,
                "messages": requestMessages,
                "max_tokens": 1000
            ]
            
            // Convert request body to JSON data
            guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
                let error = NSError(domain: "OpenAIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request body"])
                completion(.failure(error))
                return
            }
            
            // Create request
            var request = URLRequest(url: visionCompletionsURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            // Send request
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                
                // Handle network errors
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                // Check HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    completion(.failure(error))
                    return
                }
                
                // Check status code
                guard (200...299).contains(httpResponse.statusCode) else {
                    var errorMessage = "HTTP Error: \(httpResponse.statusCode)"
                    if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                        errorMessage += " - \(responseBody)"
                    }
                    let error = NSError(domain: "OpenAIClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    completion(.failure(error))
                    return
                }
                
                // Parse response
                guard let data = data else {
                    let error = NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    completion(.failure(error))
                    return
                }
                
                do {
                    // Parse JSON response
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        
                        // Add message to conversation
                        self.messages.append(["role": "user", "content": "Screenshot analysis request: \(prompt)"]) 
                        self.messages.append(["role": "assistant", "content": content])
                        
                        // Post notification about the response
                        DispatchQueue.main.async {
                            self.notificationService.post(
                                name: Notification.Name("OpenAIResponseReceived"),
                                object: ["response": content]
                            )
                        }
                        
                        // Return the result
                        completion(.success(content))
                    } else {
                        let error = NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse vision response"])
                        completion(.failure(error))
                        
                        // Post error notification
                        self.notificationService.post(
                            name: Notification.Name("OpenAIError"),
                            object: ["error": "Failed to parse vision response from OpenAI."]
                        )
                    }
                } catch {
                    completion(.failure(error))
                    
                    // Post error notification
                    self.notificationService.post(
                        name: Notification.Name("OpenAIError"),
                        object: ["error": error.localizedDescription]
                    )
                }
            }
            
            task.resume()
        } catch {
            completion(.failure(error))
            
            // Post error notification
            notificationService.post(
                name: Notification.Name("OpenAIError"),
                object: ["error": "Error reading image file: \(error.localizedDescription)"]
            )
        }
    }
}
