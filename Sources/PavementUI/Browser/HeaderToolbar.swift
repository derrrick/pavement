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
    let showingGrid: Binding<Bool>
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
        HStack(spacing: 4) {
            leftCluster
            Divider().frame(height: 18)
            actionsCluster
            Spacer()
            centerCluster
            Spacer()
            viewCluster
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Left cluster (Import / Style / Export)

    private var leftCluster: some View {
        HStack(spacing: 4) {
            Button(action: onChooseFolder) {
                Label("Import", systemImage: "folder.badge.plus")
                    .labelStyle(.iconOnly)
            }
            .help(folderURL?.path ?? "Choose folder…")
            .buttonStyle(.borderless)
            .controlSize(.large)

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
                Label("Style", systemImage: "wand.and.stars")
                    .labelStyle(.iconOnly)
            }
            .menuIndicator(.hidden)
            .help("Save / Import / Manage Styles")
            .buttonStyle(.borderless)
            .controlSize(.large)
            .frame(width: 32)

            Button(action: onExport) {
                Label("Export", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
            .disabled(!canExport)
            .help("Export selected (⌘E)")
            .buttonStyle(.borderless)
            .controlSize(.large)
            .keyboardShortcut("e", modifiers: [.command])
        }
    }

    // MARK: - Actions cluster (Reset / Undo / Redo / Auto)

    private var actionsCluster: some View {
        HStack(spacing: 4) {
            Button {
                document?.resetAdjustments()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .labelStyle(.iconOnly)
            }
            .disabled(document == nil)
            .help("Reset all adjustments (preserves crop)")
            .buttonStyle(.borderless)
            .controlSize(.large)

            Button {
                document?.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .labelStyle(.iconOnly)
            }
            .disabled(document?.canUndo != true)
            .help("Undo (⌘Z)")
            .buttonStyle(.borderless)
            .controlSize(.large)
            .keyboardShortcut("z", modifiers: [.command])

            Button {
                document?.redo()
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
                    .labelStyle(.iconOnly)
            }
            .disabled(document?.canRedo != true)
            .help("Redo (⇧⌘Z)")
            .buttonStyle(.borderless)
            .controlSize(.large)
            .keyboardShortcut("z", modifiers: [.command, .shift])

            Button {
                runAuto()
            } label: {
                Label("Auto", systemImage: "wand.and.rays")
                    .labelStyle(.iconOnly)
            }
            .disabled(document?.renderedImage == nil)
            .help("Auto-adjust exposure / contrast / WB")
            .buttonStyle(.borderless)
            .controlSize(.large)
        }
    }

    // MARK: - Center cluster (canvas tools — placeholders for future canvas modes)

    private var centerCluster: some View {
        HStack(spacing: 4) {
            // These mode toggles will drive future canvas-tool implementations.
            // For v1 they're inert chrome that documents the intent.
            Button {} label: {
                Label("Crop", systemImage: "crop")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .disabled(true)
            .help("Crop tool (use Crop panel for now)")

            Button {} label: {
                Label("Move", systemImage: "hand.draw")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .disabled(true)
            .help("Move tool (canvas pan)")

            Button {} label: {
                Label("Zoom", systemImage: "magnifyingglass")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .disabled(true)
            .help("Zoom tool (use canvas scroll)")
        }
    }

    // MARK: - View cluster (Before/After / Grid / Copy / Paste)

    private var viewCluster: some View {
        HStack(spacing: 4) {
            Toggle(isOn: Binding(
                get: { document?.showBefore ?? false },
                set: { document?.showBefore = $0 }
            )) {
                Label("Before/After", systemImage: "rectangle.split.2x1")
                    .labelStyle(.iconOnly)
            }
            .toggleStyle(.button)
            .controlSize(.large)
            .disabled(document == nil)
            .help("Before / After (\\)")

            Toggle(isOn: showingGrid) {
                Label("Grid", systemImage: "grid")
                    .labelStyle(.iconOnly)
            }
            .toggleStyle(.button)
            .controlSize(.large)
            .help("Rule-of-thirds grid overlay (G)")

            Button {
                if let document {
                    RecipeClipboard.shared.copy(from: document.recipe)
                }
            } label: {
                Label("Copy Settings", systemImage: "doc.on.clipboard")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .disabled(document == nil)
            .help("Copy current adjustments (⌘C)")
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button {
                if let document, let _ = clipboard.snapshot {
                    var r = document.recipe
                    RecipeClipboard.shared.paste(into: &r)
                    document.recipe = r
                }
            } label: {
                Label("Apply Settings", systemImage: "doc.on.doc")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .disabled(document == nil || !clipboard.hasContent)
            .help("Apply copied adjustments (⇧⌘V)")
            .keyboardShortcut("v", modifiers: [.command, .shift])
        }
    }

    // MARK: - Auto

    private func runAuto() {
        guard let document, let rendered = document.renderedImage else { return }
        Task {
            let stats = await Task.detached(priority: .userInitiated) {
                ImageStatisticsCalculator.compute(from: rendered)
            }.value
            await MainActor.run {
                let derived = AutoAdjust.operations(from: stats)
                var ops = document.recipe.operations
                ops.exposure = derived.exposure
                ops.tone.contrast = derived.tone.contrast
                ops.whiteBalance = derived.whiteBalance
                document.recipe.operations = ops
            }
        }
    }
}
