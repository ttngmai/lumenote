//

import SwiftUI

/// Home-screen row that switches the app between Korean and English.
struct LanguageMenuButton: View {
    private var settings: LanguageSettings { .shared }

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    settings.language = language
                } label: {
                    if settings.language == language {
                        Label(language.nativeName, systemImage: "checkmark")
                    } else {
                        Text(language.nativeName)
                    }
                }
            }
        } label: {
            HStack(spacing: LumenoteSpacing.xxl) {
                Image(systemName: "globe")
                    .font(LumenoteFont.rounded(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: LumenoteSpacing.xxs) {
                    Text("언어 설정".l10n)
                        .font(LumenoteFont.body(.bold))
                        .foregroundStyle(.primary)
                    Text("앱에서 사용할 언어를 선택하세요".l10n)
                        .font(LumenoteFont.caption(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, LumenoteSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\("언어 설정".l10n), \("앱에서 사용할 언어를 선택하세요".l10n)")
    }
}
