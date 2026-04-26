import SwiftUI
import PavementCore

/// Presets panel — categories grouped, each category individually
/// collapsible. State persists per-category in UserDefaults so the
/// user's open/closed pattern survives across launches.
struct PresetsPanel: View {
    @Bindable var document: PavementDocument

    private var grouped: [(category: String, presets: [Preset])] {
        let groups = Dictionary(grouping: BuiltinPresets.all, by: \.category)
        // Stable display order — most-used categories near the top.
        let order = ["Reset", "Film", "Cinematic", "Color", "Street", "B&W", "Landscape"]
        return order.compactMap { cat in
            guard let presets = groups[cat] else { return nil }
            return (cat, presets)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(grouped, id: \.category) { group in
                if group.category == "Reset" {
                    // Reset is a single button — no need for a category
                    // header / collapse affordance, just show the chip.
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 6)],
                        alignment: .leading,
                        spacing: 6
                    ) {
                        ForEach(group.presets) { preset in
                            PresetChip(preset: preset, document: document)
                        }
                    }
                } else {
                    PresetCategorySection(
                        title: group.category,
                        presets: group.presets,
                        document: document
                    )
                }
            }
        }
    }
}

/// One collapsible category. Header (chevron + name + count) toggles
/// the grid below. Open/closed state persists per-category.
private struct PresetCategorySection: View {
    let title: String
    let presets: [Preset]
    @Bindable var document: PavementDocument

    @State private var expanded: Bool
    private let storageKey: String

    init(title: String, presets: [Preset], document: PavementDocument) {
        self.title = title
        self.presets = presets
        self.document = document
        let key = "pavement.presets.\(title)"
        self.storageKey = key
        // Default: only Film + Reset expanded — keeps the panel tidy
        // when there are 70+ presets across 6 categories.
        let stored = UserDefaults.standard.object(forKey: key) as? Bool
        let defaultOpen = (title == "Film")
        _expanded = State(initialValue: stored ?? defaultOpen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            if expanded {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 6)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(presets) { preset in
                        PresetChip(preset: preset, document: document)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) { expanded.toggle() }
            UserDefaults.standard.set(expanded, forKey: storageKey)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("(\(presets.count))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
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
        .help(preset.description.isEmpty ? "Apply \(preset.name) preset" : preset.description)
    }
}
