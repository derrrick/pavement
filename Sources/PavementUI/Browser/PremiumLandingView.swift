import SwiftUI

struct PremiumLandingView: View {
    let onChooseFolder: () -> Void
    let onImportXMP: () -> Void
    let onImportLUT: () -> Void

    var body: some View {
        ZStack {
            landingBackground

            HStack(spacing: 36) {
                intro
                    .frame(minWidth: 320, idealWidth: 420, maxWidth: 500, alignment: .leading)

                StudioPreview()
                    .frame(minWidth: 420, idealWidth: 560, maxWidth: 720)
            }
            .padding(.horizontal, 52)
            .padding(.vertical, 42)
            .frame(maxWidth: 1240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pavement")
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .tracking(0)
                Text("A quiet, premium studio for building photographic looks.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(action: onChooseFolder) {
                    Label("Open Photo Folder", systemImage: "folder.badge.plus")
                        .frame(minWidth: 170)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Menu {
                    Button {
                        onImportXMP()
                    } label: {
                        Label("Lightroom XMP", systemImage: "doc.badge.plus")
                    }
                    Button {
                        onImportLUT()
                    } label: {
                        Label(".cube LUT", systemImage: "cube.transparent")
                    }
                } label: {
                    Label("Import Style", systemImage: "wand.and.stars")
                        .frame(minWidth: 132)
                }
                .menuStyle(.button)
                .controlSize(.large)
            }

            workflowStrip
        }
    }

    private var workflowStrip: some View {
        HStack(spacing: 10) {
            LandingStep(icon: "square.grid.2x2", title: "Browse")
            LandingStep(icon: "swatchpalette", title: "Style")
            LandingStep(icon: "slider.horizontal.3", title: "Refine")
            LandingStep(icon: "square.and.arrow.up", title: "Export")
        }
        .padding(.top, 8)
    }

    private var landingBackground: some View {
        ZStack {
            Theme.surfaceInset
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.075),
                    Color(red: 0.15, green: 0.12, blue: 0.09),
                    Color(red: 0.05, green: 0.065, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
}

private struct LandingStep: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.surfaceRaised.opacity(0.72), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(Theme.borderSubtle, lineWidth: 1)
        )
    }
}

private struct StudioPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(Color.red.opacity(0.55)).frame(width: 9, height: 9)
                Circle().fill(Color.yellow.opacity(0.55)).frame(width: 9, height: 9)
                Circle().fill(Color.green.opacity(0.55)).frame(width: 9, height: 9)
                Spacer()
                Text("Style Browser")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(Theme.surface)

            HStack(spacing: 0) {
                filmStrip
                    .frame(width: 92)
                heroPhoto
                styleRail
                    .frame(width: 168)
            }
            .frame(height: 350)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.42), radius: 32, y: 18)
    }

    private var filmStrip: some View {
        VStack(spacing: 9) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(filmGradient(index))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(index == 1 ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.08), lineWidth: index == 1 ? 2 : 1)
                    )
                    .frame(height: 64)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.black.opacity(0.18))
    }

    private var heroPhoto: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.80, green: 0.60, blue: 0.38),
                    Color(red: 0.18, green: 0.31, blue: 0.32),
                    Color(red: 0.06, green: 0.07, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GeometryReader { geo in
                Path { path in
                    let h = geo.size.height
                    let w = geo.size.width
                    path.move(to: CGPoint(x: 0, y: h * 0.74))
                    path.addCurve(to: CGPoint(x: w, y: h * 0.55), control1: CGPoint(x: w * 0.32, y: h * 0.62), control2: CGPoint(x: w * 0.62, y: h * 0.82))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(Color.black.opacity(0.38))
            }
            HStack(spacing: 8) {
                Label("72%", systemImage: "wand.and.stars")
                Label("Fit", systemImage: "magnifyingglass")
            }
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
            .padding(12)
        }
    }

    private var styleRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Built-in")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(["Warm Editorial", "Cinematic Gold", "Portra Skin"], id: \.self) { name in
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(styleGradient(name))
                        .frame(height: 44)
                    Text(name)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                }
                .padding(6)
                .background(name == "Warm Editorial" ? Color.accentColor.opacity(0.14) : Theme.surfaceInset.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
            Spacer()
        }
        .padding(10)
        .background(Theme.surfaceRaised.opacity(0.60))
    }

    private func filmGradient(_ index: Int) -> LinearGradient {
        let palettes: [[Color]] = [
            [.init(red: 0.52, green: 0.34, blue: 0.22), .init(red: 0.16, green: 0.24, blue: 0.25)],
            [.init(red: 0.80, green: 0.56, blue: 0.34), .init(red: 0.18, green: 0.30, blue: 0.31)],
            [.init(red: 0.22, green: 0.34, blue: 0.43), .init(red: 0.08, green: 0.08, blue: 0.09)],
            [.init(red: 0.62, green: 0.58, blue: 0.48), .init(red: 0.26, green: 0.22, blue: 0.18)]
        ]
        let colors = palettes[index % palettes.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func styleGradient(_ name: String) -> LinearGradient {
        switch name {
        case "Cinematic Gold":
            return LinearGradient(colors: [.init(red: 0.16, green: 0.29, blue: 0.32), .init(red: 0.84, green: 0.57, blue: 0.34)], startPoint: .leading, endPoint: .trailing)
        case "Portra Skin":
            return LinearGradient(colors: [.init(red: 0.76, green: 0.55, blue: 0.42), .init(red: 0.45, green: 0.52, blue: 0.44)], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [.init(red: 0.76, green: 0.58, blue: 0.42), .init(red: 0.20, green: 0.34, blue: 0.34)], startPoint: .leading, endPoint: .trailing)
        }
    }
}
