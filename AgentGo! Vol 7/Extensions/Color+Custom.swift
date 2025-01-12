import SwiftUI

extension Color {
    static let customDarkBackground = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let customDarkSurface = Color(red: 0.15, green: 0.15, blue: 0.15)
    static let customDarkBorder = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let customLightBackground = Color(red: 0.95, green: 0.94, blue: 0.92) // #f2efeb
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    static func backgroundFor(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? customDarkBackground : customLightBackground
    }
    
    static func surfaceFor(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? customDarkSurface : .white
    }
    
    static func borderFor(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? customDarkBorder : .black.opacity(0.1)
    }
}

extension ShapeStyle where Self == Color {
    static var customAccent: Color { .customAccent }
} 
