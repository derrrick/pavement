import SwiftUI

/// Compact icon-only toolbar button with a uniform 32×32 hit target,
/// hover highlight, and the standard borderless style. Capture One's
/// header chrome consists almost entirely of these — same target size,
/// same hover treatment, same icon weight.
struct ToolbarIconButton: View {
    let systemImage: String
    var help: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .regular))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1.0)
        .help(help)
        .hoverHighlight()
    }
}

/// Toggle variant — shows accent-tinted background when on, hover
/// otherwise. Used for view-mode flips (Grid, Before/After).
struct ToolbarIconToggle: View {
    let systemImage: String
    var help: String
    @Binding var isOn: Bool
    var disabled: Bool = false

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: isOn ? .semibold : .regular))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .foregroundStyle(isOn ? Color.accentColor : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .fill(isOn ? Color.accentColor.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1.0)
        .help(help)
        .hoverHighlight()
    }
}
