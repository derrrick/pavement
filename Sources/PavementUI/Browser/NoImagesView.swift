import SwiftUI

struct NoImagesView: View {
    let onChooseFolder: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Color.accentColor)
            VStack(spacing: 5) {
                Text("No Images Found")
                    .font(.title3.weight(.semibold))
                Text("RAF, CR3, DNG, and JPEG files are supported.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Button(action: onChooseFolder) {
                Label("Choose Another Folder", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surfaceInset)
    }
}
