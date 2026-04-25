import SwiftUI
import PavementUI

@main
struct PavementApp: App {
    var body: some Scene {
        WindowGroup("Pavement") {
            RootView()
        }
        .windowStyle(.titleBar)
    }
}
