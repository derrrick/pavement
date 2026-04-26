import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Single source of truth for the app's visual design tokens.
///
/// Until this existed, panel backgrounds drifted across four shades of
/// gray (0.06 / 0.08 / 0.10 / 0.12) and padding was a mix of 4 / 6 / 8 /
/// 12 with no convention. Capture One feels coherent because every
/// surface speaks the same vocabulary; that's what this enforces.
///
/// Three surface tiers, three padding sizes, one hover treatment.
public enum Theme {
    // MARK: - Surface colors

    /// The app's primary working surface — chrome, panels, side rails.
    /// Reads as "neutral dark" against any photo on the canvas.
    public static let surface       = Color(white: 0.10)
    /// Slightly raised — thumbnails, cards, color-wheel inner wells.
    public static let surfaceRaised = Color(white: 0.13)
    /// Inset wells — the canvas itself, histogram, anywhere that should
    /// feel "behind" the surrounding chrome.
    public static let surfaceInset  = Color(white: 0.06)

    // MARK: - Borders & strokes

    public static let borderSubtle = Color.white.opacity(0.06)
    public static let borderHover  = Color.white.opacity(0.18)
    public static let dividerColor = Color.white.opacity(0.08)

    // MARK: - Hover tint

    /// Background tint added to hovered controls. Subtle — Capture One
    /// uses ~6-8% white overlay; we match.
    public static let hoverTint = Color.white.opacity(0.07)
    public static let pressedTint = Color.white.opacity(0.12)

    // MARK: - Spacing

    public static let paddingTight: CGFloat   = 6
    public static let paddingDefault: CGFloat = 12
    public static let paddingLoose: CGFloat   = 16
    public static let paddingHero: CGFloat    = 20

    public static let sectionSpacing: CGFloat = 10
    public static let rowSpacing: CGFloat     = 8

    // MARK: - Sizes

    /// Top toolbar — taller than the macOS default to give icons room
    /// to breathe and to read as "tool surface" rather than "title bar."
    public static let toolbarHeight: CGFloat   = 52
    public static let statusBarHeight: CGFloat = 26
    public static let cornerRadius: CGFloat    = 6
}

// MARK: - Hover modifier

/// Applies a subtle background tint when the mouse is over a control.
/// Used on icon buttons, thumbnail cells, accordion headers — anywhere
/// the user might want feedback that "yes, this is interactive."
public struct HoverHighlight: ViewModifier {
    @State private var hovering = false
    var cornerRadius: CGFloat
    var tint: Color

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(hovering ? tint : Color.clear)
                    .animation(.easeOut(duration: 0.12), value: hovering)
            )
            .onHover { hovering = $0 }
    }
}

public extension View {
    /// Adds a hover-tinted background. Use on bare icon buttons and
    /// accordion headers — anywhere `.buttonStyle(.borderless)` strips
    /// the system hover treatment.
    func hoverHighlight(
        cornerRadius: CGFloat = Theme.cornerRadius,
        tint: Color = Theme.hoverTint
    ) -> some View {
        modifier(HoverHighlight(cornerRadius: cornerRadius, tint: tint))
    }

    #if os(macOS)
    func cursorOnHover(_ cursor: NSCursor = .pointingHand) -> some View {
        modifier(CursorOnHover(cursor: cursor))
    }
    #endif
}

#if os(macOS)
private struct CursorOnHover: ViewModifier {
    let cursor: NSCursor
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside, !pushed {
                    cursor.push()
                    pushed = true
                } else if !inside, pushed {
                    NSCursor.pop()
                    pushed = false
                }
            }
            .onDisappear {
                if pushed {
                    NSCursor.pop()
                    pushed = false
                }
            }
    }
}
#endif
