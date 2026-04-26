import SwiftUI
import PavementCore

struct CropOverlay: View {
    @Binding var crop: CropOp
    let viewerState: ViewerState
    let imageExtent: CGRect
    let sourceAspectRatio: CGFloat

    @State private var dragStart: CropOp?

    var body: some View {
        GeometryReader { geometry in
            let mapper = CropOverlayMapper(
                viewSize: geometry.size,
                viewerState: viewerState,
                imageExtent: imageExtent
            )
            let imageRect = mapper.imageRect
            let rect = mapper.viewRect(for: crop)

            ZStack {
                dimmingMask(imageRect: imageRect, cropRect: rect)

                GridOverlay(mode: .thirds)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .clipShape(Rectangle())

                cropFrame(rect)
                    .gesture(moveGesture(imageRect: imageRect))

                ForEach(CropHandle.allCases) { handle in
                    handleView(handle)
                        .position(handle.point(in: rect))
                        .gesture(handleGesture(handle, imageRect: imageRect))
                }

                quickBar
                    .position(x: imageRect.midX, y: max(38, imageRect.minY - 34))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(true)
    }

    private var quickBar: some View {
        HStack(spacing: 5) {
            ForEach(["free", "1:1", "3:2", "4:5", "16:9"], id: \.self) { aspect in
                Button {
                    setAspect(aspect)
                } label: {
                    Text(aspect)
                        .font(.caption2.monospacedDigit().weight(crop.aspect == aspect ? .semibold : .regular))
                        .frame(minWidth: 34)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(crop.aspect == aspect ? Color.accentColor.opacity(0.20) : Color.clear)
                )
            }

            Divider().frame(height: 16)

            Button {
                crop = CropOp(enabled: false)
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)
            .help("Reset crop")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }

    private func dimmingMask(imageRect: CGRect, cropRect: CGRect) -> some View {
        Canvas { ctx, size in
            var path = Path(CGRect(origin: .zero, size: size))
            path.addPath(Path(cropRect))
            ctx.fill(path, with: .color(.black.opacity(0.46)), style: FillStyle(eoFill: true))

            var outside = Path()
            outside.addRect(imageRect)
            outside.addRect(cropRect)
            ctx.fill(outside, with: .color(.black.opacity(0.16)), style: FillStyle(eoFill: true))
        }
        .allowsHitTesting(false)
    }

    private func cropFrame(_ rect: CGRect) -> some View {
        Rectangle()
            .strokeBorder(Color.white.opacity(0.92), lineWidth: 1.2)
            .background(Color.white.opacity(0.001))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .shadow(color: .black.opacity(0.55), radius: 1)
    }

    private func handleView(_ handle: CropHandle) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color.white)
            .frame(width: handle.isCorner ? 12 : 22, height: handle.isCorner ? 12 : 7)
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color.black.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 3)
    }

    private func moveGesture(imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? crop
                dragStart = start
                var updated = start
                updated.enabled = true
                updated.x = clamp01(start.x + Double(value.translation.width / imageRect.width), maxValue: 1 - start.w)
                updated.y = clamp01(start.y + Double(value.translation.height / imageRect.height), maxValue: 1 - start.h)
                crop = updated
            }
            .onEnded { _ in dragStart = nil }
    }

    private func handleGesture(_ handle: CropHandle, imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? crop
                dragStart = start
                crop = handle.adjust(
                    start,
                    dx: Double(value.translation.width / imageRect.width),
                    dy: Double(value.translation.height / imageRect.height)
                )
            }
            .onEnded { _ in dragStart = nil }
    }

    private func setAspect(_ aspect: String) {
        crop.enabled = true
        crop.aspect = aspect
        guard let target = CropFilter.aspectRatio(aspect) else { return }
        let normalizedAspect = Double(target / sourceAspectRatio)
        let centerX = crop.x + crop.w / 2
        let centerY = crop.y + crop.h / 2
        var width = crop.w
        var height = width / normalizedAspect
        if height > 1 {
            height = crop.h
            width = height * normalizedAspect
        }
        crop.w = min(1, max(0.05, width))
        crop.h = min(1, max(0.05, height))
        crop.x = clamp01(centerX - crop.w / 2, maxValue: 1 - crop.w)
        crop.y = clamp01(centerY - crop.h / 2, maxValue: 1 - crop.h)
    }

    private func clamp01(_ value: Double, maxValue: Double = 1) -> Double {
        min(max(value, 0), max(0, maxValue))
    }
}

private struct CropOverlayMapper {
    let viewSize: CGSize
    let viewerState: ViewerState
    let imageExtent: CGRect

    var imageRect: CGRect {
        guard imageExtent.width > 0, imageExtent.height > 0 else { return .zero }
        let xRatio = viewerState.viewportSize.width > 0 ? viewSize.width / viewerState.viewportSize.width : 1
        let yRatio = viewerState.viewportSize.height > 0 ? viewSize.height / viewerState.viewportSize.height : 1
        let width = imageExtent.width * viewerState.scale * xRatio
        let height = imageExtent.height * viewerState.scale * yRatio
        let center = CGPoint(
            x: viewSize.width / 2 + viewerState.panOffset.width * xRatio,
            y: viewSize.height / 2 - viewerState.panOffset.height * yRatio
        )
        return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    func viewRect(for crop: CropOp) -> CGRect {
        let rect = imageRect
        return CGRect(
            x: rect.minX + rect.width * crop.x,
            y: rect.minY + rect.height * crop.y,
            width: rect.width * crop.w,
            height: rect.height * crop.h
        )
    }
}

private enum CropHandle: CaseIterable, Identifiable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    var id: String { String(describing: self) }

    var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomRight, .bottomLeft: return true
        default: return false
        }
    }

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .top: return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    func adjust(_ crop: CropOp, dx: Double, dy: Double) -> CropOp {
        let minSize = 0.05
        var updated = crop
        updated.enabled = true

        func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
            min(max(value, minValue), maxValue)
        }

        switch self {
        case .topLeft:
            let newX = clamp(crop.x + dx, 0, crop.x + crop.w - minSize)
            let newY = clamp(crop.y + dy, 0, crop.y + crop.h - minSize)
            updated.w = crop.w + crop.x - newX
            updated.h = crop.h + crop.y - newY
            updated.x = newX
            updated.y = newY
        case .top:
            let newY = clamp(crop.y + dy, 0, crop.y + crop.h - minSize)
            updated.h = crop.h + crop.y - newY
            updated.y = newY
        case .topRight:
            let newY = clamp(crop.y + dy, 0, crop.y + crop.h - minSize)
            updated.w = clamp(crop.w + dx, minSize, 1 - crop.x)
            updated.h = crop.h + crop.y - newY
            updated.y = newY
        case .right:
            updated.w = clamp(crop.w + dx, minSize, 1 - crop.x)
        case .bottomRight:
            updated.w = clamp(crop.w + dx, minSize, 1 - crop.x)
            updated.h = clamp(crop.h + dy, minSize, 1 - crop.y)
        case .bottom:
            updated.h = clamp(crop.h + dy, minSize, 1 - crop.y)
        case .bottomLeft:
            let newX = clamp(crop.x + dx, 0, crop.x + crop.w - minSize)
            updated.w = crop.w + crop.x - newX
            updated.x = newX
            updated.h = clamp(crop.h + dy, minSize, 1 - crop.y)
        case .left:
            let newX = clamp(crop.x + dx, 0, crop.x + crop.w - minSize)
            updated.w = crop.w + crop.x - newX
            updated.x = newX
        }

        return updated
    }
}
