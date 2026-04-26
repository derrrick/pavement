import SwiftUI
import AppKit
import PavementCore

struct ThumbnailCell: View {
    let item: SourceItem
    let isSelected: Bool
    let isBatchChecked: Bool
    let rating: Int
    let onClick: (_ shift: Bool, _ command: Bool) -> Void
    let onToggleBatch: () -> Void
    let onRate: (Int) -> Void

    @State private var image: NSImage?
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Theme.surfaceRaised)
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                } else {
                    ProgressView()
                        .controlSize(.small)
                }

                // Batch checkbox only shows on hover or when ticked — keeps
                // the contact sheet uncluttered until the user is in
                // multi-select mode.
                if hovering || isBatchChecked {
                    Button {
                        onToggleBatch()
                    } label: {
                        Image(systemName: isBatchChecked ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isBatchChecked ? Color.accentColor : Color.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.5), radius: 2)
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(isBatchChecked ? "Remove from batch" : "Add to batch")
                    .transition(.opacity)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .scaleEffect(hovering && !isSelected ? 1.015 : 1.0)
            .animation(.easeOut(duration: 0.14), value: hovering)

            HStack(spacing: 4) {
                Text(item.url.lastPathComponent)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(item.type.rawValue.uppercased())
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2)

            StarRating(value: rating, onSet: onRate)
                .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            let mods = NSEvent.modifierFlags
            onClick(mods.contains(.shift), mods.contains(.command))
        }
        .task(id: item.url) {
            await loadThumbnail()
        }
    }

    private var borderColor: Color {
        if isSelected { return Color.accentColor }
        if hovering   { return Color.white.opacity(0.18) }
        return Color.clear
    }

    private var borderWidth: CGFloat {
        isSelected ? 2 : 1
    }

    private func loadThumbnail() async {
        let sourceURL = item.url
        let loaded = await Task.detached(priority: .userInitiated) {
            let cache = ThumbnailCache()
            do {
                let cacheURL = try cache.ensure(for: sourceURL)
                return NSImage(contentsOf: cacheURL)
            } catch {
                return nil as NSImage?
            }
        }.value
        await MainActor.run {
            self.image = loaded
        }
    }
}
