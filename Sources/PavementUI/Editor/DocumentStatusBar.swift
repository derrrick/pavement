import SwiftUI
import PavementCore

/// Slim metadata strip below the canvas: filename + capture data.
/// Surfaces what professional editors put in their bottom info bar.
struct DocumentStatusBar: View {
    let document: PavementDocument

    private var dimensionsText: String? {
        guard let w = document.exif?.pixelWidth, let h = document.exif?.pixelHeight else { return nil }
        return "\(w) × \(h)"
    }

    private var captureSettings: String? {
        guard let exif = document.exif else { return nil }
        var parts: [String] = []
        if let iso = exif.iso { parts.append("ISO \(iso)") }
        if let camera = exif.camera { parts.append(camera) }
        if let lens = exif.lens { parts.append(lens) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(document.source.url.lastPathComponent)
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .truncationMode(.middle)

            if let dims = dimensionsText {
                Text(dims)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let settings = captureSettings {
                Text(settings)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            if document.showBefore {
                Label("Before", systemImage: "eye")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            if let isolation = document.previewIsolation {
                Label(isolationLabel(for: isolation), systemImage: "circle.lefthalf.filled.righthalf.striped.horizontal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func isolationLabel(for index: Int) -> String {
        let names = ["Red", "Orange", "Yellow", "Green", "Aqua", "Blue", "Purple", "Magenta"]
        return index >= 0 && index < names.count ? "Isolating \(names[index])" : "Isolating"
    }
}
