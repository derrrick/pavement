import SwiftUI
import PavementCore

struct PresetsPanel: View {
    @Bindable var document: PavementDocument
    @State private var state = StyleBrowserState()
    @State private var selectedItem: StyleBrowserItem?
    // All categories collapsed by default — with 73 presets across 6
    // groups, expanding everything floods the panel. User reveals what
    // they want.
    @State private var expandedBuiltInGroups: Set<String> = []
    @ObservedObject private var stylesStore = UserStylesStore.shared

    private let columns = [
        GridItem(.adaptive(minimum: 128, maximum: 180), spacing: 8)
    ]

    private var items: [StyleBrowserItem] {
        state.filteredItems(builtIns: BuiltinPresets.all, styles: stylesStore.styles)
    }

    private var builtInGroups: [(category: String, items: [StyleBrowserItem])] {
        let query = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let presets = BuiltinPresets.all.filter { $0.category != "Reset" }
        var seen = Set<String>()
        let categories = presets.map(\.category).filter { seen.insert($0).inserted }
        return categories.compactMap { category in
            let grouped = presets
                .filter { $0.category == category }
                .map(StyleBrowserItem.preset)
                .filter { item in
                    query.isEmpty
                        || item.name.lowercased().contains(query)
                        || item.category.lowercased().contains(query)
                        || item.description.lowercased().contains(query)
                }
            return grouped.isEmpty ? nil : (category, grouped)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            categoryPicker
            detailRow
            browserGrid
            resetButton
        }
        .onChange(of: state.amount) { _, _ in
            guard let item = selectedItem ?? items.first(where: { $0.id == state.previewedStyleID }) else { return }
            preview(item)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Style Browser", systemImage: "wand.and.stars")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                Text("Style Strength")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int((state.amount * 100).rounded()))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: 30, alignment: .trailing)
            }
            Slider(value: $state.amount, in: 0...1)
                .help("Preview and apply styles at this strength.")
            TextField("Search styles", text: $state.searchText)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
        }
    }

    private var categoryPicker: some View {
        // Native macOS Picker.menu — guaranteed system-rendered popup
        // chevron and frame. Two prior attempts (custom Menu label with
        // a chevron pill) didn't read as a dropdown for the user; this
        // delegates the chrome to AppKit's NSPopUpButton via SwiftUI so
        // the affordance is the standard one users already recognize.
        Picker("Style library", selection: $state.selectedCategory) {
            ForEach(StyleBrowserCategory.allCases) { category in
                Label(category.rawValue, systemImage: "square.stack.3d.up")
                    .tag(category)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .controlSize(.regular)
        .help("Switch style library")
        #if os(macOS)
        .cursorOnHover()
        #endif
    }

    @ViewBuilder
    private var detailRow: some View {
        if let item = selectedItem {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(item.category)
                        Text(item.hasLUT ? "LUT" : "Parametric")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    state.toggleFavorite(item)
                } label: {
                    Image(systemName: state.isFavorite(item) ? "star.fill" : "star")
                }
                .buttonStyle(.plain)
                .help(state.isFavorite(item) ? "Remove favorite" : "Favorite")
                Button("Apply") { apply(item) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button {
                    selectedItem = nil
                    state.previewedStyleID = nil
                    document.cancelStylePreview()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("Clear preview")
            }
            .padding(8)
            .background(Theme.surfaceInset, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
    }

    private var browserGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            if state.selectedCategory == .builtIn {
                ForEach(builtInGroups, id: \.category) { group in
                    StyleGroupSection(
                        title: group.category,
                        count: group.items.count,
                        isExpanded: expandedBuiltInGroups.contains(group.category),
                        onToggle: {
                            if expandedBuiltInGroups.contains(group.category) {
                                expandedBuiltInGroups.remove(group.category)
                            } else {
                                expandedBuiltInGroups.insert(group.category)
                            }
                        }
                    ) {
                        tileGrid(group.items)
                    }
                }
            } else {
                tileGrid(items)
            }
        }
        .frame(minHeight: 120, alignment: .top)
    }

    private func tileGrid(_ tileItems: [StyleBrowserItem]) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tileItems) { item in
                StyleTile(
                    item: item,
                    isSelected: selectedItem?.id == item.id,
                    isPreviewed: state.previewedStyleID == item.id,
                    isFavorite: state.isFavorite(item),
                    onPreview: { preview(item) },
                    onCancelPreview: { cancelPreview(for: item) },
                    onSelect: {
                        selectedItem = item
                        preview(item)
                    },
                    onApply: { apply(item) },
                    onFavorite: { state.toggleFavorite(item) }
                )
            }
        }
    }

    private var resetButton: some View {
        Button {
            selectedItem = nil
            state.previewedStyleID = nil
            document.apply(preset: BuiltinPresets.neutral, amount: 1.0)
        } label: {
            Label("Reset Adjustments", systemImage: "arrow.counterclockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func preview(_ item: StyleBrowserItem) {
        state.previewedStyleID = item.id
        switch item {
        case .preset(let preset):
            document.preview(preset: preset, amount: state.amount)
        case .style(let style):
            document.preview(style: style, amount: state.amount)
        }
    }

    private func cancelPreview(for item: StyleBrowserItem) {
        guard state.previewedStyleID == item.id, selectedItem?.id != item.id else { return }
        state.previewedStyleID = nil
        document.cancelStylePreview()
    }

    private func apply(_ item: StyleBrowserItem) {
        switch item {
        case .preset(let preset):
            document.apply(preset: preset, amount: state.amount)
        case .style(let style):
            document.apply(style: style, amount: state.amount)
        }
        selectedItem = item
        state.previewedStyleID = nil
        state.recordApply(item)
    }
}

private struct StyleGroupSection<Content: View>: View {
    let title: String
    let count: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    let content: () -> Content

    init(
        title: String,
        count: Int,
        isExpanded: Bool,
        onToggle: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.count = count
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text(title)
                        .font(.caption.weight(.semibold))
                    Text("\(count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.surfaceInset.opacity(0.72), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .hoverHighlight(cornerRadius: Theme.cornerRadius, tint: Theme.hoverTint.opacity(0.7))

            // Expansion is instant — no `.transition` and no `.animation`
            // on the parent. Filters appear/disappear immediately when
            // the user toggles the chevron, matching Capture One.
            if isExpanded {
                content()
            }
        }
    }
}

private struct StyleTile: View {
    let item: StyleBrowserItem
    let isSelected: Bool
    let isPreviewed: Bool
    let isFavorite: Bool
    let onPreview: () -> Void
    let onCancelPreview: () -> Void
    let onSelect: () -> Void
    let onApply: () -> Void
    let onFavorite: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 7) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(item.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    if item.hasLUT {
                        Text("LUT")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture(count: 2).onEnded(onApply))

            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovering || isFavorite ? 1 : 0.35)
            .help(isFavorite ? "Remove favorite" : "Favorite")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : (hovering ? Theme.hoverTint : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: isSelected || isPreviewed ? 1.25 : 1)
        )
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            inside ? onPreview() : onCancelPreview()
        }
        .help(item.description.isEmpty ? item.name : item.description)
    }

    private var statusColor: Color {
        if isSelected || isPreviewed { return .accentColor }
        switch item.category {
        case "B&W": return Color(white: 0.72)
        case "Film": return .init(red: 0.82, green: 0.64, blue: 0.42)
        case "Cinematic": return .init(red: 0.28, green: 0.56, blue: 0.62)
        case "Street": return .init(red: 0.74, green: 0.32, blue: 0.24)
        case "Landscape": return .init(red: 0.34, green: 0.64, blue: 0.42)
        default: return .secondary
        }
    }

    private var borderColor: Color {
        if isSelected { return Color.accentColor }
        if isPreviewed { return Color.accentColor.opacity(0.65) }
        if hovering { return Theme.borderHover }
        return Theme.borderSubtle
    }
}
