import SwiftUI
import PavementCore

struct GrainPanel: View {
    @Bindable var document: PavementDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Type").font(.caption)
                Spacer()
                typePicker
                    .frame(width: 150)
            }

            SliderRow(
                label: "Amount",
                value: intBinding(\.amount),
                range: 0...100,
                step: 1,
                format: "%.0f",
                defaultValue: 0
            )
            SliderRow(
                label: "Size",
                value: intBinding(\.size),
                range: 0...100,
                step: 1,
                format: "%.0f",
                defaultValue: 25
            )
            SliderRow(
                label: "Roughness",
                value: intBinding(\.roughness),
                range: 0...100,
                step: 1,
                format: "%.0f",
                defaultValue: 50
            )

            Text(typeDescription(for: document.recipe.operations.grain.type))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var typePicker: some View {
        Picker("Type", selection: Binding(
            get: { document.recipe.operations.grain.type },
            set: { document.recipe.operations.grain.type = $0 }
        )) {
            Section("Looks") {
                ForEach(lookLabels, id: \.0) { tag, label in
                    Text(label).tag(tag)
                }
            }
            Section("Algorithms") {
                ForEach(algorithmLabels, id: \.0) { tag, label in
                    Text(label).tag(tag)
                }
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private let lookLabels: [(String, String)] = [
        (GrainOp.typeFine,       "Fine"),
        (GrainOp.typeCameraRaw,  "Camera Raw"),
        (GrainOp.typeCubic,      "Cubic (T-MAX)"),
        (GrainOp.typeTabular,    "Tabular"),
        (GrainOp.typeSilverRich, "Silver Rich"),
        (GrainOp.typeSoft,       "Soft"),
        (GrainOp.typeHarsh,      "Harsh (Pushed)"),
        (GrainOp.typeNewsprint,  "Newsprint"),
        (GrainOp.typePlate,      "Plate"),
    ]

    private let algorithmLabels: [(String, String)] = [
        (GrainOp.typeUniform,  "Uniform"),
        (GrainOp.typeGaussian, "Gaussian"),
        (GrainOp.typePerlin,   "Perlin"),
        (GrainOp.typeSimplex,  "Simplex"),
        (GrainOp.typeValue,    "Value"),
        (GrainOp.typeVoronoi,  "Voronoi"),
    ]

    private func intBinding(_ keyPath: WritableKeyPath<GrainOp, Int>) -> Binding<Double> {
        Binding(
            get: { Double(document.recipe.operations.grain[keyPath: keyPath]) },
            set: { document.recipe.operations.grain[keyPath: keyPath] = Int($0.rounded()) }
        )
    }

    private func typeDescription(for type: String) -> String {
        switch type {
        // Looks
        case GrainOp.typeFine:       return "Fine modern digital grain — uniform, sharp, neutral."
        case GrainOp.typeCameraRaw:  return "Multi-octave Perlin (fBm). Roughness drives fractal complexity."
        case GrainOp.typeCubic:      return "T-MAX–style cubic crystals via value noise — crisp, defined."
        case GrainOp.typeTabular:    return "Anisotropic T-grain platelets via Perlin + horizontal motion blur."
        case GrainOp.typeSilverRich: return "Voronoi cellular crystals weighted into the shadows — Ilford Delta 3200."
        case GrainOp.typeSoft:       return "Smooth Perlin diffused into atmospheric texture."
        case GrainOp.typeHarsh:      return "Pushed film: per-pixel uniform with extreme contrast. Gritty."
        case GrainOp.typeNewsprint:  return "Ordered halftone dot screen via CIDotScreen."
        case GrainOp.typePlate:      return "Wet-plate collodion: large Voronoi cells smoothed into organic blobs."
        // Algorithms
        case GrainOp.typeUniform:    return "Pure uniform random per pixel."
        case GrainOp.typeGaussian:   return "Per-pixel random with bell-curve distribution."
        case GrainOp.typePerlin:     return "Classic Perlin gradient noise — smooth, cloud-like."
        case GrainOp.typeSimplex:    return "Simplex noise — improved Perlin, no directional artifacts."
        case GrainOp.typeValue:      return "Random values per grid cell, smoothly interpolated. Blockier."
        case GrainOp.typeVoronoi:    return "Worley cellular noise — distance to nearest random point."
        default:                     return ""
        }
    }
}
