import SwiftUI
import PavementCore
import PavementUI

@main
struct PavementApp: App {
    var body: some Scene {
        WindowGroup("Pavement") {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Pavement")
                .font(.largeTitle.weight(.semibold))
            Text("v\(PavementCore.version)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(PavementUI.placeholder)
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
