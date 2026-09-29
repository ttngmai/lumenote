//

import SwiftUI

struct ContentView: View {
    private var language: LanguageSettings { .shared }

    var body: some View {
        NavigationStack {
            FeatureMenuView()
        }
        .lumenotePalette()
        .environment(\.locale, language.locale)
        .id(language.language)
    }
}

#Preview {
    ContentView()
}
