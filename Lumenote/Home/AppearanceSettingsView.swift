//

import SwiftUI

/// Picks light, dark, or the device appearance.
struct AppearanceSettingsView: View {
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    var body: some View {
        List {
            Section {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        appearance = mode
                    } label: {
                        SettingsOptionRow(
                            title: mode.title,
                            subtitle: mode.subtitle,
                            isSelected: appearance == mode
                        )
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("화면의 밝기를 선택하세요".l10n)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SettingsPageBackground())
        .lumenoteCompactHeader(title: "화면 모드", showsBackButton: true)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
    .lumenotePalette()
}
