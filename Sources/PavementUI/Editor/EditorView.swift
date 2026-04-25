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
                ImageCanvas(image: document.renderedImage)
                    .frame(minWidth: 480)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HistogramView(histogram: document.histogram)
                            .frame(height: 80)
                        Divider()
                        PresetsPanel(document: document)
                        Divider()
                        BasicAdjustmentsPanelInline(document: document)
                        Divider()
                        ToneCurvePanel(document: document)
                        Divider()
                        ColorPanel(document: document)
                        Divider()
                        HSLPanel(document: document)
                        Divider()
                        CropPanel(document: document)
                        Divider()
                        LensPanel(document: document)
                    }
                    .padding(12)
                }
                .frame(minWidth: 320, idealWidth: 380, maxWidth: 480)
            }
        } else {
            ProgressView("Loading…")
        }
    }

    private func loadIfNeeded() async {
        guard let item else {
            document = nil
            return
        }
        if document?.source.id == item.id { return }

        loadingURL = item.url
        document = nil
        errorMessage = nil

        do {
            let loaded = try await DocumentLoader().load(item: item, cachedDecode: cachedDecode)
            if loadingURL == item.url {
                document = loaded
                document?.refreshRender()
            }
        } catch {
            if loadingURL == item.url {
                errorMessage = error.localizedDescription
            }
        }
    }
}
