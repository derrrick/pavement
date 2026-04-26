import SwiftUI
import PavementCore

struct SaveStyleSheet: View {
    let recipe: EditRecipe
    @Binding var isPresented: Bool
    var onSaved: ((Style) -> Void)?

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var category: String = "User"
    @State private var exclusions: Set<OperationKind> = Style.defaultExclusions
    @State private var recommendedOpacity: Double = 1.0

    private let categoryChoices = ["User", "B&W", "Film", "Cinematic", "Color", "Street"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Save Style").font(.headline)

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                Picker("Category", selection: $category) {
                    ForEach(categoryChoices, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 320)
                TextField("Description", text: $description)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                HStack {
                    Text("Recommended Opacity")
                    Slider(value: $recommendedOpacity, in: 0...1)
                        .frame(width: 180)
                    Text("\(Int((recommendedOpacity * 100).rounded()))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }

            Divider()

            Text("Exclude from style").font(.subheadline.weight(.medium))
            Text("Sections you exclude won't be applied when this style runs on another image. Crop, lens correction, and white balance default to excluded — they're per-image.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                ForEach(OperationKind.allCases, id: \.self) { kind in
                    Toggle(kind.displayName, isOn: Binding(
                        get: { exclusions.contains(kind) },
                        set: { isExcluded in
                            if isExcluded { exclusions.insert(kind) } else { exclusions.remove(kind) }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.callout)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let style = Style(
            name: trimmedName,
            category: category,
            description: description,
            operations: recipe.operations,
            exclusions: exclusions,
            recommendedOpacity: recommendedOpacity,
            lut: recipe.lut
        )
        UserStylesStore.shared.add(style)
        onSaved?(style)
        isPresented = false
    }
}
