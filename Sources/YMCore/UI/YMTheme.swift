import SwiftUI

/// Modern theme and visual design tokens inspired by native macOS styling in KinoPohuy / Apple Music.
public enum YMTheme {
    public static let bg = Color(red: 11 / 255, green: 11 / 255, blue: 13 / 255)
    public static let surface = Color(red: 22 / 255, green: 22 / 255, blue: 26 / 255)
    public static let surfaceHigh = Color(red: 32 / 255, green: 32 / 255, blue: 38 / 255)
    public static let border = Color.white.opacity(0.08)
    public static let borderHover = Color.white.opacity(0.25)

    public static let fg = Color(red: 245 / 255, green: 245 / 255, blue: 247 / 255)
    public static let fg80 = fg.opacity(0.8)
    public static let fg60 = fg.opacity(0.6)
    public static let fg40 = fg.opacity(0.4)

    public static let accent = Color(red: 255 / 255, green: 204 / 255, blue: 0 / 255) // Yandex Yellow #FFCC00
    public static let heartRed = Color(red: 255 / 255, green: 59 / 255, blue: 48 / 255) // iOS Red

    public static let cornerRadiusLarge: CGFloat = 14
    public static let cornerRadiusMedium: CGFloat = 10
    public static let cornerRadiusSmall: CGFloat = 6
}

// MARK: - Glass & Translucency Modifiers

public struct YMGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let tint: Color?

    public func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill((tint ?? .black).opacity(0.35))
                    shape.stroke(YMTheme.border, lineWidth: 1)
                }
                .environment(\.colorScheme, .dark)
            }
    }
}

public extension View {
    func ymGlass<S: Shape>(in shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        modifier(YMGlassModifier(shape: shape, interactive: interactive, tint: tint))
    }

    func ymGlassCapsule(interactive: Bool = false, tint: Color? = nil) -> some View {
        ymGlass(in: Capsule(), interactive: interactive, tint: tint)
    }

    func ymScreenBackground() -> some View {
        background(YMTheme.bg.ignoresSafeArea())
    }
}

// MARK: - Interactive Card Hover Modifier

public struct YMCardHoverModifier: ViewModifier {
    @UIState private var isHovered = false
    let cornerRadius: CGFloat
    let scale: CGFloat

    public init(cornerRadius: CGFloat = YMTheme.cornerRadiusMedium, scale: CGFloat = 1.04) {
        self.cornerRadius = cornerRadius
        self.scale = scale
    }

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isHovered ? YMTheme.borderHover : Color.clear, lineWidth: 1.5)
            }
            .shadow(
                color: Color.black.opacity(isHovered ? 0.45 : 0.15),
                radius: isHovered ? 16 : 4,
                y: isHovered ? 8 : 2
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovered)
            .onHover { inside in
                isHovered = inside
            }
    }
}

public extension View {
    func ymCardHover(cornerRadius: CGFloat = YMTheme.cornerRadiusMedium, scale: CGFloat = 1.03) -> some View {
        modifier(YMCardHoverModifier(cornerRadius: cornerRadius, scale: scale))
    }
}

// MARK: - Buttons

/// Glass pill button with hover scaling and icon
public struct YMGlassPillButtonStyle: ButtonStyle {
    public var primary: Bool = false
    public var height: CGFloat = 32

    @UIState private var hover = false

    public init(primary: Bool = false, height: CGFloat = 32) {
        self.primary = primary
        self.height = height
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(primary ? Color.black : YMTheme.fg)
            .padding(.horizontal, 14)
            .frame(height: height)
            .background {
                if primary {
                    Capsule()
                        .fill(hover ? Color.white : YMTheme.accent)
                } else {
                    Capsule()
                        .fill(hover ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                        .overlay(Capsule().strokeBorder(YMTheme.border, lineWidth: 1))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : hover ? 1.03 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hover)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .onHover { hover = $0 }
    }
}
