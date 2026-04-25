import SwiftUI

public enum PavementUI {
    public static let placeholder = "PavementUI"
}

public struct RootView: View {
    public init() {}

    public var body: some View {
        BrowserView()
            .frame(minWidth: 900, minHeight: 600)
    }
}
