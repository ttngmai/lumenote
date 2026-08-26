//

import SwiftUI

/// Colors for the app chrome, resolved for the active color scheme.
/// Views read this from `@Environment(\.appPalette)` so light and dark can diverge
/// where a single value would be unreadable.
struct AppPalette {
    let colorScheme: ColorScheme

    private var isDark: Bool { colorScheme == .dark }

    // MARK: Surfaces

    var backgroundColors: [Color] {
        isDark
            ? [Color(red: 0.09, green: 0.09, blue: 0.11), Color(red: 0.12, green: 0.13, blue: 0.16)]
            : [Color(red: 0.97, green: 0.96, blue: 0.93), Color(red: 0.92, green: 0.94, blue: 0.96)]
    }

    /// Translucent card background used by the selectors and info cards.
    var cardBackground: Color {
        isDark ? Color(white: 0.16).opacity(0.9) : Color.white.opacity(0.85)
    }

    /// Opaque surface used by the selection popup.
    var popupBackground: Color {
        isDark ? Color(white: 0.14) : Color.white
    }

    var popupHeaderBackground: Color {
        isDark ? Color(white: 0.24) : Color.black
    }

    var popupHeaderForeground: Color { .white }

    var scrim: Color {
        Color.black.opacity(isDark ? 0.5 : 0.28)
    }

    // MARK: Lines

    var cardBorder: Color {
        isDark ? Color(white: 0.85).opacity(0.35) : Color.black.opacity(0.75)
    }

    var cardBorderActive: Color {
        isDark ? Color(white: 0.95) : Color.black
    }

    var divider: Color {
        isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    /// Outlines and separators inside the circle.
    var ringStroke: Color {
        isDark ? Color(white: 0.7) : Color(red: 0.15, green: 0.15, blue: 0.15)
    }

    // MARK: Circle fills

    /// Warm red / neon coral. Dark mode uses a fluorescent tone for readability.
    var major: Color {
        isDark
            ? Color(red: 1.0, green: 0.38, blue: 0.48)
            : Color(red: 0xE9 / 255, green: 0x5D / 255, blue: 0x5D / 255)
    }

    /// Cool blue / neon azure.
    var minor: Color {
        isDark
            ? Color(red: 0.35, green: 0.72, blue: 1.0)
            : Color(red: 0x4F / 255, green: 0x81 / 255, blue: 0xEE / 255)
    }

    /// Purple / neon violet.
    var diminished: Color {
        isDark
            ? Color(red: 0.78, green: 0.45, blue: 1.0)
            : Color(red: 0x9A / 255, green: 0x64 / 255, blue: 0xDB / 255)
    }

    /// Non-diatonic wedges.
    var chromaticFill: Color {
        isDark ? Color(white: 0.34) : Color(white: 0.86)
    }

    // MARK: Quiz feedback

    /// Soft green fill behind a correct quiz choice.
    var quizCorrectBackground: Color {
        isDark
            ? Color(red: 0.12, green: 0.32, blue: 0.2)
            : Color(red: 0.86, green: 0.95, blue: 0.88)
    }

    /// Green border / checkmark for a correct quiz choice.
    var quizCorrect: Color {
        isDark
            ? Color(red: 0.35, green: 1.0, blue: 0.55)
            : Color(red: 0.22, green: 0.68, blue: 0.42)
    }

    /// Soft red fill behind an incorrect selected quiz choice.
    var quizIncorrectBackground: Color {
        isDark
            ? Color(red: 0.36, green: 0.12, blue: 0.16)
            : Color(red: 0.98, green: 0.90, blue: 0.90)
    }

    /// Red border / xmark for an incorrect selected quiz choice.
    var quizIncorrect: Color {
        major
    }

    // MARK: Emphasis

    /// Chip behind a highlighted formula degree / scale column / selected row.
    /// Dark mode uses a bright amber that still keeps white text readable.
    var highlight: Color {
        isDark ? Color(red: 0.55, green: 0.42, blue: 0.08) : Color(red: 1.0, green: 0.88, blue: 0.65)
    }

    /// Softer variant behind the characteristic note row.
    var highlightSoft: Color {
        isDark ? Color(red: 0.36, green: 0.28, blue: 0.08) : Color(red: 1.0, green: 0.95, blue: 0.86)
    }

    var star: Color {
        isDark ? Color(red: 1.0, green: 0.88, blue: 0.28) : Color(red: 0.85, green: 0.55, blue: 0.1)
    }

    var emphasisFill: Color {
        Color(red: 1.0, green: 0.88, blue: 0.2).opacity(isDark ? 0.38 : 0.42)
    }

    var emphasisStroke: Color {
        isDark
            ? Color(red: 1.0, green: 0.85, blue: 0.2)
            : Color(red: 0.92, green: 0.55, blue: 0.08)
    }

    /// Background of a rarely used tonic row in the picker.
    var obscureRow: Color {
        isDark ? Color(white: 0.22) : Color(white: 0.91)
    }

    /// Drop-shadow opacity for the raised tonic wedge.
    var raisedWedgeShadowOpacity: Double {
        isDark ? 0.45 : 0.2
    }
}

// MARK: - Environment

private struct AppPaletteKey: EnvironmentKey {
    static let defaultValue = AppPalette(colorScheme: .light)
}

extension EnvironmentValues {
    var appPalette: AppPalette {
        get { self[AppPaletteKey.self] }
        set { self[AppPaletteKey.self] = newValue }
    }
}

extension View {
    /// Resolves `AppPalette` from the current color scheme and injects it for descendants.
    func lumenotePalette() -> some View {
        modifier(LumenotePaletteModifier())
    }
}

private struct LumenotePaletteModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.environment(\.appPalette, AppPalette(colorScheme: colorScheme))
    }
}
