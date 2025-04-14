//
//  JetBrainsTheme.swift
//  HiddenWindowMCP
//
//  Created on 4/10/25.
//

import SwiftUI

/// A modern, JetBrains IDE-inspired theme for the app
struct JetBrainsTheme {
    // MARK: - Colors
    
    /// Primary background color (darkest)
    static let backgroundPrimary = Color(hex: "#1E1F22")
    
    /// Secondary background color (for cards, panels)
    static let backgroundSecondary = Color(hex: "#2B2D30")
    
    /// Tertiary background color (for nested elements)
    static let backgroundTertiary = Color(hex: "#313438")
    
    /// Primary accent color (blue)
    static let accentPrimary = Color(hex: "#3574F0")
    
    /// Secondary accent color (purple)
    static let accentSecondary = Color(hex: "#A36AF9")
    
    /// Primary text color (nearly white)
    static let textPrimary = Color(hex: "#DFE1E5")
    
    /// Secondary text color (gray)
    static let textSecondary = Color(hex: "#8C8C8C")
    
    /// Border color for UI elements
    static let border = Color(hex: "#393B40")
    
    /// Success color (green)
    static let success = Color(hex: "#369668")
    
    /// Error color (red)
    static let error = Color(hex: "#F93967")
    
    /// Warning color (yellow)
    static let warning = Color(hex: "#FFC700")
    
    /// User message background
    static let userMessage = Color(hex: "#2B2D30")
    
    /// Assistant message background
    static let assistantMessage = Color(hex: "#25292E")
    
    /// Code block background
    static let codeBackground = Color(hex: "#1A1D21")
    
    // MARK: - Gradients
    
    /// Main background gradient
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(hex: "#1A1A1A"),
            Color(hex: "#262930")
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Accent gradient
    static let accentGradient = LinearGradient(
        gradient: Gradient(colors: [accentPrimary, accentSecondary]),
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
            .padding()
            .background(backgroundSecondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(border, lineWidth: 1)
            )
    }
}

// MARK: - Button Styles

/// Primary button style with accent background
struct JetBrainsPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? JetBrainsTheme.accentPrimary.opacity(0.8) : JetBrainsTheme.accentPrimary)
            .foregroundColor(.white)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(JetBrainsTheme.accentPrimary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Secondary button style with transparent background and border
struct JetBrainsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? JetBrainsTheme.border.opacity(0.3) : Color.clear)
            .foregroundColor(JetBrainsTheme.textPrimary)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(JetBrainsTheme.border, lineWidth: 1)
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

/// Toggle style with JetBrains appearance
struct JetBrainsToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            ZStack {
                Capsule()
                    .frame(width: 50, height: 24)
                    .foregroundColor(configuration.isOn ? JetBrainsTheme.accentPrimary : JetBrainsTheme.border)
                
                Circle()
                    .foregroundColor(.white)
                    .padding(2)
                    .frame(width: 22, height: 22)
                    .offset(x: configuration.isOn ? 13 : -13)
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

/// Text field style with JetBrains appearance
struct JetBrainsTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10)
            .background(JetBrainsTheme.backgroundTertiary)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(JetBrainsTheme.border, lineWidth: 1)
            )
            .foregroundColor(JetBrainsTheme.textPrimary)
    }
}
