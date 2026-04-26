import XCTest
import CoreImage
@testable import PavementCore

@MainActor
final class PavementDocumentEditingTests: XCTestCase {
    func testUndoRedoAvailabilityTracksRecipeChanges() throws {
        let document = try makeDocument()
        XCTAssertFalse(document.canUndo)
        XCTAssertFalse(document.canRedo)

        document.recipe.operations.exposure.ev = 1.0
        XCTAssertTrue(document.canUndo)
        XCTAssertFalse(document.canRedo)

        document.undo()
        XCTAssertEqual(document.recipe.operations.exposure.ev, 0, accuracy: 0.001)
        XCTAssertFalse(document.canUndo)
        XCTAssertTrue(document.canRedo)

        document.redo()
        XCTAssertEqual(document.recipe.operations.exposure.ev, 1.0, accuracy: 0.001)
        XCTAssertTrue(document.canUndo)
        XCTAssertFalse(document.canRedo)
    }

    func testAutoAdjustAppliesAsSingleUndoableEdit() throws {
        let document = try makeDocument(color: CIColor(red: 0.18, green: 0.18, blue: 0.18))
        guard let stats = document.statisticsForMatching() else {
            return XCTFail("Expected source statistics")
        }

        document.applyAutoAdjust(from: stats)
        XCTAssertGreaterThan(document.recipe.operations.exposure.ev, 0)
        XCTAssertTrue(document.canUndo)

        document.undo()
        XCTAssertEqual(document.recipe.operations.exposure.ev, 0, accuracy: 0.001)
    }

    func testMatchLookMergesDrivenBlocksAndPreservesCropLensAndDetail() throws {
        let document = try makeDocument(color: CIColor(red: 0.20, green: 0.20, blue: 0.20))
        document.recipe.operations.crop.x = 0.2
        document.recipe.operations.lensCorrection.enabled = false
        document.recipe.operations.detail.sharpAmount = 77

        let reference = ImageStatisticsCalculator.compute(
            from: CIImage(color: CIColor(red: 0.8, green: 0.25, blue: 0.20))
                .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        )
        document.applyMatchedLook(reference: reference, intensity: 1.0)

        XCTAssertGreaterThan(document.recipe.operations.exposure.ev, 0)
        XCTAssertNotEqual(document.recipe.operations.colorGrading, ColorGradingOp())
        XCTAssertEqual(document.recipe.operations.crop.x, 0.2)
        XCTAssertFalse(document.recipe.operations.lensCorrection.enabled)
        XCTAssertEqual(document.recipe.operations.detail.sharpAmount, 77)

        document.undo()
        XCTAssertEqual(document.recipe.operations.exposure.ev, 0, accuracy: 0.001)
        XCTAssertEqual(document.recipe.operations.crop.x, 0.2)
    }

    func testStylePreviewDoesNotMutateRecipeOrUndoStack() throws {
        let document = try makeDocument()
        let original = document.recipe

        document.preview(preset: BuiltinPresets.portraSkin, amount: 0.5)

        XCTAssertEqual(document.recipe, original)
        XCTAssertFalse(document.canUndo)

        document.cancelStylePreview()
        XCTAssertEqual(document.recipe, original)
        XCTAssertFalse(document.canUndo)
    }

    func testCommittedStyleAppliesAsOneUndoableEditAfterPreview() throws {
        let document = try makeDocument()

        document.preview(preset: BuiltinPresets.portraSkin, amount: 0.5)
        document.apply(preset: BuiltinPresets.portraSkin, amount: 0.5)

        XCTAssertNotEqual(document.recipe.operations.color, ColorOp())
        XCTAssertTrue(document.canUndo)

        document.undo()
        XCTAssertEqual(document.recipe.operations.color, ColorOp())
        XCTAssertFalse(document.canUndo)
    }

    func testPreviewAndCommitUseAmountScaledRecipe() throws {
        let document = try makeDocument()
        document.apply(preset: BuiltinPresets.triXPush, amount: 0.5)

        XCTAssertEqual(
            document.recipe.operations.tone.contrast,
            Int((Double(BuiltinPresets.triXPush.operations.tone.contrast) * 0.5).rounded())
        )
        XCTAssertEqual(
            document.recipe.operations.grain.amount,
            Int((Double(BuiltinPresets.triXPush.operations.grain.amount) * 0.5).rounded())
        )
    }

    private func makeDocument(color: CIColor = CIColor(red: 0.5, green: 0.5, blue: 0.5)) throws -> PavementDocument {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        let item = SourceItem(url: url, type: .jpeg, fileSize: 1)
        let image = CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let cache = CachedDecode(provider: { _ in image })
        _ = try cache.image(for: url, applyLensCorrection: true)
        _ = try cache.image(for: url, applyLensCorrection: false)
        return PavementDocument(
            source: item,
            recipe: EditRecipe(),
            exif: nil,
            fingerprint: "test",
            cachedDecode: cache
        )
    }
}
