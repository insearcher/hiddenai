//
//  SettingsView.swift
//  HiddenWindowMCP
//
//  Created by Claude on 4/9/25.
//

import SwiftUI
import AppKit

// NSTextField wrapper to support paste operations
struct PasteEnabledSecureField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    
    func makeNSView(context: Context) -> NSSecureTextField {
        let textField = NSSecureTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.stringValue = text
        textField.bezelStyle = .roundedBezel
        textField.isBezeled = true
        
        // JetBrains-style colors
        textField.backgroundColor = NSColor(red: 0.19, green: 0.20, blue: 0.22, alpha: 1.0) // Dark background
        textField.textColor = NSColor(red: 0.87, green: 0.88, blue: 0.89, alpha: 1.0) // Light text
        
        // Enable right-click context menu with paste option
        textField.menu = createContextMenu(for: textField)
        
        // Add notification when becomes first responder
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow,
               window.firstResponder?.isKind(of: NSText.self) == true ||
               window.firstResponder?.isKind(of: NSTextField.self) == true {
                // Notify that a text field is now focused
                NotificationCenter.default.post(
                    name: .textFieldFocusChanged,
                    object: ["focused": true]
                )
                print("Text field gained focus - disabling shortcuts")
            }
        }
        
        return textField
    }
    
    private func createContextMenu(for textField: NSTextField) -> NSMenu {
        let menu = NSMenu()
        
        // Add Cut menu item
        let cutItem = NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(cutItem)
        
        // Add Copy menu item
        let copyItem = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(copyItem)
        
        // Add Paste menu item
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(pasteItem)
        
        // Add Select All menu item
        let selectAllItem = NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        menu.addItem(selectAllItem)
        
        return menu
    }
    
    func updateNSView(_ nsView: NSSecureTextField, context: Context) {
        nsView.stringValue = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PasteEnabledSecureField
        
        init(_ parent: PasteEnabledSecureField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func controlTextDidBeginEditing(_ obj: Notification) {
            // Notify that a text field has gained focus
            NotificationCenter.default.post(
                name: .textFieldFocusChanged,
                object: ["focused": true]
            )
            print("Text field began editing - disabling shortcuts")
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            // Notify that a text field has lost focus
            NotificationCenter.default.post(
                name: .textFieldFocusChanged,
                object: ["focused": false]
            )
            print("Text field ended editing - enabling shortcuts")
        }
    }
}

struct SettingsView: View {
    @State private var apiKey: String = SettingsManager.shared.apiKey
    @State private var windowTransparency: Double = SettingsManager.shared.windowTransparency
    @State private var position: String = SettingsManager.shared.position
    @State private var showSavedMessage = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                    .padding(.bottom, 10)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("OpenAI API Key")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                
                HStack(spacing: 8) {
                    PasteEnabledSecureField(text: $apiKey, placeholder: "Paste your OpenAI API key here")
                        .frame(height: 32)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(JetBrainsTheme.border, lineWidth: 1)
                        )
                    
                    Button(action: pasteFromClipboard) {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(JetBrainsTheme.textPrimary)
                            .padding(6)
                            .background(JetBrainsTheme.accentPrimary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Paste API key from clipboard")
                }
                
                Text("Your API key is stored locally. Use the clipboard button to paste your key.")
                    .font(.system(size: 12))
                    .foregroundColor(JetBrainsTheme.textSecondary)
            }
            .padding(12)
            .background(JetBrainsTheme.backgroundSecondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(JetBrainsTheme.border, lineWidth: 1)
            )
            
            // Authentication section removed for open source version
            
            // Features section with speech recognition toggles removed - now only using Whisper
            
            VStack(alignment: .leading, spacing: 10) {
                Text("AI Conversation Context")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                
                TextEditor(text: $position)
                    .font(.system(size: 14))
                    .padding(10)
                    .frame(height: 180) // Increased height for larger context
                    .background(JetBrainsTheme.backgroundTertiary)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(position.count > 1000 ? JetBrainsTheme.error : JetBrainsTheme.border, lineWidth: 1)
                    )
                
                HStack {
                    Text("\(position.count)/1000 characters")
                        .font(.system(size: 12))
                        .foregroundColor(position.count > 1000 ? JetBrainsTheme.error : JetBrainsTheme.textSecondary)
                    
                    Spacer()
                }
                
                Text("Define the context for AI responses. This will be included in all conversations as a system message. You can define a role, add specific instructions, or set the tone for AI responses.")
                    .font(.system(size: 12))
                    .foregroundColor(JetBrainsTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                    .background(JetBrainsTheme.border)
                    .padding(.vertical, 6)
                
                Text("Example templates:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                
                HStack {
                    Button(action: {
                        position = "You are a helpful coding assistant. Provide clear, concise explanations and focus on best practices in your code examples."
                    }) {
                        Text("Coding Assistant")
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(JetBrainsSecondaryButtonStyle())
                    
                    Button(action: {
                        position = "You are a senior software engineer in a technical interview. Respond to questions as if you're demonstrating your expertise during a job interview."
                    }) {
                        Text("Interview Mode")
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(JetBrainsSecondaryButtonStyle())
                }
            }
            .padding(12)
            .background(JetBrainsTheme.backgroundSecondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(JetBrainsTheme.border, lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Window Appearance")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                
                HStack {
                    Text("Transparency: \(Int(windowTransparency * 100))%")
                        .foregroundColor(JetBrainsTheme.textPrimary)
                        .font(.system(size: 14))
                    
                    Spacer()
                }
                
                HStack {
                    Text("Opaque")
                        .font(.system(size: 12))
                        .foregroundColor(JetBrainsTheme.textSecondary)
                    
                    Slider(value: $windowTransparency, in: 0...1, step: 0.01)
                        .accentColor(JetBrainsTheme.accentPrimary)
                    
                    Text("Transparent")
                        .font(.system(size: 12))
                        .foregroundColor(JetBrainsTheme.textSecondary)
                }
                .padding(.bottom, 5)
                
                Text("The default transparency is 0% (fully opaque)")
                    .font(.system(size: 12))
                    .foregroundColor(JetBrainsTheme.textSecondary)
            }
            .padding(12)
            .background(JetBrainsTheme.backgroundSecondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(JetBrainsTheme.border, lineWidth: 1)
            )
            
            // Information section with open source details
            VStack(alignment: .leading, spacing: 10) {
                Text("About HiddenAI")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                
                Text("HiddenAI is an open source application that provides a floating, hideable window for interacting with OpenAI's GPT-4o model.")
                    .font(.system(size: 13))
                    .foregroundColor(JetBrainsTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
                
                HStack {
                    Text("Version:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(JetBrainsTheme.textSecondary)
                    
                    Text("1.0.0")
                        .font(.system(size: 13))
                        .foregroundColor(JetBrainsTheme.textPrimary)
                    
                    Spacer()
                }
                
                HStack {
                    Text("License:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(JetBrainsTheme.textSecondary)
                    
                    Text("MIT")
                        .font(.system(size: 13))
                        .foregroundColor(JetBrainsTheme.textPrimary)
                    
                    Spacer()
                }
                
                // GitHub link
                Button(action: {
                    if let url = URL(string: "https://github.com/insearcher/HiddenAI") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 14))
                        
                        Text("GitHub Repository")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(JetBrainsTheme.accentPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(JetBrainsSecondaryButtonStyle())
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(JetBrainsTheme.accentPrimary.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(12)
            .background(JetBrainsTheme.backgroundSecondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(JetBrainsTheme.border, lineWidth: 1)
            )
            
            HStack {
                Button(action: saveSettings) {
                    Text("Save Settings")
                        .foregroundColor(JetBrainsTheme.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(JetBrainsTheme.accentPrimary)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(JetBrainsTheme.accentPrimary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(JetBrainsPrimaryButtonStyle())
                
                if showSavedMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(JetBrainsTheme.success)
                        
                        Text("Settings saved!")
                            .foregroundColor(JetBrainsTheme.success)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.top, 20)
            }
            .padding(20)
            .padding(.bottom, 10) // Add extra padding at the bottom for scrolling
        }
        .background(JetBrainsTheme.backgroundPrimary)
        .cornerRadius(8)
        .frame(width: 420, height: 580)
    }
    
    private func pasteFromClipboard() {
        // Get content from clipboard
        if let clipboardContent = NSPasteboard.general.string(forType: .string) {
            apiKey = clipboardContent
        }
    }
    
    private func saveSettings() {
        // Save settings to SettingsManager
        SettingsManager.shared.apiKey = apiKey
        SettingsManager.shared.windowTransparency = windowTransparency
        // Save position with character limit (now 1000 characters)
        SettingsManager.shared.position = String(position.prefix(1000))
        
        // Show saved message
        withAnimation {
            showSavedMessage = true
        }
        
        // Hide message after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSavedMessage = false
            }
        }
        
        // If API key is set for the first time, show a success message
        if !apiKey.isEmpty && SettingsManager.shared.apiKey.isEmpty {
            let alert = NSAlert()
            alert.messageText = "API Key Saved"
            alert.informativeText = "Your OpenAI API key has been saved. You can now use all features of the application."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    // Sign out functionality removed for open source version
}

#Preview {
    SettingsView()
        .environment(\.colorScheme, .dark)
}
