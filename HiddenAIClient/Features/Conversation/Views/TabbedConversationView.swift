//
//  TabbedConversationView.swift
//  HiddenAIClient
//
//  Created for tabbed conversation interface
//

import SwiftUI

struct TabbedConversationView: View {
    @ObservedObject var viewModel: ConversationViewModel
    @State private var showScrollToButton = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            if !viewModel.conversationTabs.isEmpty {
                TabBarView(viewModel: viewModel)
                    .background(JetBrainsTheme.backgroundSecondary)
                
                // Separator
                Rectangle()
                    .fill(JetBrainsTheme.border.opacity(0.3))
                    .frame(height: 0.5)
            }
            
            // Content area
            ZStack {
                if viewModel.conversationTabs.isEmpty && !viewModel.isProcessing {
                    // Empty state (only when not processing)
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundColor(JetBrainsTheme.textSecondary.opacity(0.5))
                        
                        Text("Start a conversation")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(JetBrainsTheme.textSecondary.opacity(0.7))
                        
                        Text("Type a message or use voice recording")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(JetBrainsTheme.textSecondary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(JetBrainsTheme.backgroundPrimary)
                } else if viewModel.conversationTabs.isEmpty && viewModel.isProcessing {
                    // Processing state when no tabs exist yet
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(viewModel.processingStage.displayText)
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(JetBrainsTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(JetBrainsTheme.backgroundPrimary)
                } else {
                    // Show current tab content
                    TabContentView(viewModel: viewModel, showScrollToButton: $showScrollToButton)
                        .background(JetBrainsTheme.backgroundPrimary)
                }
            }
        }
    }
}

struct TabBarView: View {
    @ObservedObject var viewModel: ConversationViewModel
    @State private var scrollViewOffset: CGFloat = 0
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(viewModel.conversationTabs.enumerated()), id: \.element.id) { index, tab in
                        TabButton(
                            tab: tab,
                            isSelected: index == viewModel.selectedTabIndex,
                            isComplete: tab.isComplete,
                            action: {
                                viewModel.selectTab(at: index)
                            }
                        )
                        .id(index)
                    }
                }
                .padding(.horizontal, 12)
            }
            .onChange(of: viewModel.selectedTabIndex) { oldValue, newIndex in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onChange(of: viewModel.conversationTabs.count) { oldValue, newCount in
                // Auto-scroll to the latest tab when a new one is added
                if !viewModel.conversationTabs.isEmpty {
                    let latestIndex = viewModel.conversationTabs.count - 1
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(latestIndex, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 44)
    }
}

struct TabButton: View {
    let tab: ConversationTab
    let isSelected: Bool
    let isComplete: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                
                // Tab title
                Text(tab.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 80, maxWidth: 200)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: isSelected ? 1 : 0.5)
            )
            .cornerRadius(6)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var statusColor: Color {
        if !isComplete {
            return JetBrainsTheme.accentColor // Processing
        } else {
            return JetBrainsTheme.success // Complete
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return JetBrainsTheme.textPrimary
        } else {
            return JetBrainsTheme.textSecondary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return JetBrainsTheme.backgroundPrimary
        } else if isHovered {
            return JetBrainsTheme.backgroundTertiary.opacity(0.7)
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return JetBrainsTheme.accentColor
        } else {
            return JetBrainsTheme.border.opacity(0.3)
        }
    }
}

struct TabContentView: View {
    @ObservedObject var viewModel: ConversationViewModel
    @Binding var showScrollToButton: Bool
    
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.currentTabMessages) { message in
                            MessageView(
                                message: message,
                                onDelete: { _ in }
                            )
                            .id(message.id)
                        }
                        
                        // Show processing indicator if assistant response is pending
                        if let tab = viewModel.currentTab, !tab.isComplete && viewModel.isProcessing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(viewModel.processingStage.displayText)
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(JetBrainsTheme.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(JetBrainsTheme.backgroundSecondary)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .onChange(of: viewModel.latestMessageId) { oldValue, messageId in
                    if let messageId = messageId {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(messageId, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Scroll to bottom button
            if showScrollToButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: scrollToBottom) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(JetBrainsTheme.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(JetBrainsTheme.backgroundSecondary)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
    
    private func scrollToBottom() {
        // This will be handled by the ScrollViewReader proxy in the closure
        showScrollToButton = false
    }
}