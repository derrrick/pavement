import SwiftUI
import UniformTypeIdentifiers
import PavementCore

@Observable
@MainActor
final class ExportQueue {
    var total: Int = 0
    var completed: Int = 0
    var current: String?
    var failures: [(name: String, message: String)] = []
    var isRunning: Bool = false

    private var task: Task<Void, Never>?

    func start(items: [SourceItem], preset: ExportPreset, destinationFolder: URL?) {
        guard !isRunning else { return }
        guard !items.isEmpty else { return }

        total = items.count
        completed = 0
        failures = []
        current = nil
        isRunning = true

        let urls = items.map { $0.url }

        task = Task.detached(priority: .userInitiated) { [weak self] in
            for url in urls {
                if Task.isCancelled { break }

                let dest: URL
                if let destinationFolder {
                    let stem = url.deletingPathExtension().lastPathComponent
                    let ext = (preset.spec.format == .jpeg) ? "jpg" : "tif"
                    dest = destinationFolder.appendingPathComponent("\(stem).\(ext)")
                } else {
                    dest = Exporter.defaultDestination(source: url, preset: preset)
                }

                await MainActor.run { self?.current = url.lastPathComponent }

                let result: Result<Void, Error> = await Task.detached(priority: .userInitiated) {
                    do {
                        var recipe = (try SidecarStore().load(for: url)) ?? EditRecipe()
                        try Migrations.upgrade(&recipe)
                        Clamping.clampInPlace(&recipe)
                        try Exporter().export(
                            recipe: recipe,
                            source: url,
                            preset: preset,
                            destination: dest
                        )
                        return .success(())
                    } catch {
                        return .failure(error)
                    }
                }.value

                await MainActor.run {
                    if case .failure(let err) = result {
                        self?.failures.append((url.lastPathComponent, "\(err)"))
                    }
                    self?.completed += 1
                }
            }

            await MainActor.run {
                self?.isRunning = false
                self?.current = nil
            }
        }
    }

    func cancel() {
        task?.cancel()
        isRunning = false
    }
}

struct ExportSheet: View {
    let items: [SourceItem]
    @Binding var isPresented: Bool

    @State private var preset: ExportPreset = .instagram
    @State private var queue = ExportQueue()
    @State private var customDestination: URL?
    @State private var showingFolderPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export \(items.count) photo\(items.count == 1 ? "" : "s")")
                .font(.headline)

            Picker("Preset", selection: $preset) {
                ForEach(ExportPreset.allCases) { p in
                    Text("\(p.displayName) — \(presetCaption(p))").tag(p)
                }
            }
            .pickerStyle(.menu)
            .disabled(queue.isRunning)

            HStack(alignment: .firstTextBaseline) {
                Text("Destination").frame(width: 90, alignment: .leading)
                Text(customDestination?.path ?? defaultDestinationLabel)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose…") { showingFolderPicker = true }
                    .disabled(queue.isRunning)
                if customDestination != nil {
                    Button("Reset") { customDestination = nil }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

            Divider()

            if queue.total > 0 {
                progressSection
            } else {
                summarySection
            }

            Divider()

            HStack {
                if queue.isRunning {
                    Button("Cancel") { queue.cancel() }
                } else if !queue.failures.isEmpty {
                    Text("\(queue.failures.count) failed")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                Spacer()
                Button("Done") { isPresented = false }
                Button("Export") {
                    queue.start(items: items, preset: preset, destinationFolder: customDestination)
                }
                .disabled(queue.isRunning || items.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                customDestination = url
            }
        }
    }

    private var defaultDestinationLabel: String {
        if let first = items.first {
            let folder = first.url.deletingLastPathComponent()
            return folder.appendingPathComponent("_exports/\(preset.spec.folderName)/").path
        }
        return "_exports/\(preset.spec.folderName)/"
    }

    private func presetCaption(_ p: ExportPreset) -> String {
        let s = p.spec
        let dim = s.longEdge.map { "\($0)px" } ?? "full"
        let format = s.format.rawValue.uppercased()
        return "\(dim) \(s.colorSpace.rawValue) \(format)"
    }

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items.prefix(6), id: \.id) { item in
                Text(item.url.lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if items.count > 6 {
                Text("…and \(items.count - 6) more")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxHeight: 120, alignment: .top)
    }

    @ViewBuilder
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(
                value: Double(queue.completed),
                total: Double(max(1, queue.total))
            )
            HStack {
                Text("\(queue.completed) / \(queue.total)")
                    .font(.caption.monospacedDigit())
                Spacer()
                if let c = queue.current {
                    Text(c)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            if !queue.failures.isEmpty {
                Text("Failed: \(queue.failures.map(\.name).joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
    }
}
