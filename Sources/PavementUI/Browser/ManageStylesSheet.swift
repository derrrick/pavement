import SwiftUI
import PavementCore

struct ManageStylesSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var store = UserStylesStore.shared

    @State private var selection: String?
    @State private var renamingId: String?
    @State private var draftName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Manage Styles").font(.headline)
                Spacer()
                Text("\(store.styles.count) saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.styles.isEmpty {
                ContentUnavailableView(
                    "No saved styles yet",
                    systemImage: "wand.and.stars",
                    description: Text("Save the current edit as a style, or import a Lightroom XMP / .cube LUT.")
                )
                .frame(height: 240)
            } else {
                List(selection: $selection) {
                    ForEach(store.categories, id: \.self) { category in
                        Section(category) {
                            ForEach(store.styles(in: category)) { style in
                                row(style: style)
                                    .tag(style.id)
                            }
                        }
                    }
                }
                .frame(width: 480, height: 320)
                .listStyle(.sidebar)
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    if let id = selection { store.duplicate(id: id) }
                } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                .disabled(selection == nil)

                Button {
                    if let id = selection { store.remove(id: id); selection = nil }
                } label: { Label("Delete", systemImage: "trash") }
                .disabled(selection == nil)

                Spacer()

                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    @ViewBuilder
    private func row(style: Style) -> some View {
        if renamingId == style.id {
            HStack {
                TextField("Name", text: $draftName, onCommit: {
                    let trimmed = draftName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        store.rename(id: style.id, to: trimmed)
                    }
                    renamingId = nil
                })
                .textFieldStyle(.plain)
                Button("Cancel") { renamingId = nil }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(style.name).font(.callout)
                    if !style.description.isEmpty {
                        Text(style.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if style.lut != nil {
                    Image(systemName: "cube.transparent")
                        .foregroundStyle(Color.accentColor)
                        .help("Includes a 3D LUT")
                }
                Text(style.category)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .contextMenu {
                Button("Rename") {
                    renamingId = style.id
                    draftName = style.name
                }
                Button("Duplicate") { store.duplicate(id: style.id) }
                Divider()
                Button("Delete", role: .destructive) {
                    store.remove(id: style.id)
                    if selection == style.id { selection = nil }
                }
            }
        }
    }
}
