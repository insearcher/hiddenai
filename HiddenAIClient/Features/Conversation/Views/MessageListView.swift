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
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                                .onAppear {
                                    if message.id == viewModel.latestMessageId && viewModel.scrollToBottom {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                scrollView.scrollTo(message.id, anchor: .bottom)
                                            }
                                        }
                                    }
                                }
                        }
                        
                        // Show recording status if Whisper is recording - minimal style
                        if viewModel.isWhisperRecording {
                            HStack(spacing: 8) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .foregroundColor(JetBrainsTheme.error.opacity(0.6))
                                    .font(.system(size: 12, weight: .light))
                                
                                Text("RECORDING: \(viewModel.whisperRecordingTime)")
                                    .font(.system(size: 11, weight: .light, design: .monospaced))
                                    .tracking(1)
                                    .foregroundColor(JetBrainsTheme.error.opacity(0.8))
                            }
                            .padding(10)
                            .background(JetBrainsTheme.error.opacity(0.05))
                            .cornerRadius(2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(JetBrainsTheme.error.opacity(0.2), lineWidth: 0.5)
                            )
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(20)
                    .onChange(of: viewModel.messages) { 
                        if let lastMessage = viewModel.messages.last {
                            viewModel.latestMessageId = lastMessage.id
                            
                            if viewModel.scrollToBottom {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            } else {
                                viewModel.showScrollToButton = true
                            }
                        }
                    }
                }
                .background(JetBrainsTheme.backgroundPrimary)
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        viewModel.scrollToBottom = false
                        viewModel.showScrollToButton = true
                    }
                )
                
                // Minimal scroll to latest button
                if viewModel.showScrollToButton && !viewModel.messages.isEmpty {
                    Button(action: {
                        if let lastId = viewModel.messages.last?.id {
                            withAnimation(.easeOut(duration: 0.2)) {
                                scrollView.scrollTo(lastId, anchor: .bottom)
                                viewModel.scrollToBottom = true
                                viewModel.showScrollToButton = false
                            }
                        }
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(JetBrainsTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(JetBrainsTheme.backgroundSecondary)
                            .cornerRadius(2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(JetBrainsTheme.border.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.bottom, 20)
                    .padding(.trailing, 20)
                    .transition(.opacity)
                }
            }
        }
    }
}
