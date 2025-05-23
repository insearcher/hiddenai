//
//  JetBrainsTheme.swift
//  HiddenWindowMCP
//
//  Created on 4/10/25.
//

import SwiftUI

/// A modern, austere dark theme for the app
struct JetBrainsTheme {
    // MARK: - Colors
    
    /// Primary background color (very dark)
    static let backgroundPrimary = Color(hex: "#0A0A0A")
    
    /// Secondary background color (for cards, panels)
    static let backgroundSecondary = Color(hex: "#141414")
    
    /// Tertiary background color (for nested elements)
    static let backgroundTertiary = Color(hex: "#1A1A1A")
    
    /// Primary accent color (muted blue)
    static let accentPrimary = Color(hex: "#4A6FA5")
    
    /// Secondary accent color (muted purple)
    static let accentSecondary = Color(hex: "#6B5B95")
    
    /// Primary text color (slightly dimmed white)
    static let textPrimary = Color(hex: "#E0E0E0")
    
    /// Secondary text color (muted gray)
    static let textSecondary = Color(hex: "#808080")
    
    /// Border color for UI elements (very subtle)
    static let border = Color(hex: "#242424")
    
    /// Success color (muted green)
    static let success = Color(hex: "#4A7C59")
    
    /// Error color (muted red)
    static let error = Color(hex: "#8B4049")
    
    /// Warning color (muted amber)
    static let warning = Color(hex: "#A67F00")
    
    /// User message background
    static let userMessage = Color(hex: "#0F0F0F")
    
    /// Assistant message background
    static let assistantMessage = Color(hex: "#121212")
    
    /// Code block background
    static let codeBackground = Color(hex: "#080808")
    
    // MARK: - Gradients
    
    /// Main background gradient (subtle)
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: "#0A0A0A"),
            Color(hex: "#0F0F0F")
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Accent gradient (subtle)
    static let accentGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: "#4A6FA5").opacity(0.8),
            Color(hex: "#6B5B95").opacity(0.8)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - UI Element Styles
    
    /// Style for primary buttons
    static func primaryButtonStyle() -> some ButtonStyle {
        return JetBrainsPrimaryButtonStyle()
    }
    
    /// Style for secondary buttons
    static func secondaryButtonStyle() -> some ButtonStyle {
        return JetBrainsSecondaryButtonStyle()
    }
    
    /// Style for cards and panels
    static func cardStyle<Content: View>(_ content: Content) -> some View {
        content
            .padding(16)
            .background(backgroundSecondary)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(border.opacity(0.5), lineWidth: 0.5)
            )
    }
}

// MARK: - Button Styles

/// Primary button style with accent background
struct JetBrainsPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? 
                JetBrainsTheme.accentPrimary.opacity(0.6) : 
                JetBrainsTheme.accentPrimary.opacity(0.8))
            .foregroundColor(JetBrainsTheme.textPrimary)
            .cornerRadius(2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Secondary button style with transparent background and border
struct JetBrainsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? 
                JetBrainsTheme.border.opacity(0.2) : 
                Color.clear)
            .foregroundColor(JetBrainsTheme.textSecondary)
            .cornerRadius(2)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(JetBrainsTheme.border.opacity(0.8), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Helper Extensions

extension Color {
    /// Initialize a color from a hex string (e.g. "#FFFFFF")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: // RGB (24-bit)
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: // ARGB (32-bit)
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, int >> 24)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

/// Toggle style with austere appearance
struct JetBrainsToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            ZStack {
                Capsule()
                    .frame(width: 44, height: 22)
                    .foregroundColor(configuration.isOn ? 
                        JetBrainsTheme.accentPrimary.opacity(0.6) : 
                        JetBrainsTheme.border)
                
                Circle()
                    .foregroundColor(JetBrainsTheme.textPrimary.opacity(0.9))
                    .padding(2)
                    .frame(width: 18, height: 18)
                    .offset(x: configuration.isOn ? 11 : -11)
                    .animation(.spring(response: 0.2), value: configuration.isOn)
            }
            .onTapGesture {
                withAnimation {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

/// Text field style with austere appearance
struct JetBrainsTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(JetBrainsTheme.backgroundTertiary)
            .cornerRadius(2)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(JetBrainsTheme.border.opacity(0.5), lineWidth: 0.5)
            )
            .foregroundColor(JetBrainsTheme.textPrimary)
    }
}
