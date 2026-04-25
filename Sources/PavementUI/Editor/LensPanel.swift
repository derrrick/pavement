import SwiftUI
import PavementCore

struct LensPanel: View {
    @Bindable var document: PavementDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { document.recipe.operations.lensCorrection.enabled },
                set: { document.recipe.operations.lensCorrection.enabled = $0 }
            )) {
                Text("Apply embedded lens profile")
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Text("Uses the camera's embedded lens profile (CR3/RAF). Toggle off to see the raw distortion. Manual strengths and Lensfun support land in a later phase.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
