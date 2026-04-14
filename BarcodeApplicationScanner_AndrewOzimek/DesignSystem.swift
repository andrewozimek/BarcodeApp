import SwiftUI

// Modern Design System for Barcode Scanner App
struct AppTheme {
    // MARK: - Colors
    struct Colors {
        // Primary Brand Colors
        static let primary = Color(red: 0.2, green: 0.4, blue: 1.0)  // Vibrant Blue
        static let primaryLight = Color(red: 0.4, green: 0.6, blue: 1.0)
        static let primaryDark = Color(red: 0.1, green: 0.3, blue: 0.8)
        
        // Accent Colors
        static let accent = Color(red: 1.0, green: 0.4, blue: 0.6)  // Coral Pink
        static let success = Color(red: 0.2, green: 0.8, blue: 0.4)  // Green
        static let warning = Color(red: 1.0, green: 0.7, blue: 0.0)  // Orange
        static let error = Color(red: 1.0, green: 0.3, blue: 0.3)  // Red
        
        // Neutral Colors
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)
        
        // Text Colors
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)
        
        // Card Colors
        static let cardBackground = Color(.systemBackground)
        static let cardShadow = Color.black.opacity(0.1)
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let pill: CGFloat = 999
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let small = ShadowStyle(color: Colors.cardShadow, radius: 4, x: 0, y: 2)
        static let medium = ShadowStyle(color: Colors.cardShadow, radius: 8, x: 0, y: 4)
        static let large = ShadowStyle(color: Colors.cardShadow, radius: 16, x: 0, y: 8)
    }
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Custom View Modifiers

struct CardStyle: ViewModifier {
    var backgroundColor: Color = AppTheme.Colors.cardBackground
    var cornerRadius: CGFloat = AppTheme.CornerRadius.lg
    var shadow: ShadowStyle = AppTheme.Shadows.medium
    
    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var isLarge: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isLarge ? AppTheme.Typography.title3 : AppTheme.Typography.headline)
            .foregroundColor(.white)
            .padding(.horizontal, isLarge ? AppTheme.Spacing.xl : AppTheme.Spacing.lg)
            .padding(.vertical, isLarge ? AppTheme.Spacing.md : AppTheme.Spacing.sm)
            .background(
                LinearGradient(
                    colors: [AppTheme.Colors.primary, AppTheme.Colors.primaryDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(AppTheme.CornerRadius.pill)
            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundColor(AppTheme.Colors.primary)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(AppTheme.Colors.primary.opacity(0.1))
            .cornerRadius(AppTheme.CornerRadius.pill)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle(backgroundColor: Color = AppTheme.Colors.cardBackground,
                   cornerRadius: CGFloat = AppTheme.CornerRadius.lg,
                   shadow: ShadowStyle = AppTheme.Shadows.medium) -> some View {
        self.modifier(CardStyle(backgroundColor: backgroundColor, cornerRadius: cornerRadius, shadow: shadow))
    }
    
    func glassEffect() -> some View {
        self
            .background(.ultraThinMaterial)
            .cornerRadius(AppTheme.CornerRadius.lg)
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                AppTheme.Colors.primary.opacity(0.3),
                AppTheme.Colors.primaryLight.opacity(0.2),
                AppTheme.Colors.accent.opacity(0.3)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    var color: Color = AppTheme.Colors.primary
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: color.opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            
            Text(title)
                .font(AppTheme.Typography.title2)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(message)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, AppTheme.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
