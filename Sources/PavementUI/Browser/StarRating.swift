import SwiftUI

struct StarRating: View {
    let value: Int           // 0..5
    let onSet: (Int) -> Void

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= value ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundStyle(star <= value ? Color.yellow : Color.white.opacity(0.3))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Click same star → clear; otherwise set to that star.
                        onSet(star == value ? 0 : star)
                    }
            }
        }
        .help("Click to rate (1–5). Use number keys when this image is selected.")
    }
}
