import SwiftUI
import UniformTypeIdentifiers
import PavementCore

/// Capture One-inspired top toolbar: actions on the left, view-tools in
/// the middle, view options + clipboard on the right. Single source of
/// truth for the app's chrome — replaces the ad-hoc browser toolbar.
struct HeaderToolbar: View {
    let folderURL: URL?
    let hasSelection: Bool
    let canExport: Bool
    let document: PavementDocument?
    let gridMode: Binding<GridOverlayMode>
    let activeTool: Binding<CanvasTool>
    let onChooseFolder: () -> Void
    let onExport: () -> Void
    let onSaveStyle: () -> Void
    let onImportXMP: () -> Void
    let onImportLUT: () -> Void
    let onManageStyles: () -> Void
    let onApplyStyle: (Style) -> Void

    @ObservedObject private var stylesStore = UserStylesStore.shared
    @ObservedObject private var clipboard = RecipeClipboard.shared

    var body: some View {
        HStack(spacing: 6) {
            leftCluster
            verticalDivider
            actionsCluster
            Spacer()
            centerCluster
            Spacer()
            viewCluster
        }
        .padding(.horizontal, Theme.paddingDefault)
        .frame(height: Theme.toolbarHeight)
        .background(Theme.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.dividerColor)
                .frame(height: 1)
        }
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Theme.borderSubtle)
            .frame(width: 1, height: 22)
            .padding(.horizontal, 4)
    }

    // MARK: - Left cluster (Import / Style / Export)

    private var leftCluster: some View {
        HStack(spacing: 2) {
            ToolbarIconButton(
                systemImage: "folder.badge.plus",
                help: folderURL?.path ?? "Choose folder…",
                action: onChooseFolder
            )

            Menu {
                Button {
                    onSaveStyle()
                } label: {
                    Label("Save Current as Style…", systemImage: "square.and.arrow.down")
                }
                .disabled(document == nil)

                Divider()

                Button {
                    onImportXMP()
                } label: {
                    Label("Import Lightroom XMP…", systemImage: "doc.badge.plus")
                }

                Button {
                    onImportLUT()
                } label: {
                    Label("Import .cube LUT…", systemImage: "cube.transparent")
                }

                Divider()

                if stylesStore.styles.isEmpty {
                    Text("No saved styles").foregroundStyle(.secondary)
                } else {
                    ForEach(stylesStore.categories, id: \.self) { category in
                        Menu(category) {
                            ForEach(stylesStore.styles(in: category)) { style in
                                Button(style.name) { onApplyStyle(style) }
                            }
                        }
                    }
                }

                Divider()

                Button("Manage Styles…") { onManageStyles() }
            } label: {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 32, height: 32)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Save / Import / Manage Styles")
            .frame(width: 32, height: 32)
            .hoverHighlight()

            ToolbarIconButton(
                systemImage: "square.and.arrow.up",
                help: "Export selected (⌘E)",
                disabled: !canExport,
                action: onExport
            )
            .keyboardShortcut("e", modifiers: [.command])
        }
    }

    // MARK: - Actions cluster (Reset / Undo / Redo / Auto)

    private var actionsCluster: some View {
        HStack(spacing: 2) {
            ToolbarIconButton(
                systemImage: "arrow.counterclockwise",
                help: "Reset all adjustments (preserves crop)",
                disabled: document == nil,
                action: { document?.resetAdjustments() }
            )
            ToolbarIconButton(
                systemImage: "arrow.uturn.backward",
                help: "Undo (⌘Z)",
                disabled: document?.canUndo != true,
                action: { document?.undo() }
            )
            .keyboardShortcut("z", modifiers: [.command])
            ToolbarIconButton(
                systemImage: "arrow.uturn.forward",
                help: "Redo (⇧⌘Z)",
                disabled: document?.canRedo != true,
                action: { document?.redo() }
            )
            .keyboardShortcut("z", modifiers: [.command, .shift])
            ToolbarIconButton(
                systemImage: "wand.and.rays",
                help: "Auto-adjust exposure / contrast / WB",
                disabled: document?.renderedImage == nil,
                action: { runAuto() }
            )
        }
    }

    // MARK: - Center cluster (canvas tools)

    private var centerCluster: some View {
        HStack(spacing: 2) {
            ToolbarToolButton(
                systemImage: "crop",
                help: "Crop tool",
                tool: .crop,
                activeTool: activeTool,
                disabled: document == nil,
                action: {
                    document?.recipe.operations.crop.enabled = true
                }
            )
            ToolbarToolButton(
                systemImage: "hand.draw",
                help: "Move tool (canvas pan)",
                tool: .pan,
                activeTool: activeTool,
                disabled: document == nil
            )
            ToolbarToolButton(
                systemImage: "magnifyingglass",
                help: "Zoom tool",
                tool: .zoom,
                activeTool: activeTool,
                disabled: document == nil
            )
        }
    }

    // MARK: - View cluster (Before/After / Grid / Copy / Paste)

    private var viewCluster: some View {
        HStack(spacing: 2) {
            ToolbarIconToggle(
                systemImage: "rectangle.split.2x1",
                help: "Before / After (\\)",
                isOn: Binding(
                    get: { document?.showBefore ?? false },
                    set: { document?.showBefore = $0 }
                ),
                disabled: document == nil
            )
            Menu {
                ForEach(GridOverlayMode.allCases) { mode in
                    Button {
                        gridMode.wrappedValue = mode
                    } label: {
                        Label(mode.label, systemImage: mode.systemImage)
                    }
                }
            } label: {
                Image(systemName: gridMode.wrappedValue.systemImage)
                    .font(.system(size: 16, weight: gridMode.wrappedValue == .off ? .regular : .semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(gridMode.wrappedValue == .off ? Color.primary : Color.accentColor)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                            .fill(gridMode.wrappedValue == .off ? Color.clear : Color.accentColor.opacity(0.15))
                    )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Composition guides (G cycles)")
            .frame(width: 32, height: 32)
            .hoverHighlight()
            verticalDivider
            ToolbarIconButton(
                systemImage: "doc.on.clipboard",
                help: "Copy current adjustments (⇧⌘C)",
                disabled: document == nil,
                action: {
                    if let document {
                        RecipeClipboard.shared.copy(from: document.recipe)
                    }
                }
            )
            .keyboardShortcut("c", modifiers: [.command, .shift])
            ToolbarIconButton(
                systemImage: "doc.on.doc",
                help: "Apply copied adjustments (⇧⌘V)",
                disabled: document == nil || !clipboard.hasContent,
                action: {
                    if let document, clipboard.snapshot != nil {
                        var r = document.recipe
                        RecipeClipboard.shared.paste(into: &r)
                        document.recipe = r
                    }
                }
            )
            .keyboardShortcut("v", modifiers: [.command, .shift])
        }
    }

    // MARK: - Auto

    private func runAuto() {
        guard let document else { return }
        Task { @MainActor in
            guard let stats = document.statisticsForMatching() else { return }
            document.applyAutoAdjust(from: stats)
        }
    }
}

private struct ToolbarToolButton: View {
    let systemImage: String
    let help: String
    let tool: CanvasTool
    let activeTool: Binding<CanvasTool>
    var disabled = false
    var action: () -> Void = {}

    private var isActive: Bool { activeTool.wrappedValue == tool }

    var body: some View {
        Button {
            if isActive, tool != .pan {
                activeTool.wrappedValue = .pan
            } else {
                activeTool.wrappedValue = tool
                action()
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: isActive ? .semibold : .regular))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.16) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1.0)
        .help(isActive && tool != .pan ? "\(help) - click again to return to pan" : help)
        .hoverHighlight()
        .cursorOnHover()
    }
}
