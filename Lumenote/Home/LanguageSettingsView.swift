//

import SwiftUI

/// Picks the language used throughout the app.
struct LanguageSettingsView: View {
    private var settings: LanguageSettings { .shared }

    var body: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        settings.language = language
                    } label: {
                        SettingsOptionRow(
                            title: language.nativeName,
                            isSelected: settings.language == language
                        )
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("앱에서 사용할 언어를 선택하세요".l10n)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SettingsPageBackground())
        .lumenoteCompactHeader(title: "언어 설정", showsBackButton: true)
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
    .lumenotePalette()
}
