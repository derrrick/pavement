import SwiftUI

/// Accordion section wrapper used by the editor side panel. Each section
/// has its own chevron-toggle header with a title, an optional modified-
/// state dot, and an optional reset button. Expanded/collapsed state
/// persists across launches via UserDefaults so the user's panel layout
/// doesn't reset every time they reopen the app.
struct CollapsibleSection<Content: View>: View {
    let title: String
    let isModified: Bool
    let onReset: (() -> Void)?
    let content: () -> Content

    @State private var expanded: Bool
    private let storageKey: String

    init(
        title: String,
        isModified: Bool = false,
        defaultExpanded: Bool = true,
        onReset: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.isModified = isModified
        self.onReset = onReset
        self.content = content
        let key = "pavement.section.\(title)"
        self.storageKey = key
        let stored = UserDefaults.standard.object(forKey: key) as? Bool
        _expanded = State(initialValue: stored ?? defaultExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if expanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) { expanded.toggle() }
                UserDefaults.standard.set(expanded, forKey: storageKey)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                    Text(title).font(.headline)
                    if isModified {
                        Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                            .help("Modified")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            if let onReset, isModified {
                Button("Reset", action: onReset)
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
