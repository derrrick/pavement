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

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(white: 0.12))
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    onToggleBatch()
                } label: {
                    Image(systemName: isBatchChecked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isBatchChecked ? Color.accentColor : Color.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isBatchChecked ? "Remove from batch" : "Add to batch")
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )

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
        .onTapGesture {
            let mods = NSEvent.modifierFlags
            onClick(mods.contains(.shift), mods.contains(.command))
        }
        .task(id: item.url) {
            await loadThumbnail()
        }
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
