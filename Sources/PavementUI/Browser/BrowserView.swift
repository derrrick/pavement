import SwiftUI
import UniformTypeIdentifiers
import PavementCore

public struct BrowserView: View {
    @State private var folderURL: URL?
    @State private var selection = SelectionModel()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPicker = false
    @State private var showingExport = false
    @State private var cachedDecode = CachedDecode()

    private let columnsLayout: [GridItem] = [
        GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 12)
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

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
                        cachedDecode: cachedDecode
                    )
                    .frame(minWidth: 600)
                }
            }
        }
        .focusable()
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
        .fileImporter(
            isPresented: $showingPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let folder = urls.first {
                    loadFolder(folder)
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showingExport) {
            ExportSheet(items: itemsToExport, isPresented: $showingExport)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                showingPicker = true
            } label: {
                Label("Choose Folder…", systemImage: "folder")
            }

            if let folderURL {
                Text(folderURL.path)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !selection.items.isEmpty {
                Text("\(selection.selection.count) of \(selection.items.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                showingExport = true
            } label: {
                Label("Export…", systemImage: "square.and.arrow.up")
            }
            .disabled(selection.selection.isEmpty)
            .keyboardShortcut("e", modifiers: [.command])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var itemsToExport: [SourceItem] {
        guard !selection.selection.isEmpty else { return [] }
        let urls = selection.selection
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
            Button("Try Again") { showingPicker = true }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contactSheet: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: columnsLayout, spacing: 12) {
                    ForEach(Array(selection.items.enumerated()), id: \.element.id) { index, item in
                        ThumbnailCell(
                            item: item,
                            isSelected: selection.selection.contains(item.url)
                        ) { shift, command in
                            selection.handleClick(at: index, shift: shift, command: command)
                        }
                    }
                }
                .padding(12)
            }
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

    private func updateColumnCount(for width: CGFloat) {
        // Mirror the columnsLayout adaptive math so up/down arrow keys jump
        // to the correct row neighbor.
        let columns = max(1, Int((width - 24) / (140 + 12)))
        selection.columnCount = columns
    }

    private func loadFolder(_ folder: URL) {
        folderURL = folder
        errorMessage = nil
        isLoading = true
        cachedDecode.clear()

        Task.detached(priority: .userInitiated) {
            do {
                let items = try FolderScanner().scan(folder: folder)
                await MainActor.run {
                    selection.setItems(items)
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
