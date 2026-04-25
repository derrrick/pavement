import SwiftUI
import PavementCore

public struct EditorView: View {
    let item: SourceItem?
    let cachedDecode: CachedDecode

    @State private var document: PavementDocument?
    @State private var loadingURL: URL?
    @State private var errorMessage: String?

    public init(item: SourceItem?, cachedDecode: CachedDecode) {
        self.item = item
        self.cachedDecode = cachedDecode
    }

    public var body: some View {
        ZStack {
            Color(white: 0.08)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: item?.id) {
            await loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle).foregroundStyle(.orange)
                Text("Couldn't open file").font(.headline)
                Text(errorMessage).font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        } else if item == nil {
            ContentUnavailableView(
                "Select a photo",
                systemImage: "photo",
                description: Text("Pick a thumbnail to start editing.")
            )
        } else if let document {
            HSplitView {
                VStack(spacing: 0) {
                    ImageCanvas(image: document.renderedImage)
                        .overlay(alignment: .topLeading) {
                            if document.showBefore {
                                Text("BEFORE")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.regularMaterial, in: Capsule())
                                    .padding(12)
                            }
                        }
                    DocumentStatusBar(document: document)
                }
                .frame(minWidth: 480)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HistogramView(histogram: document.histogram)
                            .frame(height: 80)
                        Divider()
                        sections(for: document)
                    }
                    .padding(12)
                }
                .frame(minWidth: 320, idealWidth: 380, maxWidth: 480)
            }
        } else {
            ProgressView("Loading…")
        }
    }

    @ViewBuilder
    private func sections(for document: PavementDocument) -> some View {
        let ops = document.recipe.operations
        CollapsibleSection(title: "Presets") {
            PresetsPanel(document: document)
        }
        Divider()
        CollapsibleSection(
            title: "White Balance",
            isModified: ops.whiteBalance != WhiteBalanceOp(),
            onReset: { document.recipe.operations.whiteBalance = WhiteBalanceOp() }
        ) {
            WhiteBalancePanel(document: document)
        }
        Divider()
        CollapsibleSection(
            title: "Exposure",
            isModified: ops.exposure.ev != 0,
            onReset: { document.recipe.operations.exposure = ExposureOp() }
        ) {
            ExposurePanel(document: document)
        }
        Divider()
        CollapsibleSection(
            title: "Tone",
            isModified: !ToneFilter.isIdentity(ops.tone),
            onReset: { document.recipe.operations.tone = ToneOp() }
        ) {
            TonePanel(document: document)
        }
        Divider()
        CollapsibleSection(
            title: "Tone Curve",
            isModified: !ToneCurveFilter.isIdentity(ops.toneCurve.rgb),
            onReset: { document.recipe.operations.toneCurve = ToneCurveOp() }
        ) {
            ToneCurvePanel(document: document)
        }
        Divider()
        CollapsibleSection(
            title: "Color",
            isModified: !ColorAdjustFilter.isIdentity(ops.color),
            onReset: { document.recipe.operations.color = ColorOp() }
        ) {
            ColorPanel(document: document)
        }
        Divider()
        CollapsibleSection(
            title: "HSL",
            isModified: !HSLFilter.isIdentity(ops.hsl),
            onReset: { document.recipe.operations.hsl = HSLOp() }
        ) {
            HSLPanel(document: document)
        }
        Divider()
        CollapsibleSection(
            title: "Detail",
            isModified: ops.detail != DetailOp(),
            onReset: { document.recipe.operations.detail = DetailOp() }
        ) {
            DetailPanel(document: document)
        }
        Divider()
        CollapsibleSection(
            title: "Crop",
            isModified: ops.crop != CropOp(),
            defaultExpanded: false,
            onReset: { document.recipe.operations.crop = CropOp() }
        ) {
            CropPanel(document: document)
        }
        Divider()
        CollapsibleSection(
            title: "Lens",
            defaultExpanded: false
        ) {
            LensPanel(document: document)
        }
    }

    private func loadIfNeeded() async {
        guard let item else {
            document = nil
            EditorViewDocumentRegistry.shared.current = nil
            return
        }
        if document?.source.id == item.id { return }

        loadingURL = item.url
        document = nil
        EditorViewDocumentRegistry.shared.current = nil
        errorMessage = nil

        do {
            let loaded = try await DocumentLoader().load(item: item, cachedDecode: cachedDecode)
            if loadingURL == item.url {
                document = loaded
                document?.refreshRender()
                EditorViewDocumentRegistry.shared.current = loaded
            }
        } catch {
            if loadingURL == item.url {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Bridge so BrowserView's keyboard shortcuts (which can't easily reach
/// EditorView's @State) can operate on the currently-loaded document.
/// Single-document app, so a shared singleton is fine.
@MainActor
final class EditorViewDocumentRegistry {
    static let shared = EditorViewDocumentRegistry()
    var current: PavementDocument?
    private init() {}
}
