import SwiftUI
import PavementCore

struct LensPanel: View {
    @Bindable var document: PavementDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Lens Correction").font(.headline)
                Spacer()
                Toggle("On", isOn: Binding(
                    get: { document.recipe.operations.lensCorrection.enabled },
                    set: { document.recipe.operations.lensCorrection.enabled = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            Text("Uses the camera's embedded lens profile (CR3/RAF). Toggle off to see the raw distortion. Manual strengths and Lensfun support land in a later phase.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
