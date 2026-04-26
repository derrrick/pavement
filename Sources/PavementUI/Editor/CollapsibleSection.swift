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
        VStack(alignment: .leading, spacing: 0) {
            header
            if expanded {
                content()
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Theme.surfaceRaised.opacity(expanded ? 0.45 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(expanded ? Theme.borderSubtle : Color.clear, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.14), value: expanded)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
                UserDefaults.standard.set(expanded, forKey: storageKey)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 10)
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(expanded ? Color.primary : Color.primary.opacity(0.85))
                    if isModified {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                            .help("Modified")
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onReset, isModified {
                Button("Reset", action: onReset)
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .hoverHighlight(cornerRadius: Theme.cornerRadius, tint: Theme.hoverTint.opacity(0.6))
    }
}
