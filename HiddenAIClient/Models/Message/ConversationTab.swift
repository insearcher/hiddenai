//
//  ConversationTab.swift
//  HiddenAIClient
//
//  Created for tabbed conversation interface
//

import Foundation

/// Represents a single conversation tab containing a question-answer pair
struct ConversationTab: Identifiable, Equatable {
    let id = UUID()
    let userMessage: Message
    let assistantMessage: Message?
    let timestamp: Date
    
    /// Display title for the tab (truncated user message)
    var title: String {
        let userText = userMessage.contents.first?.content ?? "New Question"
        if userText.count > 30 {
            return String(userText.prefix(30)) + "..."
        }
        return userText
    }
    
    /// Whether this tab has both question and answer
    var isComplete: Bool {
        return assistantMessage != nil
    }
    
    init(userMessage: Message, assistantMessage: Message? = nil, timestamp: Date = Date()) {
        self.userMessage = userMessage
        self.assistantMessage = assistantMessage
        self.timestamp = timestamp
    }
    
    static func == (lhs: ConversationTab, rhs: ConversationTab) -> Bool {
        return lhs.id == rhs.id &&
               lhs.userMessage == rhs.userMessage &&
               lhs.assistantMessage == rhs.assistantMessage
    }
}