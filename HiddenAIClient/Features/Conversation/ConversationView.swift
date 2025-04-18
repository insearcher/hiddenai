//
//  ConversationView.swift
//  HiddenWindowMCP
//
//  Created by Maxim Frolov on 4/9/25.
//

import SwiftUI
import AppKit

struct MessageContent: Equatable {
    enum ContentType: Equatable {
        case text
        case code(language: String)
    }
    
    let content: String
    let type: ContentType
    
    static func == (lhs: MessageContent, rhs: MessageContent) -> Bool {
        return lhs.content == rhs.content && lhs.type == rhs.type
    }
}

struct Message: Identifiable, Equatable {
    enum MessageType: Equatable {
        case user
        case assistant
    }
    
    let id = UUID()
    let contents: [MessageContent]
    let type: MessageType
    let timestamp: Date
    let replyToId: UUID?            // ID of the message this is replying to
    let replyChain: [UUID]          // Chain of message IDs in the reply thread
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id &&
               lhs.contents == rhs.contents &&
               lhs.type == rhs.type &&
               lhs.timestamp == rhs.timestamp &&
               lhs.replyToId == rhs.replyToId &&
               lhs.replyChain == rhs.replyChain
    }
    
    // Convenience initializer for backward compatibility
    init(text: String, type: MessageType, timestamp: Date, replyToId: UUID? = nil, replyChain: [UUID] = []) {
        // Parse the text for any code blocks
        self.contents = Message.parseTextForCodeBlocks(text)
        self.type = type
        self.timestamp = timestamp
        self.replyToId = replyToId
        self.replyChain = replyChain
    }
    
    // Parse text for code blocks using markdown-style triple backtick syntax
    static func parseTextForCodeBlocks(_ text: String) -> [MessageContent] {
        var contents: [MessageContent] = []
        
        // Pattern to find ```language\ncode\n``` blocks
        let codeBlockPattern = try? NSRegularExpression(
            pattern: "```([a-zA-Z0-9]*)?\\s*\\n([\\s\\S]*?)\\n```",
            options: []
        )
        
        let nsText = text as NSString
        var lastIndex = 0
        
        // Find all code blocks
        if let matches = codeBlockPattern?.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: nsText.length)
        ) {
            for match in matches {
                // Add any text before the code block
                let textBeforeRange = NSRange(location: lastIndex, length: match.range.location - lastIndex)
                if textBeforeRange.length > 0 {
                    var textBefore = nsText.substring(with: textBeforeRange)
                    
                    // Aggressively clean up text before code blocks
                    // 1. Trim any trailing newlines completely (not just excessive ones)
                    while textBefore.hasSuffix("\n") || textBefore.hasSuffix("\r") {
                        textBefore = String(textBefore.dropLast())
                    }
                    
                    // 2. Ensure there's just one space at the end if needed
                    textBefore = textBefore.trimmingCharacters(in: .whitespaces) + " "
                    
                    // 3. Apply general cleanup to the whole text
                    // Replace any sequence of 2+ newlines with a single newline
                    let compactText = textBefore.replacingOccurrences(
                        of: "\\n\\s*\\n+",
                        with: "\n",
                        options: .regularExpression
                    )
                    
                    // Only add non-empty content
                    if !compactText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        contents.append(MessageContent(content: compactText, type: .text))
                    }
                }
                
                // Extract language if specified
                let languageRange = match.range(at: 1)
                let language = languageRange.location != NSNotFound && languageRange.length > 0 
                    ? nsText.substring(with: languageRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    : "text"
                
                // Extract code and trim extra whitespace at start and end
                let codeRange = match.range(at: 2)
                if codeRange.location != NSNotFound {
                    let code = nsText.substring(with: codeRange)
                    // Keep internal whitespace structure but trim excess at edges
                    let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
                    contents.append(MessageContent(content: trimmedCode, type: .code(language: language)))
                }
                
                lastIndex = match.range.location + match.range.length
            }
        }
        
        // Add any remaining text after the last code block
        if lastIndex < nsText.length {
            var textAfter = nsText.substring(with: NSRange(location: lastIndex, length: nsText.length - lastIndex))
            
            // Clean up leading whitespace/newlines
            while textAfter.hasPrefix("\n") || textAfter.hasPrefix("\r") {
                textAfter = String(textAfter.dropFirst())
            }
            
            // Apply general cleanup
            let compactText = textAfter.replacingOccurrences(
                of: "\\n\\s*\\n+",
                with: "\n",
                options: .regularExpression
            )
            
            // Only add non-empty content
            if !compactText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                contents.append(MessageContent(content: compactText, type: .text))
            }
        }
        
        // If no code blocks were found, just return the entire text as one content
        if contents.isEmpty {
            // Compact text by removing extra newlines
            let compactText = text.replacingOccurrences(
                of: "\\n\\s*\\n+",
                with: "\n",
                options: .regularExpression
            )
            contents.append(MessageContent(content: compactText, type: .text))
        }
        
        return contents
    }
}

struct ConversationView: View {
    @State private var messages: [Message] = []
    @State private var isProcessing: Bool = false
    @State private var showSettings: Bool = false
    @State private var apiKeyIsSet: Bool = false
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    
    // Authentication removed for open source version
    
    // New state for Whisper transcription
    @State private var isWhisperRecording: Bool = false
    @State private var whisperRecordingTime: String = "00:00"
    
    // New state for Screenshot functionality
    @State private var isProcessingScreenshot: Bool = false
    @State private var screenshotPath: String? = nil
    
    // State for auto-scrolling and scroll position
    @State private var scrollToBottom: Bool = true
    @State private var latestMessageId: UUID?
    @State private var showScrollToButton: Bool = false
    
    // Reply context tracking
    @State private var activeReplyId: UUID? = nil
    @State private var replyChain: [UUID] = []
    
    // Timer for updating recording time
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Conversation")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                
                Spacer()
                
                // Settings button
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gear")
                        .foregroundColor(JetBrainsTheme.textPrimary)
                        .font(.system(size: 16))
                        .padding(6)
                        .background(JetBrainsTheme.backgroundTertiary)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 8)
                
                // Clear button
                Button(action: clearConversation) {
                    Image(systemName: "trash")
                        .foregroundColor(JetBrainsTheme.textPrimary)
                        .font(.system(size: 16))
                        .padding(6)
                        .background(JetBrainsTheme.backgroundTertiary)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(JetBrainsTheme.accentPrimary.opacity(0.9))
            
            // Messages area with ScrollViewReader for programmatic scrolling
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { scrollView in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                MessageView(message: message, 
                                          activeReplyId: $activeReplyId, 
                                          replyChain: $replyChain,
                                          onReply: { messageId in
                                              self.setReplyContext(messageId: messageId)
                                          },
                                          onClearReply: {
                                              self.clearReplyContext()
                                          },
                                          onClickReplyContext: { messageId in
                                              // Handle click on reply context by scrolling to the message
                                              scrollToMessage(messageId, in: scrollView)
                                          },
                                          getContentPreview: { messageId in
                                              // Get a preview of message content by ID
                                              self.getMessagePreview(id: messageId)
                                          })
                                    .id(message.id)
                                    .onAppear {
                                        // Track when the message becomes visible
                                        if message.id == latestMessageId && scrollToBottom {
                                            // Delay to ensure rendering is complete
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                withAnimation {
                                                    scrollView.scrollTo(message.id, anchor: .bottom)
                                                }
                                            }
                                        }
                                    }
                            }
                            
                            // Show active reply indicator if applicable
                            if let replyId = activeReplyId {
                                // Look up the message to get a preview
                                if let replyMsgIndex = messages.firstIndex(where: { $0.id == replyId }),
                                   let firstContent = messages[replyMsgIndex].contents.first {
                                    
                                    // Make the whole row clickable with ZStack for the Clear button
                                    ZStack(alignment: .trailing) {
                                        // Main content as a button (entire area clickable)
                                        Button(action: {
                                            // Scroll to message when tapped
                                            scrollToMessage(replyId, in: scrollView)
                                        }) {
                                            HStack {
                                                Image(systemName: "arrowshape.turn.up.left")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(JetBrainsTheme.accentPrimary)
                                                
                                                // Show real preview of the message
                                                let content = firstContent.content
                                                let preview = content.count > 60 ? 
                                                    String(content.prefix(60)) + "..." : content
                                                    
                                                Text(preview)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(JetBrainsTheme.accentPrimary)
                                                    .lineLimit(1)
                                                
                                                Spacer()
                                                
                                                // Spacer for the clear button
                                                Text("      ")
                                                    .opacity(0)
                                            }
                                            .contentShape(Rectangle()) // Make entire area clickable
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        // Clear button on top
                                        Button(action: clearReplyContext) {
                                            Text("Clear")
                                                .font(.system(size: 12))
                                                .foregroundColor(JetBrainsTheme.error)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(.trailing, 4)
                                    }
                                    .padding(8)
                                    .background(JetBrainsTheme.backgroundTertiary)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(JetBrainsTheme.accentPrimary.opacity(0.4), lineWidth: 1)
                                    )
                                    .padding(.vertical, 4)
                                    .transition(.opacity)
                                }
                            }
                            
                            // Show recording status if Whisper is recording
                            if isWhisperRecording {
                                HStack {
                                    Image(systemName: "waveform")
                                        .foregroundColor(JetBrainsTheme.error)
                                        .font(.system(size: 14))
                                    
                                    Text("Recording with Whisper: \(whisperRecordingTime)")
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundColor(JetBrainsTheme.error)
                                }
                                .padding(10)
                                .background(JetBrainsTheme.backgroundTertiary)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(JetBrainsTheme.error.opacity(0.6), lineWidth: 1)
                                )
                                .padding(.vertical, 4)
                            }
                            
                            // Removed Apple speech recognition UI
                        }
                        .padding()
                        .onChange(of: messages) { 
                            if let lastMessage = messages.last {
                                latestMessageId = lastMessage.id
                                
                                // Auto-scroll to the new message if auto-scroll is enabled
                                if scrollToBottom {
                                    withAnimation {
                                        scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                } else {
                                    // Show the scroll-to-bottom button
                                    showScrollToButton = true
                                }
                            }
                        }
                    }
                    .background(JetBrainsTheme.backgroundPrimary)
                    // We no longer need to poll for time updates since we're using notifications
                    // Detect when user manually scrolls
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            scrollToBottom = false
                            showScrollToButton = true
                        }
                    )
                    
                    // Scroll to latest button appears when needed
                    if showScrollToButton && !messages.isEmpty {
                        Button(action: {
                            if let lastId = messages.last?.id {
                                withAnimation {
                                    scrollView.scrollTo(lastId, anchor: .bottom)
                                    scrollToBottom = true
                                    showScrollToButton = false
                                }
                            }
                        }) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(JetBrainsTheme.accentPrimary)
                                .background(Circle().fill(JetBrainsTheme.backgroundPrimary))
                                .shadow(color: JetBrainsTheme.backgroundPrimary.opacity(0.3), radius: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.bottom, 16)
                        .padding(.trailing, 16)
                        .transition(.opacity)
                    }
                }
            }
            
            // Controls area
            VStack(spacing: 10) {
                if !apiKeyIsSet {
                    Text("OpenAI API key not set. Click Settings to configure.")
                        .font(.system(size: 13))
                        .foregroundColor(JetBrainsTheme.warning)
                        .padding(8)
                        .background(JetBrainsTheme.warning.opacity(0.1))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(JetBrainsTheme.warning.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.horizontal)
                }
                
                // Text input field
                HStack(spacing: 8) {
                    TextField("Type your message...", text: $inputText)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(JetBrainsTheme.backgroundTertiary)
                        .cornerRadius(6)
                        .foregroundColor(JetBrainsTheme.textPrimary)
                        .submitLabel(.send)
                        .focused($isInputFocused)
                        .onTapGesture {
                            // Ensure field gets focused when tapped
                            isInputFocused = true
                            print("Text field tapped, setting focus")
                        }
                        .onChange(of: isInputFocused) { _, focused in
                            // Notify about focus state changes
                            NotificationCenter.default.post(
                                name: .textFieldFocusChanged,
                                object: ["focused": focused]
                            )
                            print("Text input focus changed: \(focused)")
                            
                            // If losing focus unexpectedly, try to regain it
                            if !focused {
                                // Add a short delay before trying to refocus
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    // Only try to refocus if we're not currently in a different text field
                                    if let window = NSApplication.shared.keyWindow,
                                       !(window.firstResponder is NSTextField) && 
                                       !(window.firstResponder is NSTextView) {
                                        isInputFocused = true
                                        print("Auto-refocusing text field")
                                    }
                                }
                            }
                        }
                        .onSubmit {
                            sendTextMessage()
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isInputFocused ? JetBrainsTheme.accentPrimary : JetBrainsTheme.border, lineWidth: isInputFocused ? 1.5 : 1)
                        )
                        .animation(.easeInOut(duration: 0.2), value: isInputFocused)
                    
                    // Send button
                    Button(action: sendTextMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16))
                            .foregroundColor(JetBrainsTheme.textPrimary)
                            .padding(10)
                            .background(JetBrainsTheme.accentPrimary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                }
                .padding(.horizontal)
                
                HStack(spacing: 12) {
                    // Whisper record button
                    Button(action: toggleWhisperRecording) {
                        HStack(spacing: 6) {
                            Image(systemName: isWhisperRecording ? "stop.circle.fill" : "waveform.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(isWhisperRecording ? JetBrainsTheme.error : JetBrainsTheme.accentSecondary)
                            
                            Text(isWhisperRecording ? "Stop Whisper" : "Whisper")
                                .font(.system(size: 14))
                                .foregroundColor(JetBrainsTheme.textPrimary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            isWhisperRecording ? 
                                JetBrainsTheme.error.opacity(0.15) : 
                                JetBrainsTheme.backgroundTertiary
                        )
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    isWhisperRecording ? 
                                        JetBrainsTheme.error.opacity(0.5) : 
                                        JetBrainsTheme.border,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Record audio and transcribe with OpenAI Whisper (Cmd+R)")
                    
                    // Screenshot button
                    Button(action: captureScreenshot) {
                        HStack(spacing: 6) {
                            Image(systemName: isProcessingScreenshot ? "hourglass" : "camera.fill")
                                .font(.system(size: 18))
                                .foregroundColor(isProcessingScreenshot ? JetBrainsTheme.warning : JetBrainsTheme.accentPrimary)
                            
                            Text(isProcessingScreenshot ? "Processing..." : "Screenshot")
                                .font(.system(size: 14))
                                .foregroundColor(JetBrainsTheme.textPrimary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            isProcessingScreenshot ? 
                                JetBrainsTheme.warning.opacity(0.15) : 
                                JetBrainsTheme.backgroundTertiary
                        )
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    isProcessingScreenshot ? 
                                        JetBrainsTheme.warning.opacity(0.5) : 
                                        JetBrainsTheme.border,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isProcessingScreenshot)
                    .help("Capture screen and analyze with GPT-4o (Cmd+P)")
                    
                    Spacer()
                    
                    // Keyboard shortcuts
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("⌘+R")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(JetBrainsTheme.accentSecondary.opacity(0.15))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(JetBrainsTheme.accentSecondary.opacity(0.3), lineWidth: 1)
                                )
                            
                            Text("Whisper")
                                .font(.system(size: 12))
                                .foregroundColor(JetBrainsTheme.textSecondary)
                        }
                        
                        HStack(spacing: 6) {
                            Text("⌘+P")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(JetBrainsTheme.accentPrimary.opacity(0.15))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(JetBrainsTheme.accentPrimary.opacity(0.3), lineWidth: 1)
                                )
                            
                            Text("Screenshot")
                                .font(.system(size: 12))
                                .foregroundColor(JetBrainsTheme.textSecondary)
                        }
                    }
                    
                    // Status indicators
                    if isProcessing {
                        HStack(spacing: 5) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: JetBrainsTheme.textPrimary))
                                .scaleEffect(0.7)
                            
                            Text("Processing...")
                                .font(.system(size: 12))
                                .foregroundColor(JetBrainsTheme.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .background(JetBrainsTheme.backgroundSecondary)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .background(JetBrainsTheme.backgroundPrimary)
        // Set minimum frame size for the ConversationView to match window size
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            setupNotifications()
            checkAPIKey()
            
            // Add a longer delay before focusing to ensure the UI is fully loaded
            // and the window has time to become key and receive events
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isInputFocused = true
                print("Setting input focus to true after delay")
                
                // Try to focus text field through notification as well for redundancy
                NotificationCenter.default.post(
                    name: .focusTextFieldNotification,
                    object: nil
                )
            }
        }
        .onDisappear {
            removeNotifications()
        }
    }
    
    // MARK: - Screenshot Functions
    
    /// Capture a screenshot and send it to OpenAI
    private func captureScreenshot() {
        // Check if we have an API key first
        if !OpenAIClient.shared.hasApiKey {
            addMessage("OpenAI API key not set. Please configure in settings.", type: .assistant)
            showSettings = true
            return
        }
        
        // Prevent multiple capture attempts
        if isProcessingScreenshot {
            return
        }
        
        isProcessingScreenshot = true
        
        // Request screenshot capture through notification
        // Include reply context in the notification if available
        if !replyChain.isEmpty {
            // Create a notification payload with reply context
            var contextInfo: [String: Any] = [:]
            
            // Add message IDs
            contextInfo["replyChain"] = replyChain
            contextInfo["replyToId"] = activeReplyId
            
            // Post with context
            NotificationCenter.default.post(
                name: .captureScreenshotRequested, 
                object: contextInfo
            )
        } else {
            // Post without context
            NotificationCenter.default.post(name: .captureScreenshotRequested, object: nil)
        }
        
        // Add a message to indicate we're processing
        addMessage("Capturing and analyzing screenshot...", type: .user)
    }
    
    private func setupNotifications() {
        // Screenshot notifications
        NotificationCenter.default.addObserver(
            forName: .screenshotCaptured,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.object as? [String: String],
               let path = userInfo["path"] {
                self.screenshotPath = path
                print("Screenshot captured at path: \(path)")
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .screenshotProcessing,
            object: nil,
            queue: .main
        ) { _ in
            // Update UI state in addition to just logging
            self.isProcessingScreenshot = true
            
            // Optionally add the processing message if it doesn't exist yet
            if !self.messages.contains(where: { $0.contents.first?.content.contains("Capturing and analyzing screenshot") == true }) {
                self.addMessage("Capturing and analyzing screenshot...", type: .user)
            }
            
            print("Screenshot is being processed by OpenAI")
        }
        
        NotificationCenter.default.addObserver(
            forName: .screenshotError,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.object as? [String: String],
               let errorMessage = userInfo["error"] {
                DispatchQueue.main.async {
                    self.isProcessingScreenshot = false
                    self.addMessage("Screenshot error: \(errorMessage)", type: .assistant)
                }
            }
        }
        
        // Removed legacy speech recognition observers
        
        // Focus text field notification
        NotificationCenter.default.addObserver(
            forName: Notification.Name.focusTextFieldNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isInputFocused = true
        }
        
        // Removed legacy speech recognition state observers
        
        // Whisper recording state
        NotificationCenter.default.addObserver(
            forName: .whisperRecordingStarted,
            object: nil,
            queue: .main
        ) { notification in
            isWhisperRecording = true
            // Get initial time from notification if provided
            if let userInfo = notification.object as? [String: String],
               let initialTime = userInfo["timeString"] {
                whisperRecordingTime = initialTime
            } else {
                whisperRecordingTime = "00:00"
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .whisperRecordingStopped,
            object: nil,
            queue: .main
        ) { notification in
            isWhisperRecording = false
            // Get final duration from notification if provided
            if let userInfo = notification.object as? [String: String],
               let finalDuration = userInfo["finalDuration"] {
                print("Recording completed with duration: \(finalDuration)")
            }
        }
        
        // Add listener for time updates
        NotificationCenter.default.addObserver(
            forName: .whisperRecordingTimeUpdated,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.object as? [String: String],
               let timeString = userInfo["timeString"] {
                self.whisperRecordingTime = timeString
            }
        }
        
        // Whisper transcription results
        NotificationCenter.default.addObserver(
            forName: .whisperTranscriptionReceived,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.object as? [String: Any],
               let transcript = userInfo["transcript"] as? String,
               !transcript.isEmpty {
                
                // Check if there's reply context in the notification
                if let replyChainData = userInfo["replyChain"] as? [UUID],
                   !replyChainData.isEmpty {
                    
                    // Set the reply context
                    self.replyChain = replyChainData
                    
                    // Set the active reply ID if available
                    if let replyToId = userInfo["replyToId"] as? UUID {
                        self.activeReplyId = replyToId
                    }
                }
                
                // Process the transcription just like any other user input
                processTranscription(transcript)
            }
        }
        
        // Whisper transcription errors
        NotificationCenter.default.addObserver(
            forName: .whisperTranscriptionError,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.object as? [String: Any],
               let errorMessage = userInfo["error"] as? String {
                
                // Show the error as a system message
                addMessage("Whisper transcription error: \(errorMessage)", type: .assistant)
            }
        }
        
        // OpenAI API responses
        NotificationCenter.default.addObserver(
            forName: Notification.Name("OpenAIResponseReceived"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.object as? [String: Any],
               let response = userInfo["response"] as? String {
                
                // Add the assistant's response to the conversation
                addMessage(response, type: .assistant)
                
                // Always stop processing indicators after a response
                isProcessing = false
                isProcessingScreenshot = false
                
                print("ConversationView received OpenAI response via notification")
            }
        }
        
        // Error notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("OpenAIError"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.object as? [String: Any],
               let error = userInfo["error"] as? String {
                
                // Add the error as an assistant message
                addMessage("Error: \(error)", type: .assistant)
                isProcessing = false
                isProcessingScreenshot = false
            }
        }
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func checkAPIKey() {
        apiKeyIsSet = OpenAIClient.shared.hasApiKey
    }
    
    // MARK: - Whisper Transcription
    
    private func toggleWhisperRecording() {
        // Check if we have an API key first
        if !OpenAIClient.shared.hasApiKey {
            addMessage("OpenAI API key not set. Please configure in settings.", type: .assistant)
            showSettings = true
            return
        }
        
        // Toggle recording with Whisper service
        // Include reply context if available
        if !replyChain.isEmpty {
            // Create a context object
            var contextInfo: [String: Any] = [:]
            
            // Add message IDs
            contextInfo["replyChain"] = replyChain
            contextInfo["replyToId"] = activeReplyId
            
            // Toggle with context
            WhisperTranscriptionService.shared.toggleRecording(contextInfo: contextInfo) { result in
                if case .failure(let error) = result {
                    DispatchQueue.main.async {
                        addMessage("Error: \(error.localizedDescription)", type: .assistant)
                    }
                }
            }
        } else {
            // Toggle without context
            WhisperTranscriptionService.shared.toggleRecording { result in
                if case .failure(let error) = result {
                    DispatchQueue.main.async {
                        addMessage("Error: \(error.localizedDescription)", type: .assistant)
                    }
                }
            }
        }
        
        // The actual transcription response is handled through the notification system
    }
    
    // Removed Legacy Speech Recognition methods
    
    // MARK: - Message Processing
    
    private func processTranscription(_ text: String) {
        // Add the user's message to the conversation
        addMessage(text, type: .user)
        
        // Send to OpenAI for processing
        if OpenAIClient.shared.hasApiKey {
            isProcessing = true
            
            // Check if we have an active reply context
            if !replyChain.isEmpty {
                // Build an array of context messages in the right order
                var contextMessages: [Message] = []
                
                // Get all messages in the reply chain
                for messageId in replyChain {
                    if let messageIndex = messages.firstIndex(where: { $0.id == messageId }) {
                        contextMessages.append(messages[messageIndex])
                    }
                }
                
                // Send request with context
                OpenAIClient.shared.sendRequestWithContext(
                    prompt: text,
                    contextMessages: contextMessages
                ) { result in
                    // Only handle failures in the completion handler
                    // Success responses are handled by the notification observer
                    if case .failure(let error) = result {
                        DispatchQueue.main.async {
                            addMessage("Error: \(error.localizedDescription)", type: .assistant)
                            self.isProcessing = false
                        }
                    }
                }
            } else {
                // No context, send a regular request
                OpenAIClient.shared.sendRequest(prompt: text) { result in
                    // Only handle failures in the completion handler
                    // Success responses are handled by the notification observer
                    if case .failure(let error) = result {
                        DispatchQueue.main.async {
                            addMessage("Error: \(error.localizedDescription)", type: .assistant)
                            self.isProcessing = false
                        }
                    }
                    // We don't set isProcessing = false for success case 
                    // as the notification handler will do that
                }
            }
        } else {
            addMessage("Please set your OpenAI API key in settings to receive responses.", type: .assistant)
            showSettings = true
        }
    }
    
    private func addMessage(_ text: String, type: Message.MessageType) {
        let message = Message(
            text: text, 
            type: type, 
            timestamp: Date(),
            replyToId: activeReplyId,
            replyChain: replyChain
        )
        messages.append(message)
        
        // Set the latest message ID for scrolling
        latestMessageId = message.id
        
        // Re-enable auto-scrolling when a new user message is added
        // This ensures new conversations start with auto-scroll enabled
        if type == .user {
            scrollToBottom = true
        }
        
        // Clear reply context after sending a message
        if activeReplyId != nil {
            clearReplyContext()
        }
    }
    
    /// Set up the reply context for a message
    private func setReplyContext(messageId: UUID) {
        // Find the message we're replying to
        guard let replyToIndex = messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }
        
        let replyToMessage = messages[replyToIndex]
        
        // Set the active reply ID
        activeReplyId = messageId
        
        // Build the reply chain
        var newReplyChain = replyToMessage.replyChain
        
        // If the message already has a reply chain, continue it
        if !newReplyChain.isEmpty {
            // Add the current message ID to the chain
            newReplyChain.append(messageId)
        } else {
            // Start a new chain with just this message
            newReplyChain = [messageId]
        }
        
        // If we're replying to an AI message, also include the question that prompted it
        if replyToMessage.type == .assistant, let replyToId = replyToMessage.replyToId {
            // Find the user message that prompted this assistant response
            if !newReplyChain.contains(replyToId) {
                // Add the user message ID to the beginning of the chain
                newReplyChain.insert(replyToId, at: 0)
            }
        }
        
        // If we're replying to a user message, also include any AI responses to it
        if replyToMessage.type == .user {
            // Find all AI responses to this user message
            for (index, message) in messages.enumerated() {
                if message.type == .assistant && 
                   message.replyToId == messageId && 
                   !newReplyChain.contains(message.id) {
                    // Add the AI response to the chain
                    newReplyChain.append(message.id)
                    break // Only include the first AI response for now
                }
            }
        }
        
        // Set the reply chain
        replyChain = newReplyChain
        
        // Scroll to the message being replied to for context
        // (after a slight delay to ensure UI updates)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                if let scrollView = findScrollView() {
                    scrollView.scrollTo(messageId, anchor: .center)
                }
            }
        }
    }
    
    /// Clear the current reply context
    private func clearReplyContext() {
        withAnimation {
            activeReplyId = nil
            replyChain = []
        }
    }
    
    /// Helper to find the ScrollView for programmatic scrolling
    private func findScrollView() -> ScrollViewProxy? {
        // This is a placeholder since we can't actually get the ScrollViewProxy directly
        // We'll handle scrolling in our existing ScrollViewReader
        return nil
    }
    
    /// Helper to get a string preview of a message by its ID
    private func getMessagePreview(id: UUID, maxLength: Int = 50) -> String {
        // Find the message in the conversation
        if let messageIndex = messages.firstIndex(where: { $0.id == id }) {
            // Get the first content part as preview
            if let firstContent = messages[messageIndex].contents.first {
                let content = firstContent.content
                // Limit the preview length
                if content.count > maxLength {
                    return String(content.prefix(maxLength)) + "..."
                } else {
                    return content
                }
            }
        }
        return "Message"
    }
    
    /// Scroll to a specific message using the provided ScrollViewProxy
    private func scrollToMessage(_ id: UUID, in scrollView: ScrollViewProxy) {
        withAnimation {
            scrollView.scrollTo(id, anchor: .center)
        }
    }
    
    private func sendTextMessage() {
        // Get the trimmed text
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only process if there's text and we're not already processing
        guard !text.isEmpty && !isProcessing else { return }
        
        // Process the text input just like we would process transcription
        processTranscription(text)
        
        // Clear the input field
        inputText = ""
    }
    
    private func clearConversation() {
        messages.removeAll()
        OpenAIClient.shared.clearConversation()
    }
}

struct MessageView: View {
    let message: Message
    @Binding var activeReplyId: UUID?
    @Binding var replyChain: [UUID]
    let onReply: (UUID) -> Void
    let onClearReply: () -> Void
    let onClickReplyContext: (UUID) -> Void
    
    // The messages array is needed for context previews
    let getContentPreview: (UUID) -> String
    
    @State private var copiedIndex: Int? = nil
    @State private var showContextMenu = false
    
    var body: some View {
        VStack(spacing: 0) {
            // No longer showing any indicator on the message being replied to
            // to avoid duplication and visual clutter
            
            // Show a preview if this message is part of a reply chain
            if !message.replyChain.isEmpty && !message.replyChain.contains(where: { $0 == activeReplyId }) {
                ForEach(message.replyChain.prefix(1), id: \.self) { replyId in
                    Button(action: {
                        // Focus on the referenced message when clicked
                        onClickReplyContext(replyId)
                    }) {
                        HStack {
                            Image(systemName: "arrow.turn.up.left")
                                .font(.system(size: 10))
                                .foregroundColor(JetBrainsTheme.textSecondary)
                            
                            Text(getContextMessagePreview(replyId, maxLength: 40))
                                .font(.system(size: 10))
                                .foregroundColor(JetBrainsTheme.textSecondary)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(JetBrainsTheme.backgroundTertiary)
                        .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.bottom, 4)
                }
            }
            
            HStack {
                if message.type == .assistant {
                    Spacer(minLength: 30)
                }
                
                VStack(alignment: message.type == .user ? .leading : .trailing, spacing: 4) {
                    VStack(alignment: message.type == .user ? .leading : .trailing, spacing: 10) { // Increased spacing between blocks in a message
                    ForEach(Array(message.contents.enumerated()), id: \.offset) { index, content in
                        switch content.type {
                        case .text:
                            Text(content.content)
                                .font(.system(size: 14))
                                .padding(10) // Reduced padding
                                .fixedSize(horizontal: false, vertical: true) // Proper wrapping
                                .background(message.type == .user ? JetBrainsTheme.userMessage : JetBrainsTheme.assistantMessage)
                                .foregroundColor(JetBrainsTheme.textPrimary)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            message.type == .user ? 
                                                JetBrainsTheme.accentPrimary.opacity(0.3) : 
                                                JetBrainsTheme.accentSecondary.opacity(0.3),
                                            lineWidth: 1
                                        )
                                )
                        
                        case .code(let language):
                            VStack(alignment: .leading, spacing: 0) {
                                // Code header with language label and copy button
                                HStack {
                                    Text(language)
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 8) // Reduced padding
                                        .padding(.vertical, 3)   // Reduced padding
                                        .foregroundColor(JetBrainsTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        copyToClipboard(content.content)
                                        copiedIndex = index
                                        
                                        // Reset "Copied" text after 2 seconds
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            copiedIndex = nil
                                        }
                                    }) {
                                        HStack(spacing: 3) { // Reduced spacing
                                            Image(systemName: copiedIndex == index ? "checkmark" : "doc.on.doc")
                                                .font(.system(size: 11)) // Smaller icon
                                            
                                            Text(copiedIndex == index ? "Copied!" : "Copy")
                                                .font(.system(size: 11)) // Smaller text
                                        }
                                        .foregroundColor(JetBrainsTheme.textPrimary)
                                        .padding(.horizontal, 6) // Reduced padding
                                        .padding(.vertical, 3)   // Reduced padding
                                        .background(JetBrainsTheme.backgroundTertiary)
                                        .cornerRadius(4)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                .padding(.horizontal, 8) // Reduced padding
                                .padding(.vertical, 4)   // Reduced padding
                                .background(JetBrainsTheme.backgroundSecondary)
                                .clipShape(RoundedCorner(radius: 6, corners: [.topLeft, .topRight]))
                                
                                // Code content with syntax highlighting
                                ScrollView(.horizontal, showsIndicators: false) {
                                    Text(CodeHighlighter.highlightCode(content.content, language: language))
                                        .font(.system(size: 13, design: .monospaced))
                                        .lineSpacing(1) // Reduced line spacing
                                        .padding(8)      // Reduced padding
                                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                }
                                .background(JetBrainsTheme.codeBackground)
                                .clipShape(RoundedCorner(radius: 6, corners: [.bottomLeft, .bottomRight]))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(JetBrainsTheme.border, lineWidth: 1)
                                        .clipShape(RoundedCorner(radius: 6, corners: [.bottomLeft, .bottomRight]))
                                )
                            }
                            .frame(maxWidth: 500, alignment: message.type == .user ? .leading : .trailing)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(JetBrainsTheme.border, lineWidth: 1)
                            )
                            // Regular spacing between content blocks
                            .padding(.bottom, 2)
                        }
                    }
                }
                
                Text(formattedTime(for: message.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(JetBrainsTheme.textSecondary)
                    .padding(.horizontal, 5)
            }
            
            if message.type == .user {
                Spacer(minLength: 30)
            }
        }
        .contextMenu {
            Button(action: {
                onReply(message.id)
            }) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
            
            // Add copy button for the entire message
            Button(action: {
                copyMessageContent()
            }) {
                Label("Copy Message", systemImage: "doc.on.doc")
            }
            
            if activeReplyId != nil {
                Button(action: {
                    onClearReply()
                }) {
                    Label("Clear Reply", systemImage: "xmark.circle")
                }
            }
        }
        }
    }
    
    private func formattedTime(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func copyMessageContent() {
        // Combine all content parts into a single string
        let fullText = message.contents.map { content -> String in
            switch content.type {
            case .text:
                return content.content
            case .code(let language):
                return "```\(language)\n\(content.content)\n```"
            }
        }.joined(separator: "\n\n")
        
        copyToClipboard(fullText)
    }
    
    // Use provided function to get preview
    private func getMessagePreview(id: UUID, maxLength: Int = 50) -> String {
        return getContentPreview(id)
    }
    
    // Helper to handle click on reply context
    private func handleReplyContextClick(_ messageId: UUID) {
        // Delegate to the parent view through callback
        onClickReplyContext(messageId)
    }
    
    // Use provided function to get preview
    private func getContextMessagePreview(_ messageId: UUID, maxLength: Int = 50) -> String {
        return getContentPreview(messageId)
    }
}

// Extension to apply rounded corners to specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// Define our own corner enum since we're cross-platform
struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomRight = RectCorner(rawValue: 1 << 2)
    static let bottomLeft = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomRight, .bottomLeft]
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = corners.contains(.topLeft)
        let topRight = corners.contains(.topRight)
        let bottomLeft = corners.contains(.bottomLeft)
        let bottomRight = corners.contains(.bottomRight)
        
        // We directly use rect properties in the calculations
        
        // Start from top-left
        if topLeft {
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        
        // Top-right corner
        if topRight {
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                        radius: radius,
                        startAngle: Angle(degrees: -90),
                        endAngle: Angle(degrees: 0),
                        clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        
        // Bottom-right corner
        if bottomRight {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                        radius: radius,
                        startAngle: Angle(degrees: 0),
                        endAngle: Angle(degrees: 90),
                        clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        
        // Bottom-left corner
        if bottomLeft {
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                        radius: radius,
                        startAngle: Angle(degrees: 90),
                        endAngle: Angle(degrees: 180),
                        clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        
        // Top-left corner
        if topLeft {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                        radius: radius,
                        startAngle: Angle(degrees: 180),
                        endAngle: Angle(degrees: 270),
                        clockwise: false)
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        
        path.closeSubpath()
        return path
    }
}

#Preview {
    ConversationView()
        .preferredColorScheme(.dark)
}
