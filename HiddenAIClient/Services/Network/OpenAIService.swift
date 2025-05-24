//
//  OpenAIService.swift
//  HiddenAIClient
//
//  Created on 5/23/25.
//

import Foundation

/// Modern async/await OpenAI service implementation
final class OpenAIService: OpenAIClientProtocol {
    // MARK: - Constants
    
    private enum Endpoints {
        static let chatCompletions = URL(string: "https://api.openai.com/v1/chat/completions")!
        static let whisperTranscription = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        static let visionCompletions = URL(string: "https://api.openai.com/v1/chat/completions")!
    }
    
    private enum Models {
        static let chat = "gpt-4o"
        static let whisper = "whisper-1"
        static let vision = "gpt-4o"
    }
    
    // MARK: - Properties
    
    private var apiKey: String = ""
    private var conversationMessages: [[String: Any]] = []
    
    // Dependencies
    private let settingsManager: SettingsManagerProtocol
    private let notificationService: NotificationServiceProtocol
    private let retryManager: RetryManager
    private let networkSession: URLSession
    
    // MARK: - Public Properties
    
    var hasApiKey: Bool {
        !apiKey.isEmpty
    }
    
    // MARK: - Initialization
    
    init(
        settingsManager: SettingsManagerProtocol,
        notificationService: NotificationServiceProtocol,
        networkConfig: NetworkConfiguration = .default
    ) {
        self.settingsManager = settingsManager
        self.notificationService = notificationService
        self.retryManager = RetryManager(
            maxRetries: networkConfig.maxRetries,
            baseDelay: networkConfig.baseRetryDelay
        )
        self.networkSession = NetworkSessionProvider.createSession(with: networkConfig)
        
        // Load API key and initialize conversation
        self.apiKey = settingsManager.apiKey
        initializeConversation()
    }
    
    // MARK: - Public Methods
    
    func setAPIKey(_ key: String) {
        self.apiKey = key
        // Note: settingsManager is read-only in this implementation
        // API key changes should be handled by the settings manager directly
    }
    
    func clearConversation() {
        conversationMessages = conversationMessages.filter { 
            ($0["role"] as? String) == "system" 
        }
    }
    
    func isConfigured() -> Bool {
        return hasApiKey
    }
    
    // MARK: - Async API Methods
    
    func sendRequest(prompt: String) async throws -> String {
        guard hasApiKey else {
            throw AIServiceError.apiKeyMissing
        }
        
        // Add user message
        addUserMessage(prompt)
        
        let response = try await retryManager.executeWithRetry { [weak self] in
            guard let self = self else { 
                throw AIServiceError.unknown(NSError(domain: "OpenAIService", code: 0, userInfo: nil))
            }
            return try await self.performChatRequest(with: self.conversationMessages)
        }
        
        // Add assistant response to conversation
        addAssistantMessage(response)
        
        // Post success notification
        await MainActor.run {
            postResponseNotification(response)
        }
        
        return response
    }
    
    func sendRequestWithContext(prompt: String, contextMessages: [Message]) async throws -> String {
        guard hasApiKey else {
            throw AIServiceError.apiKeyMissing
        }
        
        // Build request messages with context
        var requestMessages = buildSystemMessages()
        requestMessages.append(contentsOf: convertContextMessages(contextMessages))
        requestMessages.append(["role": "user", "content": prompt])
        
        let response = try await retryManager.executeWithRetry { [weak self] in
            guard let self = self else { 
                throw AIServiceError.unknown(NSError(domain: "OpenAIService", code: 0, userInfo: nil))
            }
            return try await self.performChatRequest(with: requestMessages)
        }
        
        // Add to main conversation
        addUserMessage(prompt)
        addAssistantMessage(response)
        
        // Post success notification
        await MainActor.run {
            postResponseNotification(response)
        }
        
        return response
    }
    
    func transcribeAudio(fileURL: URL) async throws -> String {
        guard hasApiKey else {
            throw AIServiceError.apiKeyMissing
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AIServiceError.fileNotFound(fileURL.lastPathComponent)
        }
        
        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        if let fileSize = attributes[.size] as? Int64, fileSize < 1000 {
            throw AIServiceError.fileTooSmall(fileURL.lastPathComponent)
        }
        
        return try await retryManager.executeWithRetry { [weak self] in
            guard let self = self else { 
                throw AIServiceError.unknown(NSError(domain: "OpenAIService", code: 0, userInfo: nil))
            }
            return try await self.performWhisperRequest(fileURL: fileURL)
        }
    }
    
    func sendImageRequest(imageURL: URL, prompt: String, contextInfo: [String: Any]?) async throws -> String {
        guard hasApiKey else {
            throw AIServiceError.apiKeyMissing
        }
        
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw AIServiceError.fileNotFound(imageURL.lastPathComponent)
        }
        
        let response = try await retryManager.executeWithRetry { [weak self] in
            guard let self = self else { 
                throw AIServiceError.unknown(NSError(domain: "OpenAIService", code: 0, userInfo: nil))
            }
            return try await self.performVisionRequest(imageURL: imageURL, prompt: prompt, contextInfo: contextInfo)
        }
        
        // Add to conversation
        addUserMessage("Screenshot analysis request: \(prompt)")
        addAssistantMessage(response)
        
        // Post success notification
        await MainActor.run {
            postResponseNotification(response)
        }
        
        return response
    }
    
    // MARK: - Legacy Callback Methods
    
    func sendRequest(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let response = try await sendRequest(prompt: prompt)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func sendRequestWithContext(prompt: String, contextMessages: [Message], completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let response = try await sendRequestWithContext(prompt: prompt, contextMessages: contextMessages)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func transcribeAudio(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let response = try await transcribeAudio(fileURL: fileURL)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func sendImageRequest(imageURL: URL, prompt: String, contextInfo: [String: Any]?, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let response = try await sendImageRequest(imageURL: imageURL, prompt: prompt, contextInfo: contextInfo)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Private Implementation

private extension OpenAIService {
    func initializeConversation() {
        conversationMessages = [
            ["role": "system", "content": createSystemContext(questionType: "general")]
        ]
    }
    
    func createSystemContext(questionType: String) -> String {
        switch questionType {
        case "screenshot":
            return settingsManager.screenshotContext
        case "whisper":
            return settingsManager.voiceContext
        case "text":
            return settingsManager.textContext
        default:
            return settingsManager.position
        }
    }
    
    func addUserMessage(_ content: String) {
        conversationMessages.append(["role": "user", "content": content])
    }
    
    func addAssistantMessage(_ content: String) {
        conversationMessages.append(["role": "assistant", "content": content])
    }
    
    func buildSystemMessages() -> [[String: Any]] {
        return conversationMessages.filter { ($0["role"] as? String) == "system" }
    }
    
    func convertContextMessages(_ messages: [Message]) -> [[String: Any]] {
        return messages.map { message in
            let role = message.type == .user ? "user" : "assistant"
            let content = message.contents.map { content -> String in
                switch content.type {
                case .text:
                    return content.content
                case .code(let language):
                    return "```\(language)\n\(content.content)\n```"
                }
            }.joined(separator: "\n\n")
            
            return ["role": role, "content": content]
        }
    }
    
    func performChatRequest(with messages: [[String: Any]]) async throws -> String {
        let requestBody: [String: Any] = [
            "model": Models.chat,
            "messages": messages,
            "temperature": 0.7
        ]
        
        let data = try await performRequest(to: Endpoints.chatCompletions, body: requestBody)
        return try parseStandardResponse(from: data)
    }
    
    func performWhisperRequest(fileURL: URL) async throws -> String {
        let boundary = UUID().uuidString
        var request = URLRequest(url: Endpoints.whisperTranscription)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart body
        let fileData = try Data(contentsOf: fileURL)
        let body = buildMultipartBody(boundary: boundary, model: Models.whisper, fileData: fileData, filename: fileURL.lastPathComponent)
        request.httpBody = body
        
        let (data, response) = try await networkSession.data(for: request)
        try validateHTTPResponse(response)
        
        // Parse whisper response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let transcript = json["text"] as? String else {
            throw AIServiceError.responseParsingFailed
        }
        
        return transcript
    }
    
    func performVisionRequest(imageURL: URL, prompt: String, contextInfo: [String: Any]?) async throws -> String {
        let imageData = try Data(contentsOf: imageURL)
        let base64Image = imageData.base64EncodedString()
        
        var messages: [[String: Any]] = [
            ["role": "system", "content": settingsManager.screenshotContext]
        ]
        
        // Add context if provided
        if let contextInfo = contextInfo,
           let replyChain = contextInfo["replyChain"] as? [UUID] {
            // Add context messages (simplified for this refactor)
            // In a full implementation, you'd resolve these UUIDs to actual messages
        }
        
        let messageContent: [[String: Any]] = [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64Image)"]]
        ]
        
        messages.append(["role": "user", "content": messageContent])
        
        let requestBody: [String: Any] = [
            "model": Models.vision,
            "messages": messages,
            "max_tokens": 1000
        ]
        
        let data = try await performRequest(to: Endpoints.visionCompletions, body: requestBody)
        return try parseStandardResponse(from: data)
    }
    
    func performRequest(to url: URL, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await networkSession.data(for: request)
        try validateHTTPResponse(response)
        
        return data
    }
    
    func validateHTTPResponse(_ response: URLResponse?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw AIServiceError.apiKeyInvalid
        case 402, 403:
            throw AIServiceError.quotaExceeded
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw AIServiceError.rateLimitExceeded(retryAfter: retryAfter)
        case 500...599:
            throw AIServiceError.serverError(statusCode: httpResponse.statusCode, message: nil)
        default:
            throw AIServiceError.serverError(statusCode: httpResponse.statusCode, message: "Unexpected status code")
        }
    }
    
    func parseStandardResponse(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.responseParsingFailed
        }
        
        return content
    }
    
    func buildMultipartBody(boundary: String, model: String, fileData: Data, filename: String) -> Data {
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        
        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    func postResponseNotification(_ response: String) {
        notificationService.post(
            name: Notification.Name("OpenAIResponseReceived"),
            object: ["response": response]
        )
    }
}