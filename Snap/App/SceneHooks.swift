import CoreGraphics
import Foundation

/// The App's writes into the scene's R2 inputs, in one place (design/notes/scene-R2.md "New API the App must call"):
/// - `BogScene.drawnClosure`: the closure in degrees the teeth are drawn from (rest reference − the hinge's predicted
///   angle, every frame; nil on touch-only phones = the snapshot's closure);
/// - `BogScene.hudSnapsAnchor`: the HUD snaps row's leftmost live glyph, in scene space (Feast glyph flights land
///   there, a sting cracks one there, a wilt droops one there).
@MainActor
enum SceneHooks {
    static func setDrawnClosure(_ scene: BogScene?, _ degrees: Double?) {
        guard let scene else { return }
        let value = degrees.flatMap { $0.isFinite ? $0 : nil }
        if scene.drawnClosure != value { scene.drawnClosure = value }
    }

    static func setSnapsAnchor(_ scene: BogScene?, _ point: CGPoint) {
        guard let scene, point.x.isFinite, point.y.isFinite else { return }
        if scene.hudSnapsAnchor != point { scene.hudSnapsAnchor = point }
    }
}
