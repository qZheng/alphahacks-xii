import SwiftUI
import UIKit

enum AppColors {
    static let spaceCadet = Color(hex: "18BF57")
    static let indigoDye = Color(hex: "1B4661")
    static let midnightGreen = Color(hex: "19454B")
    static let castletonGreen = Color(hex: "1BB156")
    static let deepGreen = Color(hex: "18573B")

    static let accentPop = Color(hex: "2AAE86")
    static let brightGreen = Color(hex: "2EFF6B")

    static let backgroundGradient = LinearGradient(
        colors: [spaceCadet, indigoDye, midnightGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardFill = Color.white.opacity(0.10)
    static let cardStroke = Color.white.opacity(0.14)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.75)
    static let danger = Color.red.opacity(0.9)
    static let success = castletonGreen
}

extension Color {
    init(hex: String, alpha: Double = 1.0) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: alpha
        )
    }
}

struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            AppColors.backgroundGradient.ignoresSafeArea()
            content
        }
    }
}

struct AppCard: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppColors.cardFill)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppColors.cardStroke, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 8)
    }
}


struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.castletonGreen.opacity(configuration.isPressed ? 0.90 : 1.0))
            )
            .foregroundStyle(.white)
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct AppTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .foregroundStyle(.white)
    }
}

extension View {
    func appScreen() -> some View { self.modifier(AppBackground()) }
    func appCard(padding: CGFloat = 16) -> some View { self.modifier(AppCard(padding: padding)) }
    func appTextField() -> some View { self.modifier(AppTextFieldStyle()) }
    func whiteNavigationBarTint() -> some View {
        self.onAppear {
            UINavigationBar.appearance().tintColor = .white
        }
    }
}
