//

import Foundation
import Observation

/// Language the app UI is shown in. Korean is the source language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    /// Name written in that language, so either choice stays recognizable.
    var nativeName: String {
        switch self {
        case .korean: "한국어"
        case .english: "English"
        }
    }
}

/// In-app language choice. Views that read `locale` refresh when it changes.
@MainActor
@Observable
final class LanguageSettings {
    static let shared = LanguageSettings()

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
        }
    }

    var locale: Locale { language.locale }

    private init() {
        let stored = UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? ""
        language = AppLanguage(rawValue: stored) ?? .korean
    }
}

/// Looks up copy in `Localizable.xcstrings` for the language chosen in the app.
@MainActor
enum L10n {
    static var locale: Locale { LanguageSettings.shared.locale }

    /// Language folder inside the app (`en.lproj`, `ko.lproj`).
    /// `String(localized:locale:)` only changes how numbers are formatted. It still
    /// loads the device language, so an in-app English choice would stay Korean.
    static var bundle: Bundle {
        let code = LanguageSettings.shared.language.rawValue
        guard
            let path = Bundle.main.path(forResource: code, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .main
        }
        return bundle
    }

    static func s(_ value: String.LocalizationValue) -> String {
        String(localized: value, bundle: bundle, locale: locale)
    }

    static func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

extension String {
    /// Translates this Korean source string. Unknown keys are returned unchanged.
    var l10n: String {
        L10n.string(self)
    }
}
