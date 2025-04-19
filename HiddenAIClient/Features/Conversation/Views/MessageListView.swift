//
//  MessageListView.swift
//  HiddenAIClient
//
//  Created on 4/20/25.
//

import SwiftUI

/// View for the scrollable list of messages in the conversation
struct MessageListView: View {
    @ObservedObject var viewModel: ConversationViewModel
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                                .onAppear {
                                    // Track when the message becomes visible
                                    if message.id == viewModel.latestMessageId && viewModel.scrollToBottom {
                                        // Delay to ensure rendering is complete
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            withAnimation {
                                                scrollView.scrollTo(message.id, anchor: .bottom)
                                            }
                                        }
                                    }
                                }
                        }
                        
                        // Show recording status if Whisper is recording
                        if viewModel.isWhisperRecording {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundColor(JetBrainsTheme.error)
                                    .font(.system(size: 14))
                                
                                Text("Recording with Whisper: \(viewModel.whisperRecordingTime)")
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
                    }
                    .padding()
                    .onChange(of: viewModel.messages) { 
                        if let lastMessage = viewModel.messages.last {
                            viewModel.latestMessageId = lastMessage.id
                            
                            // Auto-scroll to the new message if auto-scroll is enabled
                            if viewModel.scrollToBottom {
                                withAnimation {
                                    scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            } else {
                                // Show the scroll-to-bottom button
                                viewModel.showScrollToButton = true
                            }
                        }
                    }
                }
                .background(JetBrainsTheme.backgroundPrimary)
                // Detect when user manually scrolls
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        viewModel.scrollToBottom = false
                        viewModel.showScrollToButton = true
                    }
                )
                
                // Scroll to latest button appears when needed
                if viewModel.showScrollToButton && !viewModel.messages.isEmpty {
                    Button(action: {
                        if let lastId = viewModel.messages.last?.id {
                            withAnimation {
                                scrollView.scrollTo(lastId, anchor: .bottom)
                                viewModel.scrollToBottom = true
                                viewModel.showScrollToButton = false
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
    }
}
