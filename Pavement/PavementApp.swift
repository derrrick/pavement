import SwiftUI
import PavementUI

@main
struct PavementApp: App {
    init() {
        // Register bundled custom fonts before any view tries to use
        // `Font.custom("Inter", ...)` — otherwise SwiftUI silently falls
        // back to the system face on the very first render.
        AppFonts.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup("Pavement") {
            RootView()
        }
        .windowStyle(.titleBar)
    }
}
