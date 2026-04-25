import SwiftUI
import PavementCore

struct PresetsPanel: View {
    @Bindable var document: PavementDocument

    private var grouped: [(category: String, presets: [Preset])] {
        let groups = Dictionary(grouping: BuiltinPresets.all, by: \.category)
        // Stable display order
        let order = ["Reset", "B&W", "Film", "Cinematic", "Color", "Street"]
        return order.compactMap { cat in
            guard let presets = groups[cat] else { return nil }
            return (cat, presets)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(grouped, id: \.category) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 6)],
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(group.presets) { preset in
                            PresetChip(preset: preset, document: document)
                        }
                    }
                }
            }
        }
    }
}

private struct PresetChip: View {
    let preset: Preset
    @Bindable var document: PavementDocument

    var body: some View {
        Button {
            document.recipe.apply(preset: preset)
        } label: {
            Text(preset.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help("Apply \(preset.name) preset")
    }
}
