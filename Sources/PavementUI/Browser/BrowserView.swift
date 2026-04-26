import SwiftUI
import UniformTypeIdentifiers
import PavementCore

public struct BrowserView: View {
    @State private var folderURL: URL?
    @State private var selection = SelectionModel()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingExport = false
    @State private var showingSaveStyle = false
    @State private var showingManageStyles = false
    @State private var importErrorMessage: String?
    @State private var showingGrid = false
    @State private var cachedDecode = CachedDecode()

    private let columnsLayout: [GridItem] = [
        GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 12)
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HeaderToolbar(
                folderURL: folderURL,
                hasSelection: !selection.selection.isEmpty,
                canExport: !itemsToExport.isEmpty,
                document: documentForCurrentSelection,
                showingGrid: $showingGrid,
                onChooseFolder: { chooseFolder() },
                onExport: { showingExport = true },
                onSaveStyle: { showingSaveStyle = true },
                onImportXMP: { chooseXMP() },
                onImportLUT: { chooseLUT() },
                onManageStyles: { showingManageStyles = true },
                onApplyStyle: { style in
                    documentForCurrentSelection?.recipe.apply(style: style)
                }
            )
            secondaryStatusBar

            if let errorMessage {
                errorView(errorMessage)
            } else if folderURL == nil {
                emptyState
            } else if isLoading {
                ProgressView("Scanning folder…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selection.items.isEmpty {
                ContentUnavailableView(
                    "No images",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Folder contained no RAF, CR3, DNG, or JPEG files.")
                )
            } else {
                HSplitView {
                    contactSheet
                        .frame(minWidth: 260, idealWidth: 360, maxWidth: 480)
                    EditorView(
                        item: selectedSingleItem,
                        cachedDecode: cachedDecode,
                        showGrid: showingGrid
                    )
                    .frame(minWidth: 600)
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) {
            selection.move(.left)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            selection.move(.right)
            return .handled
        }
        .onKeyPress(.upArrow) {
            selection.move(.up)
            return .handled
        }
        .onKeyPress(.downArrow) {
            selection.move(.down)
            return .handled
        }
        .onKeyPress("\\") {
            documentForCurrentSelection?.showBefore.toggle()
            return .handled
        }
        .onKeyPress(.escape) {
            documentForCurrentSelection?.previewIsolation = nil
            return .handled
        }
        .onKeyPress("g") {
            showingGrid.toggle()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "012345"), phases: .down) { press in
            guard let digit = press.characters.first?.wholeNumberValue,
                  digit >= 0, digit <= 5,
                  let url = selection.primarySelectionURL else {
                return .ignored
            }
            selection.setRating(digit, for: url)
            Task { await persistRating(digit, for: url) }
            return .handled
        }
        .sheet(isPresented: $showingExport) {
            ExportSheet(items: itemsToExport, isPresented: $showingExport)
        }
        .sheet(isPresented: $showingSaveStyle) {
            if let document = documentForCurrentSelection {
                SaveStyleSheet(recipe: document.recipe, isPresented: $showingSaveStyle)
            }
        }
        .sheet(isPresented: $showingManageStyles) {
            ManageStylesSheet(isPresented: $showingManageStyles)
        }
        .alert("Import failed", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK") { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    /// Slim status bar between toolbar and content showing folder path,
    /// selection state, and grid hint. Replaces the old top toolbar's
    /// inline status text.
    private var secondaryStatusBar: some View {
        HStack(spacing: 12) {
            if let folderURL {
                Text(folderURL.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("No folder loaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !selection.items.isEmpty {
                if !selection.batchSelection.isEmpty {
                    Text("\(selection.batchSelection.count) batched")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                    Button("Clear") { selection.clearBatchSelection() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                } else {
                    Text("\(selection.selection.count) of \(selection.items.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, Theme.paddingDefault)
        .frame(height: Theme.statusBarHeight)
        .background(Theme.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.dividerColor).frame(height: 1)
        }
    }

    /// Items destined for the export sheet. If the user has ticked any
    /// batch checkboxes, those win — that's the explicit "I want these
    /// exported as a set" signal. Otherwise fall back to the click
    /// selection so cmd-E on a hovered photo still does the right thing.
    private var itemsToExport: [SourceItem] {
        let urls = selection.batchSelection.isEmpty ? selection.selection : selection.batchSelection
        guard !urls.isEmpty else { return [] }
        return selection.items.filter { urls.contains($0.url) }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Pick a folder",
            systemImage: "folder.badge.plus",
            description: Text("Choose a folder containing RAFs, CR3s, DNGs, or JPEGs to start.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Couldn't open folder")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") { chooseFolder() }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contactSheet: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: columnsLayout, spacing: Theme.paddingDefault) {
                    ForEach(Array(selection.items.enumerated()), id: \.element.id) { index, item in
                        ThumbnailCell(
                            item: item,
                            isSelected: selection.selection.contains(item.url),
                            isBatchChecked: selection.batchSelection.contains(item.url),
                            rating: selection.rating(for: item.url),
                            onClick: { shift, command in
                                selection.handleClick(at: index, shift: shift, command: command)
                            },
                            onToggleBatch: {
                                selection.toggleBatchSelection(for: item.url)
                            },
                            onRate: { value in
                                selection.setRating(value, for: item.url)
                                Task { await persistRating(value, for: item.url) }
                            }
                        )
                    }
                }
                .padding(Theme.paddingDefault)
            }
            .background(Theme.surface)
            .onAppear { updateColumnCount(for: geometry.size.width) }
            .onChange(of: geometry.size.width) { _, newWidth in
                updateColumnCount(for: newWidth)
            }
        }
    }

    /// The single item currently driving the editor pane. Returns nil while
    /// no items are selected (Phase 2 doesn't render multi-select yet).
    private var selectedSingleItem: SourceItem? {
        guard let url = selection.primarySelectionURL else { return nil }
        return selection.items.first { $0.url == url }
    }

    /// Bridge for keyboard shortcuts that operate on the editor's loaded
    /// document. EditorView owns the actual document; we expose a callback
    /// hook through a binding so shortcuts at the BrowserView level can
    /// reach in. For now we let the EditorView publish its document via
    /// a shared environment value so this stays local.
    private var documentForCurrentSelection: PavementDocument? {
        EditorViewDocumentRegistry.shared.current
    }

    private func updateColumnCount(for width: CGFloat) {
        // Mirror the columnsLayout adaptive math so up/down arrow keys jump
        // to the correct row neighbor.
        let columns = max(1, Int((width - 24) / (140 + 12)))
        selection.columnCount = columns
    }

    /// Persist a rating change to the source's sidecar so it survives reloads.
    /// Background queue, fire-and-forget — UI already reflects the new value
    /// via SelectionModel.ratings.
    private func persistRating(_ rating: Int, for url: URL) async {
        await Task.detached(priority: .utility) {
            let store = SidecarStore()
            do {
                var recipe = (try store.load(for: url)) ?? EditRecipe()
                recipe.rating = rating
                recipe.modifiedAt = EditRecipe.now()
                try store.save(recipe, for: url)
            } catch {
                // Best-effort — don't surface an alert for a rating click.
            }
        }.value
    }

    /// Open a native NSOpenPanel for a folder. We bypass SwiftUI's
    /// .fileImporter because stacking three of them on the same view
    /// caused the buttons to silently no-op (only one fires reliably).
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Choose a folder containing RAFs, CR3s, DNGs, or JPEGs."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFolder(url)
    }

    private func chooseXMP() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.xml, UTType(filenameExtension: "xmp") ?? .xml]
        panel.prompt = "Import"
        panel.message = "Pick a Lightroom XMP preset to import as a Style."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let xml = try String(contentsOf: url, encoding: .utf8)
            let baseName = url.deletingPathExtension().lastPathComponent
            let style = try LightroomXMP.parse(xml, name: baseName)
            UserStylesStore.shared.add(style)
        } catch {
            importErrorMessage = "Couldn't import XMP: \(error)"
        }
    }

    private func chooseLUT() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "cube") ?? .data]
        panel.prompt = "Import"
        panel.message = "Pick a .cube 3D LUT to import as a Style."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let cubeText = try String(contentsOf: url, encoding: .utf8)
            let baseName = url.deletingPathExtension().lastPathComponent
            let lut = try CubeLUT.parse(cubeText, name: baseName)
            let style = Style(
                name: baseName,
                category: "LUT",
                description: "Imported .cube LUT (\(lut.dimension)³)",
                operations: Operations(),
                exclusions: Set(OperationKind.allCases),
                lut: lut
            )
            UserStylesStore.shared.add(style)
        } catch {
            importErrorMessage = "Couldn't import LUT: \(error)"
        }
    }

    private func loadFolder(_ folder: URL) {
        folderURL = folder
        errorMessage = nil
        isLoading = true
        cachedDecode.clear()

        Task.detached(priority: .userInitiated) {
            do {
                let items = try FolderScanner().scan(folder: folder)
                let ratings = preloadRatings(for: items)
                await MainActor.run {
                    selection.setItems(items)
                    for (url, rating) in ratings {
                        selection.setRating(rating, for: url)
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

}

/// Sweep the scanned items, opening each sidecar once to read the
/// rating field. Off-main; runs in ~10ms per 100 sidecars on M-series.
nonisolated private func preloadRatings(for items: [SourceItem]) -> [URL: Int] {
    let store = SidecarStore()
    var out: [URL: Int] = [:]
    for item in items {
        if let recipe = try? store.load(for: item.url), recipe.rating > 0 {
            out[item.url] = recipe.rating
        }
    }
    return out
}
