//

import SwiftUI

/// Appearance chosen by the user. `.system` follows the device setting.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearanceMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            L10n.string("시스템")
        case .light:
            L10n.string("라이트")
        case .dark:
            L10n.string("다크")
        }
    }

    var subtitle: String {
        switch self {
        case .system:
            L10n.string("기기의 설정을 따릅니다")
        case .light:
            L10n.string("항상 밝은 화면을 사용합니다")
        case .dark:
            L10n.string("항상 어두운 화면을 사용합니다")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
