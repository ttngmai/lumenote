//

import SwiftUI

struct ContentView: View {
    @State private var path = NavigationPath()
    private var language: LanguageSettings { .shared }

    var body: some View {
        NavigationStack(path: $path) {
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
